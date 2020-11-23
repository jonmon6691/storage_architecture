#!/bin/bash

if [[ $# -lt 2 ]]
then
	echo "Usage: ./initialize.sh <dataset_source> <remote_directory>" 
	echo "	Example: ./initialize.sh tank/archives ~/rclone/gdrive/"
	exit
fi

dataset=$1
remote_dir=$2

# Temp file for holding the remote directory listing cache
files=$(tempfile)
function rmtemp {
	rm -f "$files"
}
trap rmtemp EXIT

# Check no base on remote already
rclone lsf $remote_dir > $files
if [[ $? -eq 0 ]]
then
	base=$(grep "base_[[:digit:]]\+/$" $files)
	if [[ $base != "" ]]
	then
		echo "[exists] $remote_dir/$base"
		echo "[failed] Remote already contains a base!"
		exit
	fi
fi

(set -x; sudo zfs allow -u $USER create,hold,mount,rename,send,snapshot,userprop $dataset)

# Create snapshot
tmp_name=$dataset@base
(set -x; zfs snapshot $tmp_name) || exit
stamp=`zfs list -o creation -pHt snapshot $tmp_name`
base_name=$dataset@base_$stamp
(set -x; zfs rename $tmp_name $base_name) || exit

# Verify remote

# Create base_file
base_path=$remote_dir/base_$stamp
rclone mkdir $base_path
(set -x; zfs send --raw --replicate $base_name | ./rpipe/rpipe.py --parchive $base_path) || exit

# check file integrity
./rpipe/rpipe.py --verify --repair $base_path
if [[ $? -eq 0 ]]
then
	echo "[checksum verified] Initialization complete"
	(set -x; zfs set tag:offsite=offsite $base_name)
else
	echo "[checksum failed] Initialization could not verify data on remote"
fi

echo "dataset=$dataset" > backup_args.env
echo "remote_dir=$remote_dir" >> backup_args.env
