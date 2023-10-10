#!/bin/bash
# Pontus Claesson, 2023
# Example : sudo /usr/local/bin/backup_to_s3.sh  -d /fms-data/backup/backup/Daily/ -f /fms-data/container/

BUCKET_FOLDER=$(hostname)       # ServerName in order to find it on S3
LOG_DIR="/var/log/s3-backup"    # Path for local logfiles
LOG_FILE="$LOG_DIR/backup.log"  # Path for local log
BACKUP_BUCKET="sqm-backups"     # Bucketname used for backup
RETENTION="90d"                 # S3 Lifecycle (needs to have corresponding lifecycle rules)
STORAGE_CLASS="STANDARD_IA"     # AWS Storage Class Standard-Infrequent Access for data that is accessed less frequently at a lower cost
S3_ARGS="--no-progress --storage-class $STORAGE_CLASS --metadata {\"retention\":\"$RETENTION\"}"

# Retuns size of remote bucket folder
function getSizeOfBucketFolder () {
        /usr/local/bin/aws s3 ls --summarize  --recursive s3://sqm-backups/$1/$2/ | tail -1 | awk '{print $3}'
}

function timeStamp() {
        date "+%Y-%m-%d %H:%M:%S"
}

while getopts f:d: option
do 
    case "${option}"
        in
        f)file_dir=${OPTARG};;  # Path fo FMS containerdata
        d)db_dir=${OPTARG};;    # Path to FMS DB backups
    esac
done

if [[ ! -e $LOG_DIR ]]; then
    mkdir $LOG_DIR
fi

if [ ! -d "$db_dir" ]; then
        echo "db_dir : $db_dir does not exist."
else
        echo $(timeStamp) starting DB backup >> $LOG_FILE
        # Loop over all subdirs (FM-backups) in folder
        for subdir in $db_dir/*/; do
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

        # zero counters
        s3_bytes_diff=0 s3_bytes_start=0 s3_bytes_end=0

        # Sync tgz-files to S3
        s3_bytes_start=$(getSizeOfBucketFolder $BUCKET_FOLDER "DB")
        /usr/local/bin/aws s3 sync $db_dir s3://$BACKUP_BUCKET/$BUCKET_FOLDER/DB/ $S3_ARGS --exclude "*" --include "*.tgz"  >> $LOG_FILE
        s3_bytes_end=$(getSizeOfBucketFolder $BUCKET_FOLDER "DB")
        s3_bytes_diff="$(($s3_bytes_end-$s3_bytes_start))"

        echo "$s3_bytes_diff bytes uploaded to $BACKUP_BUCKET/$BUCKET_FOLDER/DB/" >> $LOG_FILE
        echo  $s3_bytes_diff > $TRANSFERED_BYTES_LOG_DIR/db.log
        echo "$(timeStamp) $s3_bytes_diff" > $LOG_DIR/transfer_size_db.log

        # Clean upp tgz-files older than 24h
        echo "$(timeStamp) Cleaning up old files" >> $LOG_FILE
        find $db_dir -name "*.tgz" -type f -mtime +0 -delete
        echo $(timeStamp) finished db backup >> $LOG_FILE
fi

if [ ! -d "$file_dir" ]; then
        echo "file_dir : $file_dir does not exist."
else
        echo $(timeStamp) starting FILES backup >> $LOG_FILE

        # zero counters
        s3_bytes_diff=0 s3_bytes_start=0 s3_bytes_end=0

        # Sync container data to S3
        s3_bytes_start=$(getSizeOfBucketFolder $BUCKET_FOLDER "FILES")
        /usr/local/bin/aws s3 sync $file_dir s3://$BACKUP_BUCKET/$BUCKET_FOLDER/FILES/ $S3_ARGS  >> $LOG_FILE
        s3_bytes_end=$(getSizeOfBucketFolder $BUCKET_FOLDER "FILES")
        s3_bytes_diff="$(($s3_bytes_end-$s3_bytes_start))"

        echo "$s3_bytes_diff bytes uploaded to $BACKUP_BUCKET/$BUCKET_FOLDER/FILES/" >> $LOG_FILE
        echo "$(timeStamp) $s3_bytes_diff" > $LOG_DIR/transfer_size_files.log
        echo $(timeStamp) finished file backup >> $LOG_FILE
fi
