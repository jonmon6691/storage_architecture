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

prev_snapshot=`zfs list -s creation -o name -pH -t snapshot tank/archives | tail -n 1`
prev_stamp=`zfs list -o creation -pH -t snapshot ${prev_snapshot}`

# Create snapshot
(set -x; zfs snapshot ${dataset}@next) || exit
next_stamp=`zfs list -o creation -pHt snapshot ${dataset}@next`
(set -x; zfs rename ${dataset}@next ${dataset}@${next_stamp}) || exit

# Send increment
increment_file=${prev_stamp}_${next_stamp}.zfsi
(set -x; zfs send --raw -i ${prev_snapshot} ${dataset}@${next_stamp} > ${remote_dir}/${increment_file}) || exit

# Delete old snapshot
#TODO

