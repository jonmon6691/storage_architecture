#!/bin/bash

dataset=$1
remote=$2

if [[ $# -lt 2 ]]
then
	echo "Usage: ./initialize.sh <dataset_source> <remote_directory>" 
	echo "	Example: ./initialize.sh tank/archives ~/rclone/gdrive/"
	exit
fi

# Generate snapshot name
snapshot=`date +%Y_M%m_base`
base_file=${snapshot}.zfs

# Create snapshot
(set -x; zfs snapshot ${dataset}@${snapshot}) || exit

# Verify remote

# Create base_file
(set -x; zfs send --raw --replicate ${dataset}@${snapshot} > ${remote}/${base_file}) || exit

