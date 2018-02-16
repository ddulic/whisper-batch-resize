#!/bin/bash

#########################################################################
# Script used for resizing whisper databases to given retention         #
# Generate a resize.txt with full paths of the .wsp's you wish to resize  #
# The script must be ran as the apache user!                            #
# Example: whisper-batch-resize.sh file.txt "60s:1d 5m:7d"               #
#########################################################################

# checks for the arguments
if [ $# -ne 2 ]; then
    echo "ERROR: Wrong number of arguments. Please enter the filename and desired retention"
    echo "EXAMPLE: whisper-batch-resize.sh file.txt \"60s:1d 5m:7d\""
    exit 1
fi

#### MOFIFY ACCORDINGLY BELOW
# location of the log files without ending /
log_loc="/var/log/whisper-resize"
# location of the folder where the files will be held temporarily
copy_loc="/dev/shm/tmp"
# max number of checks to perform on a corrupted file before aborting
maxchecks=4
# user under which the script has to be ran
req_user="apache"

#### DO NOT MODIFY
today=$(date +%Y-%m-%d.%H.%M)
retention=$2
line_count=1
num_of_files=$(cat $1 | wc -l)

# display usage if the script is not run as given user
if [[ ${USER} != ${req_user} ]]; then
    echo "This script must be run as the apache user!"
    exit 1
fi

# sanity check
if [[ $(grep -c ".wsp$" $1) -ne ${num_of_files} ]]; then
    echo "ERROR. Not all files in $1 end in '.wsp'. ABORTING!"
    exit 1
fi

# used for error logging, should be self explanatory
function logit {
    "$@" >> ${log_loc}/whisper-batch-resize.${today}.log 2>> ${log_loc}/whisper-batch-resize.${today}.log
}

# used in each other function for checking if the file is corrupted
# if the file is corrupted, redo all the steps and check again
function error_check {
    whisper-dump.py $1 > /dev/null 2> /dev/null
    exit_code=$?
    logit echo "whisper-dump for $1 exited with ${exit_code}"
    while [[ ${exit_code} -ne 0 ]]; do
        echo "CORRUPTED! Retry $count on file ${line_count}/${num_of_files} - ${FILE}"
        logit echo -e "\nCORRUPTED! Retry $count on file ${line_count}/${num_of_files} - ${FILE}"
        whisper-dump.py $1 > /dev/null 2> /dev/null
        exit_code=$?
        sleep 2
        if [[ ${exit_code} -eq 0 ]]; then
            echo "OK! ${line_count}/${num_of_files} - $FILE"
            logit echo "OK! ${line_count}/${num_of_files} - $FILE"
        fi
        if [[ ${count} -eq ${maxchecks} ]]; then
            echo -e "\nERROR: Maximum number of checks reached. ABORTING!"
            logit echo -e "\nERROR: Maximum number of checks reached. ABORTING!"
            exit 1
        fi
        count=$((count + 1))
    done
}

# copy the file to the tmp directory
function copy {
    mkdir -p ${copy_loc}`dirname ${FILE}`
    logit cp -v $FILE ${copy_loc}${FILE}
    func=${FUNCNAME[0]}
    if [[ ${FUNCNAME[1]} != "error_check" ]]; then
        error_check ${copy_loc}${FILE}
    fi
}

# do the actual resizing
function resize {
    logit whisper-resize.py ${copy_loc}${FILE} $retention
    logit echo "${copy_loc}${FILE} successfully resized"
}

# copy the file back from the tmp dir thus overwriting the original
function copy_back {
    func=${FUNCNAME[0]}
    logit cp -v ${copy_loc}${FILE} $FILE
    if [[ ${FUNCNAME[1]} != "error_check" ]]; then
        error_check ${FILE}
    fi
}

# delete the leftover copy
# will not execute unless all checks are passed
function delete_copy {
    logit rm -v ${copy_loc}${FILE}
    logit rm -v ${copy_loc}${FILE}.bak
    find ${copy_loc} -type d -empty -delete
}

read -r -p "The file contains ${num_of_files} files. Targeted retention is '${retention}'. Are you sure you want to continue? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        cat $1 |
        while read FILE
        do
            count=1

            echo "Processing file ${line_count}/${num_of_files} - ${FILE}"
            logit echo -e "\nProcessing file ${line_count}/${num_of_files} - ${FILE}"

            copy
            resize
            copy_back
            delete_copy

            if [[ $line_count -eq $num_of_files ]]; then
                echo -e "\n$num_of_files files successfully resized to $retention"
                echo "Log file: ${log_loc}/whisper-batch-resize.${today}.log"
                logit echo -e "\n${num_of_files} files successfully resized to ${retention}"
            fi

            line_count=$((line_count + 1))

        done
        ;;
    *)
        echo "Canceled."
        exit 1
        ;;
esac