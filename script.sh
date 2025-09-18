#!/bin/bash

# Add Configuration File

# Defining variables
BACKUP_SRC="/home/subaru/Documents/Personal/"
BACKUP_DST="/home/subaru/Backups"
BACKUP_DATE=$(date +%Y%m%d%H%M%S)
BACKUP_FILENAME="backup-demo-_$BACKUP_DATE.tar.gz"

# Make directory
mkdir -p "$BACKUP_DST/$BACKUP_DATE"

# Compress & Archive src directory

tar -czf "$BACKUP_DST/$BACKUP_DATE/$BACKUP_FILENAME" "$BACKUP_SRC"


# Verify the backup that was created successfully.

if [ $? -eq 0 ]; then
	echo "Backup was successful: $BACKUP_FILENAME"
else
	echo "Backup Failed."
fi


