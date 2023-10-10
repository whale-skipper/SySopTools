#!/bin/bash
if [ -z "$1" ]
then
	dir="/backups"
else
	dir=$1
fi
if [ -z "$2" ]
then
	time="60"
else
	time=$2
fi
changesMade=$(find $dir -mmin -$time)
if [[ -z ${changesMade} ]]
then
	echo "No backups created!"
else
	echo "OK"
fi
