# Bakta database setup on AWS

Bakta can't run without its database. This guide explains how to download the **full** Bakta database (about 64 GB) to **AWS EFS**, where the [Bakta Docker image](../../../tools/bakta) and your AWS Batch jobs can read it.

Always download the database with Bakta's own command, **`bakta_db download`**, never by downloading the archive by hand. It also updates the **AMRFinderPlus** database inside it, which Bakta uses to annotate antimicrobial resistance genes.

## Contents

* [How bakta_db download works](#how-bakta_db-download-works)
* [Choose how to download](#choose-how-to-download)
* [Before you start](#before-you-start)
* [Option A: EC2 instance with the Docker image (recommended)](#option-a-ec2-instance-with-the-docker-image-recommended)
* [Option B: EC2 instance with Bakta installed](#option-b-ec2-instance-with-bakta-installed)
* [Option C: AWS Batch job](#option-c-aws-batch-job)
* [Check the database](#check-the-database)
* [Use the database](#use-the-database)
* [Keep the database up to date](#keep-the-database-up-to-date)
* [Clean up](#clean-up)
* [Troubleshooting](#troubleshooting)
* [Files in this folder](#files-in-this-folder)
* [References](#references)

## How bakta_db download works

`bakta_db download --output <folder> --type full` does four things, in this order:

1. **Finds the newest compatible database** for the installed Bakta version. Bakta 1.11.x needs database version 6.x; the newest is **v6.0** (24 Feb 2025). `bakta_db list` shows the versions.
2. **Downloads** `db.tar.xz` from Zenodo into the output folder (31.9 GB for `full`, 1.3 GB for `light`) and checks its MD5 checksum.
3. **Extracts** it into `<folder>/db` (or `<folder>/db-light`) and deletes the archive.
4. **Updates the AMRFinderPlus database** in `<folder>/db/amrfinderplus-db`. It runs `amrfinder_update --force_update`, which downloads the current AMRFinderPlus data from NCBI.

Two practical consequences:

* **Storage:** the archive and the extracted database exist at the same time for a while, so plan for **at least 100 GB free** for the full database.
* **Versions:** step 4 fetches the AMRFinderPlus data that matches the `amrfinder` version doing the download. **Download the database with the same Bakta image your jobs use**, so the database and the software match. Option A and Option C do this automatically.

## Choose how to download

| Option | Best for | What you need |
|--------|----------|---------------|
| **A. EC2 instance with the Docker image** (recommended) | A one-off download, with the same software as your jobs. Nothing to install apart from Docker | An EC2 instance with EFS mounted |
| **B. EC2 instance with Bakta installed** | Running Bakta itself on the instance, outside Docker | An EC2 instance with EFS mounted, and the install script in this folder |
| **C. AWS Batch job** | Teams that already run Bakta on AWS Batch, or that want to repeat the download or the update without managing an instance | An AWS Batch compute environment and job queue with access to EFS |

If you aren't sure, use **Option A**: it's the simplest, and you can turn it into Option C later.

## Before you start

You need:

* An AWS account with permission to use EC2, EFS and (for Option C) AWS Batch.
* An **EFS file system**, with a mount target in the subnet where the instance or job runs. Its security group must allow **NFS (port 2049)** from the instance or the Batch compute environment. EFS is the recommended storage, because all your AWS Batch jobs can share it. An EBS volume also works with Options A and B, but only one instance can use it.
* **At least 100 GB free** on that storage for the full database (see above).
* **Internet access** from the instance or job, to download from Zenodo (`zenodo.org`) and NCBI (`ftp.ncbi.nlm.nih.gov`). In a private subnet this means a NAT gateway.

The examples use `/mnt/efs` as the EFS mount point and `/mnt/efs/bakta_db` as the database folder. If yours are different, change the paths.

## Option A: EC2 instance with the Docker image (recommended)

### 1. Launch the instance

| Setting | Value |
|---------|-------|
| AMI | Ubuntu Server (x86_64) |
| Instance type | **r5.2xlarge** (8 vCPU, 64 GB RAM). On smaller instances the download and extraction can run out of memory and be killed |
| Security group | SSH (port 22) from your IP, and NFS (port 2049) to the EFS mount targets |

Use an x86_64 instance type: the Bakta image is built for `linux/amd64`.

Connect to it and mount EFS on `/mnt/efs` (see [Mounting EFS file systems](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html)):

```shell
ssh -i /path/to/your-key.pem ubuntu@<instance-public-dns>
```

### 2. Install Docker

```shell
sudo apt-get update
sudo apt-get install -y docker.io
```

### 3. Download the database

```shell
sudo mkdir -p /mnt/efs/bakta_db
sudo docker run --rm \
  --mount src=/mnt/efs/bakta_db,target=/db,type=bind \
  genomixcloud/bakta:latest \
  bakta_db download --output /db --type full
```

The image runs `bakta_db` directly, so you don't need to activate any environment. The download takes a long time: start it inside `screen` or `tmux` so it keeps running if your SSH connection drops. It ends with `Successfully downloaded Bakta database!` and `Update AMRFinderPlus database... done`.

For a quick test first, use `--type light` (1.3 GB): it creates `/mnt/efs/bakta_db/db-light`.

Then [check the database](#check-the-database) and [clean up](#clean-up).

## Option B: EC2 instance with Bakta installed

Use this option if you also want to run Bakta on the instance outside Docker. The install script creates the same conda environment as the Bakta image: Bakta 1.11.4, pyhmmer 0.11.3 and Python 3.10. AMRFinderPlus and the other dependencies are resolved by conda when you run it, so they can be newer than in the image you use for your jobs. If they differ, refresh the AMRFinderPlus data with the image afterwards (see [Keep the database up to date](#keep-the-database-up-to-date)).

### 1. Launch the instance

Launch it as in [Option A, step 1](#1-launch-the-instance), connect to it and mount EFS.

### 2. Copy the installation files

From your computer, in this folder, copy both files to the instance:

```shell
scp -i /path/to/your-key.pem install_bakta_ubuntu.sh environment.yaml \
ubuntu@<instance-public-dns>:~
```

### 3. Install Bakta

On the instance:

```shell
chmod +x install_bakta_ubuntu.sh
./install_bakta_ubuntu.sh
```

The script stops at the first error. It:

1. Installs the system packages it needs (`wget`, `zip`, `groff`, `locales`) and generates the `en_US.UTF-8` locale.
2. Installs Miniconda in `~/miniconda3`, unless it's already there.
3. Accepts the conda channel terms of service, updates conda and adds the `bioconda` and `conda-forge` channels.
4. Creates the `bakta_env` environment from `environment.yaml`, unless it already exists, and prints the Bakta version.

You can run it again safely: it skips what's already installed. When it finishes, activate the environment in your session (and in every new SSH session):

```shell
export PATH="$HOME/miniconda3/bin:$PATH"
source activate bakta_env
```

### 4. Download the database

```shell
sudo mkdir -p /mnt/efs/bakta_db
sudo chown -R ubuntu:ubuntu /mnt/efs/bakta_db
bakta_db download --output /mnt/efs/bakta_db --type full
```

As in Option A, start it inside `screen` or `tmux`. Then [check the database](#check-the-database) and [clean up](#clean-up).

## Option C: AWS Batch job

The job runs the Bakta image with EFS mounted and calls `bakta_db download`. You don't manage any instance, and you can submit the same job again to update the database.

### 1. Register the job definition

Save this as `bakta-db-download.json`. Replace `fs-0123456789abcdef0` with your EFS file system ID:

```json
{
  "jobDefinitionName": "bakta-db-download",
  "type": "container",
  "platformCapabilities": ["EC2"],
  "containerProperties": {
    "image": "genomixcloud/bakta:latest",
    "command": ["bakta_db", "download", "--output", "/mnt/efs/bakta_db", "--type", "full"],
    "resourceRequirements": [
      {"type": "VCPU", "value": "2"},
      {"type": "MEMORY", "value": "16384"}
    ],
    "volumes": [
      {
        "name": "efs",
        "efsVolumeConfiguration": {
          "fileSystemId": "fs-0123456789abcdef0",
          "transitEncryption": "ENABLED"
        }
      }
    ],
    "mountPoints": [
      {"sourceVolume": "efs", "containerPath": "/mnt/efs", "readOnly": false}
    ]
  },
  "retryStrategy": {"attempts": 1},
  "timeout": {"attemptDurationSeconds": 21600}
}
```

```shell
aws batch register-job-definition --cli-input-json file://bakta-db-download.json
```

* **Memory:** 16 GiB is a starting point. If the job ends with exit code 137 (killed, out of memory), register a new revision with more memory, up to the 64 GiB of the instance used in Options A and B.
* **Timeout:** 6 hours (`21600` seconds). The download speed from Zenodo varies; raise it if the job times out.
* **Retries:** 1 attempt. A second attempt would start the 32 GB download again from zero, so resubmit by hand after checking the log.
* **Image:** use the same tag as your annotation jobs, so the AMRFinderPlus data matches their `amrfinder` version.
* The compute environment needs **internet access** (NAT gateway in a private subnet) and its security group must reach EFS on port 2049.

### 2. Submit the job

```shell
aws batch submit-job \
  --job-name bakta-db-download \
  --job-queue <your-job-queue> \
  --job-definition bakta-db-download
```

Follow it in the AWS Batch console, or with `aws batch describe-jobs --jobs <job-id>`. The log is in CloudWatch Logs, in the `/aws/batch/job` log group. A successful run ends with `Successfully downloaded Bakta database!` and `Update AMRFinderPlus database... done`.

Then [check the database](#check-the-database): you can do it from any instance with EFS mounted, or with a short job that runs `ls /mnt/efs/bakta_db/db`.

## Check the database

```shell
ls /mnt/efs/bakta_db/db
cat /mnt/efs/bakta_db/db/version.json
ls /mnt/efs/bakta_db/db/amrfinderplus-db/latest
```

`version.json` shows the database version (`"major": 6`), type and date. `amrfinderplus-db/latest` must point to a folder with the AMRFinderPlus data; if it's missing, step 4 of the download failed (see [Troubleshooting](#troubleshooting)).

## Use the database

Mount the folder that contains `db` and pass the `db` path with `--db`. With Docker:

```shell
docker run --rm \
  --mount src="$(pwd)",target=/data,type=bind \
  --mount src=/mnt/efs/bakta_db,target=/db,type=bind \
  genomixcloud/bakta /src/bakta.sh --db /db/db --threads 16 contig.fasta --output data_out
```

In an AWS Batch job definition, mount EFS as in Option C (`readOnly: true` is enough for annotation jobs) and pass `--db /mnt/efs/bakta_db/db`.

## Keep the database up to date

* **New Bakta database release:** `bakta_db update` replaces an existing database with the newest compatible version and updates AMRFinderPlus too. Run it with the image, as in Option A:

  ```shell
  sudo docker run --rm \
    --mount src=/mnt/efs/bakta_db,target=/db,type=bind \
    genomixcloud/bakta:latest \
    bakta_db update --db /db/db --tmp-dir /db
  ```

  As an AWS Batch job, use the Option C job definition with the command `["bakta_db", "update", "--db", "/mnt/efs/bakta_db/db", "--tmp-dir", "/mnt/efs/bakta_db"]`.
* **New Bakta image:** if you pull or build a Bakta image with a different AMRFinderPlus version, refresh only the AMRFinderPlus data, with that image:

  ```shell
  sudo docker run --rm \
    --mount src=/mnt/efs/bakta_db,target=/db,type=bind \
    genomixcloud/bakta:latest \
    amrfinder_update --force_update --database /db/db/amrfinderplus-db
  ```

* **New Bakta major version:** a Bakta release that needs a new database major version (7.x) can't use the old database. Download it again with `bakta_db download`.

## Clean up

When the download has finished, stop paying for what you no longer need:

* **Options A and B:** terminate the EC2 instance. The database stays on EFS.
* **Option C:** nothing runs once the job ends. Keep the job definition for updates.
* If you tried `--type light` first, delete `/mnt/efs/bakta_db/db-light` to save EFS storage.

## Troubleshooting

| Problem | Cause and solution |
|---------|--------------------|
| The process stops with `Killed`, or the Batch job ends with exit code 137 | Out of memory. Use an r5.2xlarge instance, or give the job more memory |
| `ERROR: Could not download file from Zenodo!` | No internet access, or Zenodo is temporarily unavailable. Check the NAT gateway and security groups, and try again later |
| `ERROR: AMRFinderPlus failed! command: 'amrfinder_update ...'` | Step 4 couldn't reach NCBI. The Bakta database is already extracted: check internet access to `ftp.ncbi.nlm.nih.gov`, then run only the `amrfinder_update` command from [Keep the database up to date](#keep-the-database-up-to-date) |
| `ERROR: wrong database version detected!` when running Bakta | The database doesn't match the Bakta version. Bakta 1.11.x needs version 6.x: download it again with the same image as your jobs |
| `No space left on device` | Less than about 100 GB free. Free up space or use EFS, which grows automatically |
| `Permission denied` when downloading (Option B) | The `ubuntu` user doesn't own the folder. Run the `chown` command in [Option B, step 4](#4-download-the-database) |
| `bakta: command not found` (Option B) | The conda environment isn't active. Run the two commands at the end of [Option B, step 3](#3-install-bakta) |
| `sudo: docker: command not found` (Option A) | Docker isn't installed. Run [Option A, step 2](#2-install-docker) |

## Files in this folder

| File | Content |
|------|---------|
| `install_bakta_ubuntu.sh` | Option B: installs Miniconda and the `bakta_env` conda environment. Stops at the first error and can be run again safely |
| `environment.yaml` | Conda environment: Bakta 1.11.4, pyhmmer 0.11.3, Python 3.10 and AMRFinderPlus. The same as `tools/bakta/environment.yaml` |

Last reviewed on 11 Nov 2026, against Bakta 1.11.4 and the `genomixcloud/bakta:latest` image of that date (database v6.0). The install script was tested on Ubuntu 24.04. The Option C job definition hasn't been run on AWS yet.

## References

* [Bakta database download](https://github.com/oschwengers/bakta/blob/main/README.md#database-download)
* [Bakta software and manual](https://github.com/oschwengers/bakta/blob/main/README.md)
* [AMRFinderPlus database updates](https://github.com/ncbi/amr/wiki/Upgrading#database-updates)
* [Mounting EFS file systems](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html)
* [Amazon EFS volumes in AWS Batch](https://docs.aws.amazon.com/batch/latest/userguide/efs-volumes.html)
* [Amazon EC2 memory-optimized instances](https://aws.amazon.com/ec2/instance-types/r5/)
