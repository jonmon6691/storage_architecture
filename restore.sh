#!/bin/bash
dataset=""
remote_dir=""

if [[ $# -ge 2 ]]
then
	dataset=$1
	remote_dir=$2
elif [[ -f "backup_args.env" ]]
then
	. backup_args.env
else
	echo "usage: ./restore.sh <dataset_source> <remote_dir>"
	echo "	example: ./restore.sh tank/archives gdrive:"
	exit
fi

# Temp file for holding the remote directory listing cache
files=$(tempfile)
function rmtemp {
	rm -f "$files"
}
trap rmtemp EXIT

# Remote directory listing is cached because it's probably slow
rclone lsf $remote_dir > $files

# Attempt to resume a restore if the dataset already exists
if [[ $(grep "^$dataset$" <(zfs list -o name)) != "" ]]
then
	prev_snapshot=`zfs list -s creation -o name,tag:offsite -pH -t snapshot $dataset | awk '$2 == "offsite" {print $1}' | tail -n 1`
	i_stamp=`zfs list -o creation -pH -t snapshot $prev_snapshot`
else # otherwise start at the base
	i_stamp='base'
fi

while [[ 1 ]]
do
	# Find next zfs file given the current stamp
    matches=$(grep "${i_stamp}_[[:digit:]]\+/$" $files | awk -F / '{print $1}')
    if [[ $matches == "" ]]
    then
		if [[ $i_stamp == "base" ]]
		then
			echo "[failed] No base found on remote!"
		else
        		echo "[Done]"
		fi
		exit
    elif [[ $(echo "$matches" | wc -l) -ne 1 ]]
    then
        echo "$matches" | awk '{print "[fork] " $1}'
        echo "Error: Encountered a fork while restoring!"
        exit
    fi

	echo "[restoring] $matches"
	(set -x; ./rpipe/rpipe.py --replay --repair $remote_dir/$matches | sudo zfs recv -o tag:offsite=offsite $dataset) || exit

	# Extract next stamp from filename
    i_stamp=$(echo "$matches" | awk -F '_' '{print $2}')
done
