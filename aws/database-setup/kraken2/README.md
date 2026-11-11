# Kraken2 database setup on AWS EC2

This guide explains how to download a **prebuilt** Kraken2 database to AWS storage, using an AWS EC2 Ubuntu instance. The [Kraken2 Docker image](../../../tools/kraken2) and your AWS Batch jobs can then read it from the storage.

**Use a prebuilt database instead of building your own.** Building a Kraken2 database with `kraken2-build` downloads all the genomes from NCBI, needs a machine with more memory than the final index, and takes many hours. The Langmead lab builds the common Kraken2 databases regularly and publishes them ready to use, so you only download and extract one file. You don't need to install Kraken2 for this either.

## Contents

1. [Where to find the prebuilt databases](#where-to-find-the-prebuilt-databases)
2. [Choose a database](#choose-a-database)
3. [Before you start](#before-you-start)
4. [Launch the EC2 instance](#1-launch-the-ec2-instance)
5. [Download the database](#2-download-the-database)
6. [Check the database](#3-check-the-database)
7. [Clean up](#4-clean-up)
8. [Troubleshooting](#troubleshooting)

## Where to find the prebuilt databases

All the prebuilt databases are listed on one page: **[benlangmead.github.io/aws-indexes/k2](https://benlangmead.github.io/aws-indexes/k2)** (the "Index zone" of the Langmead lab).

On that page, use the section **Kraken2 + Bracken**, and in it the table under **Latest: <month> <year> update**. That table has one row per database ("collection") with:

| Column | What it is |
|--------|------------|
| Collection, Contains | Database name and the genomes it includes |
| Date | Release date of this build |
| Archive size (GB), Index size (GB) | Size of the download and of the extracted index, in GiB |
| HTTPS URL | Link to the `.tar.gz` archive to download |
| Inspect, Library | What's in the database: taxa and sequences |
| MD5 | Checksum file to check the download |

The section is called *Kraken2 + Bracken* because each archive also contains the k-mer distribution files that [Bracken](https://github.com/jenniferlu717/Bracken) needs to re-estimate abundances.

Other sections of the same page are for other uses: *Kraken2 + Bracken 16s RNA* (16S databases), *KrakenUniq* and *Pracken* (other tools), and *Old Kraken2 + Bracken* and *Old Minikraken* (previous releases, see below).

### The databases are updated over time

The Langmead lab publishes a new release of the databases about every 3 to 4 months (for example February, June and October 2026), and the names, sizes and URLs change with each one:

* **The release date is part of every file name.** For example, the Standard database of 22 Oct 2026 is `k2_standard_20261022.tar.gz`, and its checksum file is in `standard_20261022/`.
* **When a new release comes out, the previous one moves to *Old Kraken2 + Bracken***, with all its links. Older releases stay available there, so you can still download the exact database you used before.
* **Sizes grow** from release to release as RefSeq grows. For example, Standard went from 103.1 GiB (June 2026) to 109.4 GiB (October 2026).

So **always copy the URLs from the page** instead of reusing old ones, and **write down the release date** you download: results from different releases aren't directly comparable. The URLs in this guide are from the **22 Oct 2026** release, the latest when it was written.

## Choose a database

The collections in the *Kraken2 + Bracken* table of the 22 Oct 2026 release (index sizes in GiB):

| Collection | Contains | Archive | Index | Use |
|------------|----------|---------|-------|-----|
| **Standard** | RefSeq archaea, bacteria, viral, plasmid, human, UniVec_Core | 84.6 | 109.4 | **Real analyses** of bacterial isolates: best sensitivity and accuracy |
| **Standard-16** | Standard, capped at 16 GB | 11.2 | 14.9 | Good balance between size and accuracy |
| **Standard-8** | Standard, capped at 8 GB | 5.5 | 7.5 | Testing, or machines with little memory |
| PlusPF | Standard plus RefSeq protozoa and fungi | 89.7 | 116.1 | Samples that may contain protozoa or fungi |
| PlusPF-8, PlusPF-16 | PlusPF, capped at 8 or 16 GB | 5.5, 11.1 | 7.5, 14.9 | As PlusPF, with less memory |
| PlusPFP | Standard plus RefSeq protozoa, fungi and plants | 199.6 | 270.0 | Samples that may contain plant DNA |
| PlusPFP-8, PlusPFP-16 | PlusPFP, capped at 8 or 16 GB | 5.1, 10.3 | 7.5, 14.9 | As PlusPFP, with less memory |
| MinusB | RefSeq archaea, viral, plasmid, human, UniVec_Core (no bacteria) | 8.6 | 12.0 | Non-bacterial screening |
| Viral | RefSeq viral | 0.5 | 0.6 | Viral reads only |

The table also has larger, less frequently updated databases (EuPathDB, core_nt, GTDB), each with its own date.

The capped databases (-8, -16) are the full database reduced to fit in 8 or 16 GB of memory, at the cost of some sensitivity and accuracy. For the Genomix Cloud pipeline we use **Standard** in production, and **Standard-8** or **Standard-16** for tests.

Download and checksum URLs of the three Standard databases in the 22 Oct 2026 release:

| Database | Download URL | Checksum file |
|----------|--------------|---------------|
| Standard-8 | https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08_GB_20261022.tar.gz | https://genome-idx.s3.amazonaws.com/kraken/standard_08_GB_20261022/standard_08_GB.md5 |
| Standard-16 | https://genome-idx.s3.amazonaws.com/kraken/k2_standard_16_GB_20261022.tar.gz | https://genome-idx.s3.amazonaws.com/kraken/standard_16_GB_20261022/standard_16_GB.md5 |
| Standard | https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20261022.tar.gz | https://genome-idx.s3.amazonaws.com/kraken/standard_20261022/standard.md5 |

For a newer release, copy the new URLs from the [index page](https://benlangmead.github.io/aws-indexes/k2): the pattern is the same with another date.

**Memory when running Kraken2:** Kraken2 loads the whole index into memory, so the machine or AWS Batch job that runs it needs more RAM than the index size (for example, more than 109.4 GiB for Standard). Downloading the database doesn't need that memory.

## Before you start

You need:

* An AWS account with permission to launch EC2 instances.
* An EC2 key pair (`.pem` file) to connect to the instance with SSH.
* **Storage for the database, already mounted on the instance** and writable by the `ubuntu` user:

| Database size | Storage |
|---------------|---------|
| Standard, PlusPF, PlusPFP (> 100 GiB) | **AWS EFS** |
| Capped databases (-8, -16) | AWS EFS or an EBS volume |

This guide assumes you know how to create and mount this storage. If you need help, see [Mounting EFS file systems](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html) or [Making an Amazon EBS volume available for use](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-using-volumes.html).

The examples below use `/mnt/efs` as the mount point. If your storage is mounted somewhere else, replace `/mnt/efs` with your path.

**Region:** the databases are in the `genome-idx` S3 bucket, in the `us-east-1` region. An instance in another region can download them too, but the transfer is slower; for the Standard database that can mean hours.

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
wget -O - https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20261022.tar.gz \
| tar -xvz -C /mnt/efs/kraken_db/
```

This downloads and extracts in one step, so the archive is never stored and you only need space for the index.

If you prefer to keep the archive while extracting (you then need space for both):

```shell
cd /mnt/efs
wget https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20261022.tar.gz
tar -xvzf k2_standard_20261022.tar.gz -C /mnt/efs/kraken_db/
rm k2_standard_20261022.tar.gz
```

For another database or a newer release, use its URL from the [index page](https://benlangmead.github.io/aws-indexes/k2) (see [Choose a database](#choose-a-database)).

The Standard database is large, so the download can take a long time. To keep it running if your SSH connection drops, start it inside `screen` or `tmux`.

To keep track of which release you have, save its date next to the index:

```shell
echo "k2_standard_20261022" > /mnt/efs/kraken_db/RELEASE.txt
```

## 3. Check the database

1. Check that the database folder contains the three Kraken2 index files, `hash.k2d`, `opts.k2d` and `taxo.k2d`:

```shell
ls -lh /mnt/efs/kraken_db
```

2. Check that the files weren't corrupted during the download, using the checksum file of your database. For example, for Standard:

```shell
cd /mnt/efs/kraken_db
wget https://genome-idx.s3.amazonaws.com/kraken/standard_20261022/standard.md5
md5sum -c --ignore-missing standard.md5
```

Every file must show `OK`. If any shows `FAILED`, download the database again. `--ignore-missing` skips the files listed in the checksum file that aren't part of the archive.

The database is ready. Use the folder path with `--db` when you run Kraken2, for example `--db /mnt/efs/kraken_db` (see the [Kraken2 Docker image](../../../tools/kraken2)).

## 4. Clean up

When the download and the check have finished, terminate the EC2 instance so you stop paying for it. The database stays on the storage.

## Troubleshooting

| Problem | Cause and solution |
|---------|--------------------|
| `404 Not Found` when downloading | The URL is from a release that has moved or changed. Copy the current URL from the [index page](https://benlangmead.github.io/aws-indexes/k2), or look for your release under *Old Kraken2 + Bracken* |
| `Permission denied` when creating `kraken_db` or downloading | The `ubuntu` user can't write to the storage. Give it ownership of the mount point, for example `sudo chown ubuntu:ubuntu /mnt/efs` |
| `No space left on device` | The storage is too small. Use EFS for the Standard database, or download and extract in one step |
| `md5sum` shows `FAILED` | The download was interrupted or corrupted. Delete the files and download the database again |
| The download is very slow | The instance is far from `us-east-1`, or it's a small instance with low network bandwidth. Use a larger instance type, or run the download in `us-east-1` and copy the index to your region afterwards |

Last reviewed on 11 Nov 2026, with the 22 Oct 2026 release of the Kraken2 + Bracken databases. All the URLs in this guide were checked that day.

## References

* [Kraken2 and Bracken prebuilt databases (Index zone)](https://benlangmead.github.io/aws-indexes/k2)
* [Kraken2 manual](https://github.com/DerrickWood/kraken2/blob/master/docs/MANUAL.markdown)
* [Bracken](https://github.com/jenniferlu717/Bracken)
* [Mounting EFS file systems](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html)
* [Making an Amazon EBS volume available for use](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-using-volumes.html)
* [Langmead lab teaching documentation](https://www.langmead-lab.org/teaching.html)
