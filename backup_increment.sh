#!/bin/bash

dataset=""
remote_dir=""
keep_snapshots=-1

if [[ -f "backup_args.env" ]]
then
	. backup_args.bash
elif [[ $# -ge 2 ]]
then
	dataset=$1
	remote_dir=$2
else
	echo "usage: ./backup_increment.sh <dataset_source> <remote_dir>"
	echo "	example: ./backup_increment.sh tank/archives ~/rclone/gdrive"
	exit
fi

prev_snapshot=`zfs list -s creation -o name,tag:offsite -pH -t snapshot $dataset | awk '$2 == "offsite" {print $1}' | tail -n 1`
prev_stamp=`zfs list -o creation -pH -t snapshot $prev_snapshot`

# Create snapshot
(set -x; sudo zfs snapshot $dataset@next) || exit
next_stamp=`zfs list -o creation -pHt snapshot $dataset@next`
(set -x; sudo zfs rename $dataset@next $dataset@$next_stamp) || exit

# Send increment
increment_file=$remote_dir/${prev_stamp}_$next_stamp
rclone mkdir $increment_file
(set -x; sudo zfs send --raw -i $prev_snapshot $dataset@$next_stamp | ./rpipe/rpipe.py $increment_file) || exit

# Verify increment on remote, tag snapshot if all is well
check=$(rclone ls $increment_file/rp-aaaaaa | awk '{print $1}')
if [[ $? -eq 0 && $check -gt 0 ]]
then
	(set -x; sudo zfs set tag:offsite=offsite $dataset@$next_stamp)
fi


# Delete old snapshot
#TODO
