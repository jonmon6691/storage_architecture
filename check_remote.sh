#!/bin/bash 

if [[ $# -lt 2 ]]
then
	echo "usage: ./check_remote.sh <dataset_source> <remote_dir>"
	echo "	example: ./check_remote.sh tank/archives ~/rclone/gdrive"
	exit
fi

dataset=$1
remote_dir=$2
files=".check_remote.cache"

# find base, get i_stamp
ls -1 $remote_dir > $files
base=$(grep "_base.zfs" $files)
nbases=$(echo "$base" | wc -l)

# get latest_stamp
latest_stamp=$(zfs list -s creation -o creation,tag:offsite,name -pHt snapshot tank/archives | awk '$2 == "offsite"' | tail -n1)
latest_stamp_name=$(echo "$latest_stamp" | awk '{print $3}')
echo "Latest local snapshot that was verified as sent offsite: $latest_stamp_name"

i_stamp=$(echo "$latest_stamp" | awk '{print $1}')
while [[ 1 ]]
do
	# Check if we're at the base file
	if [[ $i_stamp == "base" ]]
	then
		echo "[Passed] Remote appears coherent"
		exit
	fi

	# Find the file(s) that connect
	matches=$(grep "_$i_stamp.zfs" $files)
	if [[ $matches == "" ]]
	then
		echo "[Not found] *_$i_stamp.zfs"
		echo "[Failed] Remote is missing a link!"
		exit
	elif [[ $(echo "$matches" | wc -l) -ne 1 ]]
	then
		echo "$matches" | awk '{print "[fork] " $1}'
		echo "[Failed] Remote contains a fork."
		exit
	fi
	
	# check file integrity
	if [[ $(stat -c %s $remote_dir/$matches) -eq 0 ]]
	then
		echo "$matches is empty!"
		echo "Maybe there's a way to get a checksum?"
		exit
	fi
	echo "[checked] $matches"

	# get next_stamp
	i_stamp=$(echo "$matches" | awk -F "_" '{print $1}')
done
