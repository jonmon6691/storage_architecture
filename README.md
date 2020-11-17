# storage_architecture
Documentation and scripts for my storage and backup system

This storage architecture makes a distinction between archival data, and content. Content is publicly available media and software that can be replaced. Archival data is personal, private, and can not be recovered if lost.

Archival data is periodically snapshoted and the incremental changes are sent (compressed and encrypted) offsite using rclone.

![Overview diagram](docs/overview.svg)

# Internal Architecture
Only the last few periodic snapshots are retained locally, whereas remote storage contains a base file and all period increments from that point forward.

The @base snapshot is created when the remote storage is first initialized and is not touched again

Every period, a snapshot is created and an increment is sent to the remote storage. The oldest periodic snapshot is destroyed in accordance with the "local snapshots retained" parameter

![Internal diagram](docs/internal.svg)

# Initialization
```bash
# If you don't already have your source and destination set up, set them up using commands like these
# WARNING: Don't just copy paste these into your terminal! This is just a rough example of what you might do
$ zpool create tank raidz1 sdd sde sdf
$ zfs create -o compression=on -o encryption=on tank/archives
$ rclone config

# To initialize the backup system
$ ./initialize.sh tank/archives gd:/tank/archives
```

A snapshot of the dataset is created; @base\_1605400577 (where the number is the unix timestamp of the creation date of the snapshot) 

Then a `zfs send` is executed to send the full replication data stream to a file on the remote. The streaming is accomplished using an rclone wrapper called [rpipe.py](https://github.com/jonmon6691/rpipe). rpipe takes the output of `zfs send` and sends 8MB chunks to the remote and keeps track of the checksums along the way.

Finally, the data on the remote is verified and if it appears that the transfer was successful, then the snapshot is tagged as "offsite" so that it can be used as the base for the next increment.

![Initialization diagram](docs/initialization.svg)

# Periodic Backups
```bash
# Probably done in a cron script...
# Maybe you have a working directory you want to backup into the archives?
$ rsync -aF /working/dir /tank/archives/
$ sync

# To create a snapshot and send the incremental change to the remote:
$ ./backup_increment.sh tank/archives gd:/tank/archives/
```
A new dataset snapshot is created and then the increment between this and the previous snapshot is sent to remote storage and verified. Finally any snapshots past the set number of local snapshots are destroyed (except for the base)

![Incremental backup diagram](docs/backup.svg)

# Checking the integrity of the remote
```bash
# To check that the files on the remote are okay:
$ ./check_remote.sh tank/archives gd:/tank/archives/
# If it fails you will want to purge the remote and re-initialize
```

The check script works by checking what is the latest snapshot on the local zfs dataset (that has the offsite flag set). It then finds the increment on the remote that matches, then it works its way backwards in time, checking each increment's hashes along the way until it finds the base. If it finds any problems on the way or doesn't find the base, it will report that out.

If the check fails, be thankful that you caught it before you actually needed that data! The best way forward is to re-initialize in a new folder on the remote and then once it's done, purge the old folder.

```bash
# In case of a failed check:
$ ./initialize tank/archives gd:/tank/archives_new/
$ rclone purge gd:/tank/archives
```

# Restoring
```bash
# To restore from the remote:
# NOTE: Make sure the dataset (e.g. tank/new_archives) doesn't exist!
$ ./restore.sh tank/new_archives gd:/tank/archives
```

Restoring is very easy, just make sure the dataset specified does not already exist.

