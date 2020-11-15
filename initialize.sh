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
base_path=${remote}/base_${stamp}.zfs
(set -x; zfs send --raw --replicate ${base_name} > ${base_path}) || exit

# Verify increment on remote, tag snapshot if all is well
if [[ -f ${base_path} && `stat -c %s ${base_path}` -gt 0 ]]
then
	(set -x; zfs set tag:offsite=offsite ${base_name})
fi
