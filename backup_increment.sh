#!/bin/bash

dataset=""
remote_dir=""
keep_snapshots=-1

if [[ -f "backup_args.bash" ]]
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
prev_stamp=`zfs list -o creation -pH -t snapshot ${prev_snapshot}`

# Create snapshot
(set -x; zfs snapshot ${dataset}@next) || exit
next_stamp=`zfs list -o creation -pHt snapshot ${dataset}@next`
(set -x; zfs rename ${dataset}@next ${dataset}@${next_stamp}) || exit

# Send increment
increment_file=${remote_dir}/${prev_stamp}_${next_stamp}.zfsi
(set -x; zfs send --raw -i ${prev_snapshot} ${dataset}@${next_stamp} > ${increment_file}) || exit

# Verify increment on remote, tag snapshot if all is well
if [[ -f ${increment_file} && `stat -c %s ${increment_file}` -gt 0 ]]
then
	(set -x; zfs set tag:offsite=offsite ${dataset}@${next_stamp})
fi

# Delete old snapshot
#TODO
