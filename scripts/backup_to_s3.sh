#!/bin/bash
# Pontus Claesson, 2023


# Function that return current timestamp in ISO format
function timeStamp() {
        date "+%Y-%m-%d %H:%M:%S"
}

# Set some local vars
CONTAINER_DATA="/fms-data/container"
BASE_DIR_DEFALUT="/backup/Backups/Daily"
BUCKET_FOLDER=$(hostname) # ServerName in order to find it on S3
LOG_FILE="/var/log/s3-backup.log"
BASE_DIR=${1:-$BASE_DIR_DEFALUT}

# and som S3 vars
BACKUP_BUCKET="sqm-backups"
RETENTION="90d" # Used for S3 Lifecycle config. (retention)
STORAGE_CLASS="STANDARD_IA"


echo $(timeStamp) starting backup >> $LOG_FILE
# Loop over all subdirs (FM-backups) in folder
for subdir in $BASE_DIR/*/; do
        SOURCE=$subdir
        DEST_DIR=$(dirname "$SOURCE")
        DEST_NAME=$(basename "$SOURCE")
        DEST="$DEST_DIR/$BUCKET_FOLDER-$DEST_NAME.tgz"

        # Create new tgz if none exists for givven folder.
        if [ ! -f "$DEST" ] ; then
                echo  "$(timeStamp) $DEST packing" >> $LOG_FILE
                tar -czf "$DEST" "$SOURCE"
        else
                echo "$(timeStamp) $DEST skipping" >> $LOG_FILE
        fi
done


# Sync tgz-files to S3
/usr/local/bin/aws s3 sync $BASE_DIR s3://$BACKUP_BUCKET/$BUCKET_FOLDER/DB/ --no-progress --exclude "*" --include "*.tgz" --storage-class $STORAGE_CLASS --metadata '{"retention":"'$RETENTION'"}' >> $LOG_FILE

# Sync container data to S3
/usr/local/bin/aws s3 sync $CONTAINER_DATA s3://$BACKUP_BUCKET/$BUCKET_FOLDER/FILES/ --no-progress --storage-class $STORAGE_CLASS --metadata '{"retention":"'$RETENTION'"}' >> $LOG_FILE


# Clean upp tgz-files older than 24h
echo "$(timeStamp) Cleaning up old files" >> $LOG_FILE
find $BASE_DIR -name "*.tgz" -type f -mtime +0 -delete

echo $(timeStamp) finished backup >> $LOG_FILE