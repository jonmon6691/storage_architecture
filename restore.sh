#!/bin/bash
dataset=""
remote_dir=""

if [[ $# -ge 2 ]]
then
	dataset=$1
	remote_dir=$2
elif [[ -f "backup_args.bash" ]]
then
	. backup_args.bash
else
	echo "usage: ./check_remote.sh <dataset_source> <remote_dir>"
	echo "	example: ./check_remote.sh tank/archives ~/rclone/gdrive"
	exit
fi

files=$(tempfile)
function rmtemp {
	rm -f "$files"
}
trap rmtemp EXIT

ls -1 $remote_dir > $files

if [[ $(grep "^$dataset$" <(zfs list -o name)) != "" ]]
then
	prev_snapshot=`zfs list -s creation -o name,tag:offsite -pH -t snapshot $dataset | awk '$2 == "offsite" {print $1}' | tail -n 1`
	i_stamp=`zfs list -o creation -pH -t snapshot ${prev_snapshot}`
else
	i_stamp='base'
fi

if [[ $prev_stamp != "" ]]
then
	i_stamp=$prev_stamp
fi
while [[ 1 ]]
do
    matches=$(grep "${i_stamp}_[[:digit:]]\+.zfs" $files)
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
	(set -x; cat $remote_dir/$matches | zfs recv -o tag:offsite=offsite $dataset) || exit
    i_stamp=$(echo "$matches" | awk -F '.' '{print $1}' | awk -F '_' '{print $2}')
done