#!/bin/bash
# Set user & pass using mysql_config_editor-
# sudo mysql_config_editor set --login-path=local --host=localhost --user=mysql_backup --password

# directory to put the backup files
BACKUP_DIR=/var/backups/mysql

# MYSQL Parameters
MYSQL_UNAME=mysql_backup
MYSQL_PWORD=

# Don't backup databases with these names
# Example: starts with mysql (^mysql) or ends with _schema (_schema$)
IGNORE_DB="(^mysql|_schema|sys$)"

# include mysql and mysqldump binaries for cron bash user
PATH=$PATH:/usr/local/mysql/bin

# Number of days to keep backups
KEEP_BACKUPS_FOR=30 #days

# S3-stuff
BACKUP_BUCKET="sqm-backups"
BUCKET_FOLDER=$(hostname)
LOG_FILE="/var/log/s3-backup.log"
RETENTION="90d" # Used for S3 Lifecycle config. (retention)
STORAGE_CLASS="STANDARD_IA"



TIMESTAMP=$(date +"%Y-%m-%d_%H:%M:%S")

function delete_old_backups()
{
  echo "Deleting $BACKUP_DIR/*.sql.gz older than $KEEP_BACKUPS_FOR days"
  find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +$KEEP_BACKUPS_FOR -exec rm {} \;
}

function mysql_login() {
  local mysql_login="-u $MYSQL_UNAME" 
  if [ -n "$MYSQL_PWORD" ]; then
    local mysql_login+=" -p$MYSQL_PWORD" 
  fi
   echo --login-path=local 
}

function database_list() {
  local show_databases_sql="SHOW DATABASES WHERE \`Database\` NOT REGEXP '$IGNORE_DB'"
  echo $(mysql $(mysql_login) -e "$show_databases_sql"|awk -F " " '{if (NR!=1) print $1}')
}

function echo_status(){
  printf '\r'; 
  printf ' %0.s' {0..100} 
  printf '\r'; 
  printf "$1"'\r'
}

function backup_database(){
    backup_file="$BACKUP_DIR/$TIMESTAMP.$database.sql.gz" 
    output+="$database => $backup_file\n"
    echo_status "...backing up $count of $total databases: $database"
    $(mysqldump $(mysql_login) $database --opt --routines | gzip > $backup_file)
}

function backup_databases(){
  local databases=$(database_list)
  local total=$(echo $databases | wc -w | xargs)
  local output=""
  local count=1
  for database in $databases; do
    backup_database
    local count=$((count+1))
  done
  echo -ne $output | column -t
}

function hr(){
  printf '=%.0s' {1..100}
  printf "\n"
}

#==============================================================================
# RUN SCRIPT
#==============================================================================
delete_old_backups
hr
backup_databases
hr
printf "All backed up!\n\n"

printf "Transfering to s3\n\n"
/usr/local/bin/aws s3 sync $BACKUP_DIR s3://$BACKUP_BUCKET/$BUCKET_FOLDER/DB/ --no-progress --storage-class $STORAGE_CLASS --metadata '{"retention":"'$RETENTION'"}' >> $LOG_FILE

printf "All Done\n\n"
