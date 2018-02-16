# Whisper Batch Resize

A relatively safe way to resize vast ammounts of whisper databases.

## How it does it

While doing error checking at every stage:

- reads the location of the .wsp from the given list
- copies the .wsp to the copy location
- resizes the .wsp file and moves it back
- deletes the resize generated backups

## Installation

Download the file and mark it executable

```
curl -o /usr/local/bin/whisper-batch-resize https://raw.githubusercontent.com/ddulic/whisper-batch-resize/master/whisper-batch-resize.sh
```

```
chmod +x /usr/local/bin/whisper-batch-resize
```

## Options

Defaults are below, modify inside the script if needed.

Location of the log files without ending /

```bash
log_loc="/var/log/whisper-resize"
```

Location of the folder where the files will be held temporarily

```bash
copy_loc="/dev/shm/tmp"
```

Max number of checks to perform on a corrupted file before aborting

```bash
maxchecks=4
```

User under which the script has to be ran

```bash
req_user="apache"
```

## Usage

```
whisper-batch-resize resize.txt "60s:1d 5m:7d"
```

In order to run the script you must pass a `resize.txt` (name doesn't matter) as the **first** argument with full paths of the `.wsp` files you wish to resize.
I recommend using `find` to generate the txt.

Example for `find`

```bash
find /storage/whisper -type f -name '*.wsp' -path "subfolder_path/*" > resize.txt
```

The **second** argument is the desired retention, just as in `whisper-resize.py`

```
60:1440      60 seconds per datapoint, 1440 datapoints = 1 day of retention
15m:8        15 minutes per datapoint, 8 datapoints = 2 hours of retention
1h:7d        1 hour per datapoint, 7 days of retention
12h:2y       12 hours per datapoint, 2 years of retention
```