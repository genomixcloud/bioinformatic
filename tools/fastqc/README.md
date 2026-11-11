# FastQC Docker image

A ready-to-run Linux Docker image of [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/), for the quality control of raw sequencing reads.

| | |
|---|---|
| **Image** | [`genomixcloud/fastqc`](https://hub.docker.com/r/genomixcloud/fastqc) |
| **Tool version** | FastQC 0.12.1 |
| **Platform** | `linux/amd64` |
| **Database** | None |
| **Input → output** | Reads (FASTQ, SAM or BAM) → QC report (HTML and ZIP) |
| **Pipeline step** | First step, on the raw reads, before trimming ([fastp](../fastp)) |

## Contents

* [Quick start](#quick-start)
* [Image contents](#image-contents)
* [Requirements](#requirements)
* [Usage](#usage)
* [Outputs](#outputs)
* [Database setup](#database-setup)
* [Running on AWS](#running-on-aws)
* [Build and test](#build-and-test)
* [Troubleshooting](#troubleshooting)
* [Citation](#citation)
* [Licence and references](#licence-and-references)

## Quick start

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/fastqc
docker run --rm genomixcloud/fastqc fastqc --version

# 2. Download paired-end test reads
curl -o rawreads_1.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz
curl -o rawreads_2.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz

# 3. Check their quality
mkdir data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/fastqc fastqc rawreads_1.fastq.gz rawreads_2.fastq.gz -t 4 -o ./data_out
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 18.04 | |
| FastQC | 0.12.1 | From the Babraham Bioinformatics download page |
| Java | Ubuntu 18.04 `default-jre` | Needed by FastQC |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** reads in FASTQ format (gzipped files are accepted), or SAM/BAM files.
* **Database:** none.
* **Resources:** light. Use `-t` to set the number of files processed at the same time.

## Usage

Mount your data folder on `/data`, the working folder of the container. Create the output folder first: FastQC doesn't create it.

```shell
mkdir -p data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/fastqc fastqc rawreads_1.fastq.gz rawreads_2.fastq.gz -t 4 -o ./data_out
```

Useful options:

| Option | Meaning |
|--------|---------|
| `-o <folder>` | Output folder. It must exist |
| `-t <n>` | Number of files processed at the same time. Each one uses about 250 MB of memory |
| `-f <format>` | Force the input format: `fastq`, `bam` or `sam` |
| `--extract` | Also unzip the report data in the output folder |

Test data, if you don't have your own reads. The [data/data_in_raw](../../data) folder of this repo also has raw paired-end reads.

```shell
# Linux
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz -O rawreads_1.fastq.gz
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz -O rawreads_2.fastq.gz
# macOS
curl -o rawreads_1.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz
curl -o rawreads_2.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz
```

## Outputs

For each input file, FastQC writes to the output folder:

| File | Content |
|------|---------|
| `<name>_fastqc.html` | Quality control report, to open in a browser |
| `<name>_fastqc.zip` | The report data, images and a text summary (`summary.txt`, `fastqc_data.txt`) |

## Database setup

FastQC doesn't need a database.

## Running on AWS

These are ideas for deploying FastQC on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
       wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. In `/src/fastqc.sh`, link the **in** and **out** folders to AWS S3. You can put the links and the FastQC parameters in `conf/fastqc.ini`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/fastqc /src/fastqc.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the FastQC image in AWS ECR.

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=fastqc DOCKER_TAG=my_version
docker run --rm fastqc:my_version fastqc --version
```

Or with Docker only:

```shell
cd tools/fastqc
docker build --platform=linux/amd64 -t fastqc:my_version .
```

Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with Java and FastQC |
| `src/fastqc.sh` | Template script, copied to `/src` in the image: calls `fastqc` with the variables set in `fastqc.ini` |
| `conf/fastqc.ini` | Configuration template, copied to `/conf` in the image, for the input reads and output folder |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| `Specified output directory ... does not exist` | Create the output folder before running |
| Java runs out of memory with many files | Lower `-t`: each file processed at the same time uses about 250 MB |

Known issues in the image, not fixed yet:

* `src/fastqc.sh` is a template: the variables it uses aren't read from `conf/fastqc.ini` yet.
* Ubuntu 18.04 is no longer supported by Ubuntu.

## Citation

FastQC has no paper. Please cite the software:

> Andrews, S. (2010). FastQC: a quality control tool for high throughput sequence data. https://www.bioinformatics.babraham.ac.uk/projects/fastqc/

## Licence and references

* FastQC is distributed under the GPL v3 licence: see the [FastQC repository](https://github.com/s-andrews/FastQC). This image only packages it.
* [FastQC main page](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
* [FastQC manual](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/)
* [FastQC installation notes](https://raw.githubusercontent.com/s-andrews/FastQC/master/INSTALL.txt)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
