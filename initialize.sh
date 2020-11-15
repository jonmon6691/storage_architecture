#!/bin/bash

if [[ $# -lt 2 ]]
then
	echo "Usage: ./initialize.sh <dataset_source> <remote_directory>" 
	echo "	Example: ./initialize.sh tank/archives ~/rclone/gdrive/"
	exit
fi

dataset=$1
remote_dir=$2

files=$(tempfile)
function rmtemp {
	rm -f "$files"
}
trap rmtemp EXIT

# Check no base on remote already
ls -1 $remote_dir > $files
base=$(grep "base_[[:digit:]]\+.zfs$" $files)
if [[ $base != "" ]]
then
	echo "[exists] $remote_dir/$base"
	echo "[failed] Remote already contains a base!"
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
base_path=${remote_dir}/base_${stamp}.zfs
(set -x; zfs send --raw --replicate ${base_name} > ${base_path}) || exit

# Verify increment on remote, tag snapshot if all is well
if [[ -f ${base_path} && `stat -c %s ${base_path}` -gt 0 ]]
then
	(set -x; zfs set tag:offsite=offsite ${base_name})
fi

echo "dataset=$dataset" > backup_args.bash
echo "remote_dir=$remote_dir" >> backup_args.bash