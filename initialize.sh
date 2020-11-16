#!/bin/bash -x

if [[ $# -lt 2 ]]
then
	echo "Usage: ./initialize.sh <dataset_source> <remote_directory>" 
	echo "	Example: ./initialize.sh tank/archives ~/rclone/gdrive/"
	exit
fi

dataset=$1
remote_dir=$2/$dataset

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

# Create snapshot
tmp_name=$dataset@base
(set -x; zfs snapshot $tmp_name) || exit
stamp=`zfs list -o creation -pHt snapshot $tmp_name`
base_name=$dataset@base_$stamp
(set -x; sudo zfs rename $tmp_name $base_name) || exit

# Verify remote

# Create base_file
base_path=$remote_dir/base_$stamp
rclone mkdir $base_path
(set -x; sudo zfs send --raw --replicate $base_name | ./rpipe/rpipe.py $base_path) || exit

# Verify increment on remote, tag snapshot if all is well
check=$(rclone ls $base_path/rp-aaaaaa | awk '{print $1}')
if [[ $? -eq 0 && $check -gt 0 ]]
then
	(set -x; sudo zfs set tag:offsite=offsite $base_name)
fi

echo "dataset=$dataset" > backup_args.env
echo "remote_dir=$remote_dir" >> backup_args.env
