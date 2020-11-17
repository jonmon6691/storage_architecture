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
$ zpool create tank sdd sde sdf
$ zfs create -o compression=on -o encryption=on tank/archives
$ rclone config

# To initialize the backup system
$ ./initialize.sh tank/archives gd:/tank/archives
```

A snapshot of the dataset is created; base\_@%s (where %s is the unix timestamp of the creation date of the snapshot) 

Then a `zfs send` is executed to send the full replication data stream to a file on the remote. The streaming is accomplished using an rclone wrapper called [rpipe.py](https://github.com/jonmon6691/rpipe). rpipe takes the output of `zfs send` and sends 8MB chunks to the remote and keeps track of the checksums along the way.

![Initialization diagram](docs/initialization.svg)

# Incremental Backup
```bash
# Probably done in a cron script...
# Maybe you have a working directory you want to backup into the archives?
$ rsync -aF /working/dir /tank/archives/
$ sync

# To create a snapshot and send the incremental change to the remote:
$ ./inremental_backup.sh tank/archives gd:/tank/archives/
```
A new dataset snapshot is created and then the increment between this and the previous snapshot is sent to remote storage. Finally any snapshots past the set number of local snapshots are destroyed (except for the base)

![Incremental backup diagram](docs/backup.svg)

# Checking the integrity of the remote
```bash
# To check that the files on the remote are okay:
$ ./check+remote.sh tank/archives gd:/tank/archives/
# If it fails you will want to purge the remote and re-initialize
```

The check script works by looking at what the latest snapshot on the local zfs dataset is that has the offsite flag. It then finds the increment on the remote that matches and then works its way backwards in time, checking each increment's hashes along the way until it finds a base. If it finds any problems on the way or doesn't find a base, it will report that out.

If the check fails, be thankful that you caught it before you actually needed that data ;). The best way forward is to re-initialize in a new folder on the remote and then once it's done, purge the old folder.

```bash
# In case of a failed check:
$ ./initialize tank/archives gd:/tank/archives_new/
$ rclone purge gd:/tank/archives
```

# Restoring
```bash
# To restore from the remote:
$ ./restore.sh tank/new_archives gd:/tank/archives
```

Restoring is very easy, just make sure the dataset specified does not already exist.

