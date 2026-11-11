# fastp Docker image

A ready-to-run Linux Docker image of [fastp](https://github.com/OpenGene/fastp), for fast all-in-one quality control, adapter trimming and filtering of sequencing reads.

| | |
|---|---|
| **Image** | [`genomixcloud/fastp`](https://hub.docker.com/r/genomixcloud/fastp) |
| **Tool version** | fastp 1.0.1 |
| **Platform** | `linux/amd64` |
| **Database** | None |
| **Input → output** | Raw reads (FASTQ) → trimmed and filtered reads (FASTQ) and a QC report (HTML, JSON) |
| **Pipeline step** | After the raw read QC ([FastQC](../fastqc)) and before classification ([Kraken2](../kraken2)) and assembly ([SPAdes](../spades)) |

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
docker pull genomixcloud/fastp
docker run --rm genomixcloud/fastp fastp --version

# 2. Download paired-end test reads
curl -o rawreads_1.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz
curl -o rawreads_2.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz

# 3. Trim them
mkdir data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind genomixcloud/fastp fastp \
  -i rawreads_1.fastq.gz -I rawreads_2.fastq.gz \
  -o data_out/out_rawreads_1.fastq.gz -O data_out/out_rawreads_2.fastq.gz
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 18.04 | |
| fastp | 1.0.1 | Prebuilt binary from `opengene.org` |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** single-end or paired-end reads in FASTQ format. Gzipped files are accepted.
* **Database:** none.
* **Resources:** light. Use `-w` to set the number of worker threads.

## Usage

Mount your data folder on `/data`, the working folder of the container. Create the output folder first: fastp doesn't create it.

```shell
mkdir -p data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind genomixcloud/fastp fastp \
  -i rawreads_1.fastq.gz -I rawreads_2.fastq.gz \
  -o data_out/out_rawreads_1.fastq.gz -O data_out/out_rawreads_2.fastq.gz \
  -h data_out/fastp.html -j data_out/fastp.json
```

Useful options:

| Option | Meaning |
|--------|---------|
| `-i`, `-I` | Input reads 1 and 2 (`-I` only for paired-end) |
| `-o`, `-O` | Output reads 1 and 2 |
| `-h`, `-j` | HTML and JSON report. Default: `fastp.html` and `fastp.json` in the working folder |
| `-w <n>` | Number of worker threads |
| `-q <n>` | Quality value for a base to be qualified. Default: 15 |
| `-l <n>` | Discard reads shorter than this after trimming. Default: 15 |
| `--detect_adapter_for_pe` | Detect adapters for paired-end reads by overlap analysis |

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

| File | Content |
|------|---------|
| `out_rawreads_1.fastq.gz` / `out_rawreads_2.fastq.gz` | Trimmed and filtered reads |
| `fastp.html` | Quality control report, before and after filtering |
| `fastp.json` | The same report in JSON format |

Without `-h` and `-j`, the reports are written to the working folder (`/data`), not to the output folder.

## Database setup

fastp doesn't need a database.

## Running on AWS

These are ideas for deploying fastp on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
       wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. In `/src/fastp.sh`, link the **in** and **out** folders to AWS S3. You can put the links and the fastp parameters in `conf/fastp.ini`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/fastp /src/fastp.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the fastp image in AWS ECR.

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=fastp DOCKER_TAG=my_version
docker run --rm fastp:my_version fastp --version
```

Or with Docker only:

```shell
cd tools/fastp
docker build --platform=linux/amd64 -t fastp:my_version .
```

Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with the prebuilt fastp binary |
| `src/fastp.sh` | Template script, copied to `/src` in the image: calls `fastp` with the variables set in `fastp.ini` |
| `conf/fastp.ini` | Configuration template, copied to `/conf` in the image, for the input reads and output folder |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| `ERROR: Failed to write` or no output file | Create the output folder before running: fastp doesn't create it |
| The reports aren't in the output folder | Add `-h` and `-j` with paths in the output folder |

Known issues in the image, not fixed yet:

* The fastp binary is downloaded over plain `http` from `opengene.org`, without a checksum check.
* `src/fastp.sh` is a template: the variables it uses aren't read from `conf/fastp.ini` yet.
* Ubuntu 18.04 is no longer supported by Ubuntu.

## Citation

If you use this image, please cite fastp:

> Chen, S., Zhou, Y., Chen, Y., & Gu, J. (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. *Bioinformatics*, 34(17), i884–i890. https://doi.org/10.1093/bioinformatics/bty560

## Licence and references

* fastp is distributed under its own licence: [fastp licence](https://github.com/OpenGene/fastp/blob/master/LICENSE). This image only packages it.
* [fastp software and manual](https://github.com/OpenGene/fastp)
* [fastp prebuilt binaries](https://github.com/OpenGene/fastp#or-download-the-latest-prebuilt-binary-for-linux-users)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
