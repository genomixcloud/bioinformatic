# Kraken2 database setup on AWS EC2

This guide explains how to download a prebuilt Kraken2 Standard database to AWS storage, using an AWS EC2 Ubuntu instance. You don't need to build the database or install Kraken2: the database is ready to use, and the [Kraken2 Docker image](../../../tools/kraken2) and your AWS Batch jobs can read it from the storage.

## Contents

1. [Before you start](#before-you-start)
2. [Choose a database](#choose-a-database)
3. [Launch the EC2 instance](#1-launch-the-ec2-instance)
4. [Download the database](#2-download-the-database)
5. [Check the database](#3-check-the-database)
6. [Troubleshooting](#troubleshooting)

## Before you start

You need:

* An AWS account with permission to launch EC2 instances.
* An EC2 key pair (`.pem` file) to connect to the instance with SSH.
* **Storage for the database, already mounted on the instance** and writable by the `ubuntu` user:

| Database size | Storage |
|---------------|---------|
| Standard (> 100GB) | **AWS EFS** |
| Standard-8, Standard-16 | AWS EFS or an EBS volume |

This guide assumes you know how to create and mount this storage. If you need help, see [Mounting EFS file systems](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html) or [Making an Amazon EBS volume available for use](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-using-volumes.html).

The examples below use `/mnt/efs` as the mount point. If your storage is mounted somewhere else, replace `/mnt/efs` with your path.

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
| Security group | SSH (port 22) from your IP. For EFS, also NFS (port 2049) between the instance and the EFS mount targets |

Connect to the instance:

```shell
ssh -i /path/to/your-key.pem ubuntu@<instance-public-dns>
```

## 2. Download the database

Create the database folder, then download and extract the database you chose into it. For example, for Standard:

```shell
mkdir -p /mnt/efs/kraken_db
wget -O - https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20260626.tar.gz \
| tar -xvz -C /mnt/efs/kraken_db/
```

This downloads and extracts in one step, so the archive is never stored and you only need space for the index.

If you prefer to keep the archive while extracting (you then need space for both):

```shell
cd /mnt/efs
wget https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20260626.tar.gz
tar -xvzf k2_standard_20260626.tar.gz -C /mnt/efs/kraken_db/
rm k2_standard_20260626.tar.gz
```

For Standard-8 or Standard-16, use their URL from [Choose a database](#choose-a-database).

The Standard database is large, so the download can take a long time. To keep it running if your SSH connection drops, start it inside `screen` or `tmux`.

## 3. Check the database

1. Check that the database folder contains the three Kraken2 index files, `hash.k2d`, `opts.k2d` and `taxo.k2d`:

```shell
ls -lh /mnt/efs/kraken_db
```

2. Check that the files weren't corrupted during the download, using the checksum file of your database. For example, for Standard:

```shell
cd /mnt/efs/kraken_db
wget https://genome-idx.s3.amazonaws.com/kraken/standard_20260626/standard.md5
md5sum -c --ignore-missing standard.md5
```

Every file must show `OK`. If any shows `FAILED`, download the database again. `--ignore-missing` skips the files listed in the checksum file that aren't part of the archive.

The database is ready. Use the folder path with `--db` when you run Kraken2, for example `--db /mnt/efs/kraken_db` (see the [Kraken2 Docker image](../../../tools/kraken2)).

## Troubleshooting

| Problem | Cause and solution |
|---------|--------------------|
| `Permission denied` when creating `kraken_db` or downloading | The `ubuntu` user can't write to the storage. Give it ownership of the mount point, for example `sudo chown ubuntu:ubuntu /mnt/efs` |
| `No space left on device` | The storage is too small. Use EFS for the Standard database, or download and extract in one step |
| `md5sum` shows `FAILED` | The download was interrupted or corrupted. Delete the files and download the database again |

## References

* [Kraken2 and Bracken prebuilt indexes](https://benlangmead.github.io/aws-indexes/k2)
* [Kraken2 Manual](https://github.com/DerrickWood/kraken2/blob/master/docs/MANUAL.markdown)
* [Mounting EFS file systems](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html)
* [Making an Amazon EBS volume available for use](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-using-volumes.html)
* [Langmead lab teaching documentation](https://www.langmead-lab.org/teaching.html)
