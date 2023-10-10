#!/bin/sh
DIR="/fms-data/data"
OWNER="fmserver"
LOG_FILE="/var/log/inoticoming.log"
inoticoming --foreground --logfile $LOG_FILE $DIR chown fmserver $DIR/{} \;