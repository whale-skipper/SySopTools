
# Set som vars
$BASE_DIR = "C:\Program Files\FileMaker\FileMaker Server\Data\Backups\Daily"
$BASE_DIR_FILES = "C:\Program Files\FileMaker\FileMaker Server\Data\Backups\Daily"
$BUCKET_FOLDER= "Luna"
$LOG_FILE = "C:\Users\Administrator\Desktop\s3-backup-files\backup.log"

# and som S3 vars
$BACKUP_BUCKET = "sqm-backups"
$RETENTION = "90d" # Used for S3 Lifecycle config. (retention)
$STORAGE_CLASS="STANDARD_IA"
$date = Get-Date -format yMdd-Hmmss



$directoryListing = Get-ChildItem -Path $BASE_DIR  -Directory | Select  -ExpandProperty FullName
$7zipPath = "$env:ProgramFiles\7-Zip\7z.exe"
Set-Alias Start-SevenZip $7zipPath

foreach ($dir in $directoryListing) {
    $SOURCE = $dir
    #$DEST = (Get-Item $dir).BaseName + ".zip"
    $DEST = $dir + ".zip"

    if (-not(Test-Path -Path $DEST -PathType Leaf)) {
        Start-SevenZip a $DEST $SOURCE
        }
    else {
            echo " Skipping dir, file already ziped"
        }
    }


$logDir = "C:\Users\Administrator\Desktop\s3-backup-files"
$standardOutput = "$logDir\aws_s3_sync_" + $baseName + "-" + $date + ".log"
$standardError = "$logDir\aws_s3_sync_" + $baseName + "-" + $date + ".errors.log"

# Set cmd
$awsCmd = "aws"


# Set cmd args
# Due to limitations / bugs in powershell metadat is set in a separate file 
# Se https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-parameters-quoting-strings.html#powershell
# And https://stackoverflow.com/questions/51861707/error-parsing-parameter-expression-attribute-values-invalid-json-expecting

$awsCmdArgs = "s3 sync ""$BASE_DIR"" s3://$BACKUP_BUCKET/$BUCKET_FOLDER/DB/ --no-progress --exclude ""*"" --include ""*.zip"" --storage-class $STORAGE_CLASS --metadata file://retention.json"

# Run cmd (sync to S3)
Start-Process $awsCmd -ArgumentList $awsCmdArgs -RedirectStandardOutput $standardOutput -RedirectStandardError $standardError

# Backup Container data
#$awsCmdArgs = "s3 sync $BASE_DIR s3://$BACKUP_BUCKET/$BUCKET_FOLDER/FILES/ --no-progress --storage-class $STORAGE_CLASS --metadata '{""retention"":""'$RETENTION'""}'"
#echo "Start-Process aws -ArgumentList $awsCmdArgs -RedirectStandardOutput $standardOutput -RedirectStandardError $standardError"


#Get-ChildItem -Path $BASE_DIR\*.zip -Recurse -Force | Where-Object {$_.Lastwritetime -lt (date).addhours(-24)} | Remove-Item -Force
