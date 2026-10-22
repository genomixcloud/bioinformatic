# Kraken2 database setup on AWS EC2

This guide explains how to download a prebuilt Kraken2 Standard database to an EBS volume, using an AWS EC2 Ubuntu instance. You don't need to build the database or install Kraken2: the database is ready to use, and the [Kraken2 Docker image](../../../tools/kraken2) and your AWS Batch jobs can read it from the volume.

## Contents

1. [Before you start](#before-you-start)
2. [Choose a database](#choose-a-database)
3. [Launch the EC2 instance](#1-launch-the-ec2-instance)
4. [Mount the EBS volume](#2-mount-the-ebs-volume)
5. [Download the database](#3-download-the-database)
6. [Check the database](#4-check-the-database)
7. [Troubleshooting](#troubleshooting)

## Before you start

You need:

* An AWS account with permission to launch EC2 instances and create EBS volumes.
* An EC2 key pair (`.pem` file) to connect to the instance with SSH.
* An **EBS volume** attached to the instance, big enough for the database you choose (see below).

## Choose a database

We use the prebuilt Kraken2 indexes from the [Langmead lab AWS indexes](https://benlangmead.github.io/aws-indexes/k2) page. They include RefSeq archaea, bacteria, viral, plasmid, human and UniVec_Core. We use one of these three (June 2026 release):

| Database | Archive | Index | Use |
|----------|---------|-------|-----|
| **Standard-8** | 5.5GB | 7.5GB | Testing, or machines with little memory |
| **Standard-16** | 11.2GB | 14.9GB | Good balance between size and accuracy |
| **Standard** | 79.6GB | 103.1GB | Real analyses, best sensitivity and accuracy |

Standard-8 and Standard-16 are the Standard database capped at 8GB and 16GB. They're smaller at the cost of some sensitivity and accuracy.

| Database | Download URL | Checksum file |
|----------|--------------|---------------|
| Standard-8 | https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08_GB_20260626.tar.gz | https://genome-idx.s3.amazonaws.com/kraken/standard_08_GB_20260626/standard_08_GB.md5 |
| Standard-16 | https://genome-idx.s3.amazonaws.com/kraken/k2_standard_16_GB_20260626.tar.gz | https://genome-idx.s3.amazonaws.com/kraken/standard_16_GB_20260626/standard_16_GB.md5 |
| Standard | https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20260626.tar.gz | https://genome-idx.s3.amazonaws.com/kraken/standard_20260626/standard.md5 |

The indexes are updated regularly. Check the [AWS indexes page](https://benlangmead.github.io/aws-indexes/k2) for newer releases.

**Memory when running Kraken2:** Kraken2 loads the whole index into memory, so the machine or AWS Batch job that runs it needs more RAM than the index size (for example, more than 103.1GB for Standard). Downloading the database doesn't need that memory.

## 1. Launch the EC2 instance

The instance is only used to download the database, so a small instance is enough.

| Setting | Value |
|---------|-------|
| AMI | Ubuntu Server (x86_64) |
| Instance type | A small general-purpose instance, for example t3.medium. Network speed matters more than CPU or RAM here |
| EBS volume | At least the index size, plus the archive size if you keep the archive while extracting (for example, around 200GB for Standard) |
| Security group | SSH (port 22) from your IP |

## 2. Mount the EBS volume

Connect to the instance:

```shell
ssh -i /path/to/your-key.pem ubuntu@<instance-public-dns>
```

1. Find the name of the EBS volume. On most current instance types it appears as `/dev/nvme1n1`; on older ones as `/dev/xvdb`:

```shell
lsblk
```

2. **Only for a new, empty volume:** create a file system. This erases everything on the volume:

```shell
sudo mkfs -t ext4 /dev/nvme1n1
```

3. Mount the volume on `/mnt/sdb`, then give the `ubuntu` user ownership. Run `chown` **after** `mount`: before mounting, it only changes the empty mount point, and you get `Permission denied` when you write to the volume.

```shell
sudo mkdir -p /mnt/sdb
sudo mount /dev/nvme1n1 /mnt/sdb
sudo chown ubuntu:ubuntu /mnt/sdb
mkdir -p /mnt/sdb/kraken_db
```

## 3. Download the database

Download and extract the database you chose into `/mnt/sdb/kraken_db`. For example, for Standard:

```shell
cd /mnt/sdb
wget https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20260626.tar.gz
tar -xvzf k2_standard_20260626.tar.gz -C /mnt/sdb/kraken_db/
rm k2_standard_20260626.tar.gz
```

To save disk space, you can download and extract in one step, without keeping the archive:

```shell
wget -O - https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20260626.tar.gz \
| tar -xvz -C /mnt/sdb/kraken_db/
```

For Standard-8 or Standard-16, use their URL from [Choose a database](#choose-a-database).

The Standard database is large, so the download can take a long time. To keep it running if your SSH connection drops, start it inside `screen` or `tmux`.

## 4. Check the database

1. Check that the database folder contains the three Kraken2 index files, `hash.k2d`, `opts.k2d` and `taxo.k2d`:

```shell
ls -lh /mnt/sdb/kraken_db
```

2. Check that the files weren't corrupted during the download, using the checksum file of your database. For example, for Standard:

```shell
cd /mnt/sdb/kraken_db
wget https://genome-idx.s3.amazonaws.com/kraken/standard_20260626/standard.md5
md5sum -c --ignore-missing standard.md5
```

Every file must show `OK`. If any shows `FAILED`, download the database again. `--ignore-missing` skips the files listed in the checksum file that aren't part of the archive.

The database is ready. Use the folder path with `--db` when you run Kraken2, for example `--db /mnt/sdb/kraken_db` (see the [Kraken2 Docker image](../../../tools/kraken2)).

## Troubleshooting

| Problem | Cause and solution |
|---------|--------------------|
| `mkdir: cannot create directory '/mnt/sdb/kraken_db': Permission denied` | The `ubuntu` user doesn't own the mounted volume. Run `sudo chown ubuntu:ubuntu /mnt/sdb` **after** `mount` |
| `mount: special device /dev/xvdb does not exist` | The volume has another name on this instance. Run `lsblk` and use the name it shows (for example `/dev/nvme1n1`) |
| `No space left on device` | The EBS volume is too small. See the sizes in [Choose a database](#choose-a-database), or download and extract in one step |
| `md5sum` shows `FAILED` | The download was interrupted or corrupted. Delete the files and download the database again |

## References

* [Kraken2 and Bracken prebuilt indexes](https://benlangmead.github.io/aws-indexes/k2)
* [Kraken2 Manual](https://github.com/DerrickWood/kraken2/blob/master/docs/MANUAL.markdown)
* [Langmead lab teaching documentation](https://www.langmead-lab.org/teaching.html)
* [Making an Amazon EBS volume available for use](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-using-volumes.html)
