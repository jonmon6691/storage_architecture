#!/bin/bash

dataset=$1
remote=$2

if [[ $# -lt 2 ]]
then
	echo "Usage: ./initialize.sh <dataset_source> <remote_directory>" 
	echo "	Example: ./initialize.sh tank/archives ~/rclone/gdrive/"
	exit
fi

# Create snapshot
tmp_name=${dataset}@base
(set -x; zfs snapshot ${tmp_name}) || exit
stamp=`zfs list -o creation -pHt snapshot ${tmp_name}`
base_name=${dataset}@${stamp}_base
(set -x; zfs rename ${tmp_name} ${base_name}) || exit

# Verify remote

# Create base_file
base_file=${stamp}_base.zfs
(set -x; zfs send --raw --replicate ${base_name} > ${remote}/${base_file}) || exit

