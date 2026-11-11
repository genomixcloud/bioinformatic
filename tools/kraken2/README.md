# Kraken2 Docker image

A ready-to-run Linux Docker image of [Kraken2](https://github.com/DerrickWood/kraken2), for the taxonomic classification of sequencing reads.

| | |
|---|---|
| **Image** | [`genomixcloud/kraken2`](https://hub.docker.com/r/genomixcloud/kraken2) |
| **Tool version** | Kraken2 2.1.6 |
| **Platform** | `linux/amd64` |
| **Database** | Required: MiniKraken2 (8 GB) for testing, Kraken2 Standard for real analyses |
| **Input → output** | Reads (FASTQ or FASTA) → classification per read and report per taxon |
| **Pipeline step** | After trimming ([fastp](../fastp)), to check the species and contamination before assembly ([SPAdes](../spades)) |

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

This example uses the 8 GB **MiniKraken2 database** so you can try the image quickly. For real analyses use a full database (see [Database setup](#database-setup)).

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/kraken2
docker run --rm genomixcloud/kraken2 kraken2 --version

# 2. Download the MiniKraken2 database into ./kraken_db
#    (move the .k2d files to kraken_db if the archive extracts them into a subfolder)
mkdir kraken_db
curl -o minikraken2.tgz https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v2_8GB_201904.tgz
tar -xzf minikraken2.tgz -C kraken_db

# 3. Classify the trimmed test reads from the data folder of this repo
#    (copy data_in_trimmed next to kraken_db first)
mkdir -p data_out/taxonomic_identification
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/kraken2 kraken2 --paired \
  /data/data_in_trimmed/trimmed_reads_1.fastq.gz /data/data_in_trimmed/trimmed_reads_2.fastq.gz \
  --db /data/kraken_db --threads 8 --memory-mapping \
  --output /data/data_out/taxonomic_identification/kraken-output.txt \
  --report /data/data_out/taxonomic_identification/kraken-report.txt
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 22.04 | |
| Kraken2 | 2.1.6 | Built from the GitHub release `v2.1.6`. Includes `kraken2-build` and `kraken2-inspect` |
| BLAST+ | Ubuntu 22.04 package (`ncbi-blast+`) | Used by `kraken2-build` to mask low-complexity sequences |
| rsync, Python 3 | Ubuntu 22.04 packages | Used by `kraken2-build` to download libraries |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** single-end or paired-end reads in FASTQ or FASTA format. Gzipped files are accepted.
* **Database (mandatory):** Kraken2 can't run without a database. MiniKraken2 (8 GB) is good for testing. The Kraken2 Standard database is much bigger and recommended for real analyses.
* **Storage:** keep the database in external storage, or on AWS EFS when running on AWS, and mount it into the container.
* **Resources:** Kraken2 loads the whole database into memory. If Docker has less memory than the database size, add `--memory-mapping`. Use `--threads` to set the number of CPUs. Benchmarks on several AWS instance types are in [aws/performance/kraken2](../../aws/performance/kraken2).

## Usage

1. Download a Kraken2 database to a **kraken_db** folder. For a local test, use the [MiniKraken2 database](https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v2_8GB_201904.tgz).
2. Move to the `data` folder of this repo, which contains the trimmed sample reads, and put `kraken_db` inside it.
3. **Create** the output folder (`data_out/taxonomic_identification` in this example). Kraken2 doesn't create it.

```md
data
├── kraken_db
├── data_out
│   └── taxonomic_identification
└── data_in_trimmed
    ├── trimmed_reads_1.fastq.gz
    └── trimmed_reads_2.fastq.gz
```

4. Run Kraken2:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/kraken2 kraken2 --paired \
  /data/data_in_trimmed/trimmed_reads_1.fastq.gz /data/data_in_trimmed/trimmed_reads_2.fastq.gz \
  --db /data/kraken_db --threads 8 --memory-mapping \
  --output /data/data_out/taxonomic_identification/kraken-output.txt \
  --report /data/data_out/taxonomic_identification/kraken-report.txt
```

`--memory-mapping` is **needed** in this local setup, because Docker usually has less memory than the database needs.

Useful options:

| Option | Meaning |
|--------|---------|
| `--db <folder>` | Database folder, with the `.k2d` files |
| `--paired` | The two input files are read 1 and read 2 of each pair |
| `--threads <n>` | Number of CPUs |
| `--memory-mapping` | Read the database from disk instead of loading it into memory. Slower, but needs much less RAM |
| `--report <file>` | Summary per taxon |
| `--output <file>` | One line per read. Without it, Kraken2 prints one line per read on the screen; with millions of reads, always save it to a file |
| `--confidence <0-1>` | Confidence score threshold. Default: 0 |
| `--gzip-compressed` | Input is gzipped. Usually detected automatically |

## Outputs

| File | Content |
|------|---------|
| `kraken-report.txt` | Summary per taxon: percentage of reads, number of reads in the clade, number of reads assigned directly, rank code, NCBI taxonomy ID and scientific name |
| `kraken-output.txt` | One line per read (or read pair): classified (`C`) or unclassified (`U`), read ID, taxonomy ID, length and k-mer mapping |

## Database setup

**Download a prebuilt database instead of building one.** The Langmead lab builds the common Kraken2 databases and publishes them ready to use at **[benlangmead.github.io/aws-indexes/k2](https://benlangmead.github.io/aws-indexes/k2)**. On that page, use the section **Kraken2 + Bracken**, table **Latest: <month> <year> update**: each row is a database with its download link (HTTPS URL), its checksum (MD5), and its archive and index sizes. The archives also contain the files that Bracken needs.

| Database | Index size (22 Oct 2026 release) | Use |
|----------|----------------------------------|-----|
| **Standard** (RefSeq archaea, bacteria, viral, plasmid, human, UniVec_Core) | 109.4 GiB | **Real analyses** |
| **Standard-16** (Standard capped at 16 GB) | 14.9 GiB | Good balance between size and accuracy |
| **Standard-8** (Standard capped at 8 GB) | 7.5 GiB | Testing, or machines with little memory |
| PlusPF, PlusPFP and their -8 / -16 versions | 7.5 to 270 GiB | Samples that may also contain protozoa, fungi or plants |

The databases are **updated about every 3 to 4 months**. Each release has its date in the file names (for example `k2_standard_20261022.tar.gz`), and the previous releases move to the section *Old Kraken2 + Bracken* of the same page. Always copy the URL from the page, and write down the release you use: results from different releases aren't directly comparable.

* **On an AWS EC2 instance, to AWS EFS:** step by step, with the checksum check, in [aws/database-setup/kraken2](../../aws/database-setup/kraken2).
* **For a quick local test:** the 8 GB MiniKraken2 database of the [Quick start](#quick-start), from 2019 (section *Old Minikraken*), or the current Standard-8.
* Notes on building the Standard database on AWS yourself: [How to create Kraken2 Standard (v2.1.3) DB in AWS](https://github.com/ldipotetjob/kraken2/tree/kraken2aws_profilingfromv2.1.3/docs/awsStandardDB#readme).

The image also includes `kraken2-build`, if you really need to build your own database (for example with your own genomes):

```shell
docker run --rm genomixcloud/kraken2 kraken2-build --help
```

## Running on AWS

These are ideas for deploying Kraken2 on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the Kraken2 database lives on **AWS EFS**, the image is stored in **AWS ECR**, and **AWS Batch** runs the classification jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, add the following code and rebuild the image:

   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
       wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. Store the Kraken2 Standard database in a volume on AWS EFS.
3. In `/src/kraken2.sh`, link the **in** and **out** folders to AWS S3 and the database path to the volume on AWS EFS. Kraken2 can't read `s3://` paths directly, so the script must copy the reads from S3 first and copy the results back afterwards. You can put the links and the Kraken2 parameters in `conf/kraken.ini`.
4. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/kraken2 /src/kraken2.sh
   ```

5. Push the image to your AWS account (**AWS ECR**).
6. Create an AWS Batch job, linked to the volume on AWS EFS, that points to the Kraken2 image in AWS ECR.

Recommendations for production:

1. Don't use [--memory-mapping in production](https://github.com/ldipotetjob/kraken2/blob/kraken2aws_profilingfromv2.1.3/docs/Kraken2paramsonAWS/memory-mapping.md#memory-mapping-option): give the job enough memory to load the database.
2. Store the Kraken2 Standard (v2.1.3) database on AWS EFS.
3. See the [profiling information](https://github.com/ldipotetjob/kraken2/tree/kraken2aws_profilingfromv2.1.3/docs/awsStandardDB/profilingpngs).

For the detailed AWS guide see [aws/database-setup/kraken2](../../aws/database-setup/kraken2), and for benchmarks [aws/performance/kraken2](../../aws/performance/kraken2).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=kraken2 DOCKER_TAG=my_version
docker run --rm kraken2:my_version kraken2 --version
docker run --rm kraken2:my_version blastn -version
docker run --rm kraken2:my_version kraken2-build --help
```

Or with Docker only:

```shell
cd tools/kraken2
docker build --platform=linux/amd64 -t kraken2:my_version .
```

Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 22.04 image with Kraken2 (built from source), BLAST+ and rsync |
| `src/kraken2.sh` | Script, copied to `/src` in the image: calls `kraken2` with the settings in `/conf/kraken.ini` (an environment variable with the same name overrides each one) |
| `conf/kraken.ini` | Configuration, copied to `/conf` in the image: one `KEY=VALUE` line per setting, for the input reads, database and output folder |
| `test.sh` | Smoke test, run by `make test`: checks the Kraken2 version, `kraken2-build` and BLAST+ |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| The container is killed while loading the database | Not enough memory for the database. Add `--memory-mapping`, or give Docker more memory |
| `kraken2: database ("...") does not contain necessary file taxo.k2d` | `--db` must point to the folder with the `.k2d` files. Move them up if the archive extracted them into a subfolder |
| The screen fills with one line per read | Add `--output <file>` |
| The output files aren't written | Create the output folder first: Kraken2 doesn't create it |

Known issues in the image, not fixed yet:

* The Dockerfile sets `LC_ALL=C` to override the locale, which isn't recommended (see the comment in the Dockerfile).

## Citation

If you use this image, please cite Kraken2:

> Wood, D. E., Lu, J., & Langmead, B. (2019). Improved metagenomic analysis with Kraken 2. *Genome Biology*, 20(1), 257. https://doi.org/10.1186/s13059-019-1891-0

## Licence and references

* Kraken2 is distributed under its own licence: [Kraken2 licence](https://github.com/DerrickWood/kraken2/blob/master/LICENSE). This image only packages it.
* [Kraken2 software](https://github.com/DerrickWood/kraken2)
* [Kraken2 manual](https://github.com/DerrickWood/kraken2/blob/master/docs/MANUAL.markdown)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
