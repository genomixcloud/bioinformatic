# Bakta database setup on AWS EC2

This guide explains how to install [Bakta](https://github.com/oschwengers/bakta) 1.11.4 on an AWS EC2 Ubuntu instance and download its database to external storage (AWS EFS or an EBS volume). Once the database is there, the [Bakta Docker image](../../../tools/bakta) and your AWS Batch jobs can use it.

## Contents

1. [Before you start](#before-you-start)
2. [Launch the EC2 instance](#1-launch-the-ec2-instance)
3. [Copy the installation files to the instance](#2-copy-the-installation-files-to-the-instance)
4. [Install Bakta](#3-install-bakta)
5. [Download the database](#4-download-the-database)
6. [Check the installation](#5-check-the-installation)
7. [Troubleshooting](#troubleshooting)

## Files in this folder

| File | Content |
|------|---------|
| `install_bakta_ubuntu.sh` | Installs Miniconda and creates the `bakta_env` conda environment |
| `environment.yaml` | Conda environment: Bakta 1.11.4, AMRFinderPlus and Python 3.10. The script needs it in the same folder |

## Before you start

You need:

* An AWS account with permission to launch EC2 instances.
* An EC2 key pair (`.pem` file) to connect to the instance with SSH.
* External storage for the database, mounted on the instance:
  * **AWS EFS** (recommended for production, so AWS Batch jobs can share the database), mounted on `/mnt/efs`, or
  * an **EBS volume**, mounted on `/mnt/sdb`.
* Enough free space for the database you choose:

| Database type | Size | Use |
|---------------|------|-----|
| `full` | > 30GB compressed, around 64GB uncompressed. Plan for at least 100GB free while it downloads and extracts | Real analyses |
| `light` | A few GB | Testing |

## 1. Launch the EC2 instance

Launch an instance with these settings:

| Setting | Value |
|---------|-------|
| AMI | Ubuntu Server (x86_64) |
| Instance type | **r5.2xlarge** (8 vCPU, 64GB RAM) |
| Storage | Root volume large enough for Miniconda and the conda environment, plus the EFS or EBS storage for the database |
| Security group | SSH (port 22) from your IP. For EFS, also allow NFS (port 2049) between the instance and the EFS mount targets |

**Why r5.2xlarge?** Bakta and its database download need a lot of memory. On smaller instances the process can run out of memory and be killed by the operating system. r5.2xlarge is a memory-optimized instance with enough RAM to avoid this.

Use an x86_64 instance type (like r5): the installation script downloads the x86_64 version of Miniconda, so it doesn't work on ARM (Graviton) instances.

## 2. Copy the installation files to the instance

From your computer, in this folder, copy both files to the instance's home directory:

```shell
scp -i /path/to/your-key.pem install_bakta_ubuntu.sh environment.yaml \
ubuntu@<instance-public-dns>:~
```

Then connect to the instance:

```shell
ssh -i /path/to/your-key.pem ubuntu@<instance-public-dns>
```

## 3. Install Bakta

On the instance, give the script execution permission and run it:

```shell
chmod +x install_bakta_ubuntu.sh
./install_bakta_ubuntu.sh
```

The script:

1. Installs the system packages it needs (`zip`, `groff`, `locales`).
2. Installs Miniconda in `/home/ubuntu/miniconda3`.
3. Accepts the conda channel terms of service and adds the `bioconda` and `conda-forge` channels.
4. Creates the `bakta_env` conda environment from `environment.yaml`.

The environment is activated only inside the script. When it finishes, activate it in your own session:

```shell
export PATH=$HOME/bin:/home/ubuntu/miniconda3/bin:$PATH
source activate bakta_env
```

Run these two commands again every time you open a new SSH session.

## 4. Download the database

1. Give the `ubuntu` user ownership of the database folder (for EFS):

```shell
sudo mkdir -p /mnt/efs/bakta_db
sudo chown -R ubuntu:ubuntu /mnt/efs/bakta_db
```

2. Download the database type you need:

```shell
# Full database (real analyses)
bakta_db download --output /mnt/efs/bakta_db --type full

# Light database (testing)
bakta_db download --output /mnt/efs/bakta_db --type light
```

If you use an EBS volume instead of EFS, replace `/mnt/efs` with `/mnt/sdb` in both steps.

Bakta saves the database in a subfolder of the output folder:

| Type | Folder |
|------|--------|
| `full` | `/mnt/efs/bakta_db/db` |
| `light` | `/mnt/efs/bakta_db/db-light` |

You can rename the folder if you want. Use its path with `--db` when you run Bakta.

The full database is large, so the download can take a long time. To keep it running if your SSH connection drops, start it inside `screen` or `tmux`.

ref: [Bakta database download](https://github.com/oschwengers/bakta/blob/main/README.md#database-download)

## 5. Check the installation

```shell
bakta --version
ls /mnt/efs/bakta_db/db
```

To run Bakta with this database, pass its path with `--db`:

```shell
bakta --db /mnt/efs/bakta_db/db --output data_out contig.fasta
```

## Troubleshooting

| Problem | Cause and solution |
|---------|--------------------|
| The process stops with `Killed` | The instance ran out of memory. Use an r5.2xlarge or larger instance |
| `bakta: command not found` | The conda environment isn't active. Run the two commands at the end of [Install Bakta](#3-install-bakta) |
| `Permission denied` when downloading | The `ubuntu` user doesn't own the database folder. Run the `chown` command in [Download the database](#4-download-the-database) |
| `No space left on device` | The storage is too small for the database. See the sizes in [Before you start](#before-you-start) |
| The script fails because `/home/ubuntu/miniconda3` already exists | Miniconda was installed by an earlier run. Remove the folder, or skip the Miniconda steps and create the environment with `conda env create -f environment.yaml` |

## References

* [Bakta Software](https://github.com/oschwengers/bakta/blob/main/README.md#installation)
* [Bakta database download](https://github.com/oschwengers/bakta/blob/main/README.md#database-download)
* [Amazon EC2 memory-optimized instances](https://aws.amazon.com/ec2/instance-types/r5/)
* [Mounting EFS file systems](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html)
