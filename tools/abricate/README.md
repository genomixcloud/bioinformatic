# ABRicate Docker image

A ready-to-run Linux Docker image of [ABRicate](https://github.com/tseemann/abricate), for the mass screening of contigs for antimicrobial resistance and virulence genes.

| | |
|---|---|
| **Image** | [`genomixcloud/abricate`](https://hub.docker.com/r/genomixcloud/abricate) |
| **Tool version** | ABRicate 1.0.1 |
| **Platform** | `linux/amd64` |
| **Database** | Included in the image (downloaded at build time) |
| **Input → output** | Contigs (FASTA, GenBank or EMBL) → table of genes found (TSV) |
| **Pipeline step** | After assembly ([SPAdes](../spades), [Pilon](../pilon)) |

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
# 1. Pull the image and check the installation
docker pull genomixcloud/abricate
docker run --rm genomixcloud/abricate abricate --version
docker run --rm genomixcloud/abricate abricate --check

# 2. Download a small test genome
curl -o contig.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz
gunzip -k < contig.gz > contig.fasta

# 3. Screen it
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/abricate abricate contig.fasta > out.tab
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 18.04 | |
| ABRicate | 1.0.1 | From the GitHub release `v1.0.1` |
| BLAST+ | Ubuntu 18.04 package (`ncbi-blast+`) | |
| any2fasta | latest from `master` | Converts GenBank and EMBL input to FASTA |
| BioPerl and Perl modules | Ubuntu 18.04 packages | |
| ABRicate databases | as on the build date | Set up with `abricate --setupdb` when the image is built |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** contigs in FASTA, GenBank or EMBL format. Gzipped files are accepted.
* **Database:** none to download. The ABRicate databases are inside the image. To list them, run `abricate --list`.
* **Resources:** light. Use `--threads` to set the number of CPUs.

## Usage

ABRicate writes its results to standard output, so redirect them to a file. Mount your data folder on `/data`, the working folder of the container:

```shell
mkdir -p data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/abricate abricate contig.fasta > data_out/out.tab
```

Useful options:

| Option | Meaning |
|--------|---------|
| `--db <name>` | Database to use. Default: `ncbi`. For example `--db vfdb` for virulence factors. `abricate --list` shows them all |
| `--minid <n>` | Minimum % identity. Default: 80 |
| `--mincov <n>` | Minimum % coverage. Default: 80 |
| `--threads <n>` | Number of CPUs |
| `--summary` | Combine several result tables into one presence/absence matrix |

Test data, if you don't have your own genome:

```shell
# Linux
wget https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz -O contig.gz
# macOS
curl -o contig.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz

gunzip -k < contig.gz > contig.fasta
```

## Outputs

A tab-separated table with one line per gene found, with these columns:

| Column | Content |
|--------|---------|
| `FILE`, `SEQUENCE` | Input file and contig |
| `START`, `END`, `STRAND` | Position of the gene on the contig |
| `GENE` | Gene name |
| `COVERAGE`, `COVERAGE_MAP`, `GAPS`, `%COVERAGE` | How much of the reference gene is covered |
| `%IDENTITY` | Identity with the reference gene |
| `DATABASE`, `ACCESSION`, `PRODUCT` | Database, reference accession and product |
| `RESISTANCE` | Antibiotic classes, when the database provides them |

## Database setup

No setup is needed: the databases are downloaded and indexed when the image is built. To get newer versions of the databases, rebuild the image (see [Build and test](#build-and-test)).

## Running on AWS

These are ideas for deploying ABRicate on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
       wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. In `/src/abricate.sh`, link the **in** and **out** folders to AWS S3. You can put the links and the ABRicate parameters in `conf/abricate.ini`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/abricate /src/abricate.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the ABRicate image in AWS ECR.

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=abricate DOCKER_TAG=my_version
docker run --rm abricate:my_version abricate --check
```

Or with Docker only:

```shell
cd tools/abricate
docker build --platform=linux/amd64 -t abricate:my_version .
```

Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with ABRicate, BLAST+, any2fasta and the ABRicate databases |
| `src/abricate.sh` | Template script, copied to `/src` in the image: calls `abricate` with the variables set in `abricate.ini` |
| `conf/abricate.ini` | Configuration template, copied to `/conf` in the image, for the input file, database and output folder |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| The output file has log messages or Windows line endings | Don't use `-t` (`-ti`) in `docker run` when you redirect the output to a file |
| No genes found | Check the database with `--db` and lower `--minid` or `--mincov` if needed |

Known issues in the image, not fixed yet:

* **The databases and any2fasta depend on the build date.** `abricate --setupdb` downloads the current databases, and any2fasta is taken from `master`. Two builds on different dates can give different results. Write down the build date of the image you use for a study.
* `src/abricate.sh` is a template: the variables it uses (`$contig_fasta`, `$database`, `$DATA_OUT`) aren't read from `conf/abricate.ini` yet.
* Ubuntu 18.04 is no longer supported by Ubuntu.

## Citation

ABRicate has no paper. Please cite the software and the database you used (`abricate --list` shows the source of each one):

> Seemann, T. ABRicate: mass screening of contigs for antimicrobial and virulence genes. https://github.com/tseemann/abricate

For example, for the ResFinder database:

> Zankari, E., Hasman, H., Cosentino, S., Vestergaard, M., Rasmussen, S., Lund, O., Aarestrup, F. M., & Larsen, M. V. (2012). Identification of acquired antimicrobial resistance genes. *Journal of Antimicrobial Chemotherapy*, 67(11), 2640–2644. https://doi.org/10.1093/jac/dks261

## Licence and references

* ABRicate is distributed under its own licence: [ABRicate licence](https://github.com/tseemann/abricate/blob/master/LICENSE). Each database has its own licence too. This image only packages them.
* [ABRicate software and manual](https://github.com/tseemann/abricate)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
