# QUAST Docker image

A ready-to-run Linux Docker image of [QUAST](https://github.com/ablab/quast), for the quality assessment of genome assemblies, with or without a reference genome.

| | |
|---|---|
| **Image** | [`genomixcloud/quast`](https://hub.docker.com/r/genomixcloud/quast) |
| **Tool version** | QUAST 5.2.0 |
| **Platform** | `linux/amd64` |
| **Database** | None. A reference genome is optional |
| **Input → output** | One or more assemblies (FASTA) → assembly metrics report (TXT, TSV, HTML) |
| **Pipeline step** | After assembly ([SPAdes](../spades)) and polishing ([Pilon](../pilon)), next to [CheckM](../checkm) |

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
docker pull genomixcloud/quast
docker run --rm genomixcloud/quast quast.py --version

# 2. Compare the two test assemblies from the data folder of this repo
cd data
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/quast quast.py \
  /data/data_fasta/contigs_1.fasta /data/data_fasta/contigs_2.fasta \
  -r /data/data_fasta/reference.fasta.gz \
  -o /data/data_out
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 18.04 | |
| QUAST | 5.2.0 | From the GitHub release, installed with `setup.py install` |
| Python | 2.7 (Ubuntu 18.04) | With matplotlib, simplejson and joblib from Ubuntu packages |
| Java | Ubuntu 18.04 `default-jdk` | |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** one or more assemblies (contigs or scaffolds) in FASTA format. Gzipped files are accepted.
* **Reference (optional):** a reference genome in FASTA format (`-r`) and its gene annotations in GFF format (`-g`) give more metrics, such as misassemblies and genome fraction.
* **Database:** none.
* **Resources:** light for bacterial genomes. Use `--threads` to set the number of CPUs.

## Usage

From the `data` folder of this repo:

```md
data
└── data_fasta
    ├── contigs_1.fasta
    ├── contigs_2.fasta
    └── reference.fasta.gz
```

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/quast quast.py \
  /data/data_fasta/contigs_1.fasta /data/data_fasta/contigs_2.fasta \
  -r /data/data_fasta/reference.fasta.gz \
  -o /data/data_out
```

Useful options:

| Option | Meaning |
|--------|---------|
| `-o <folder>` | Output folder |
| `-r <file>` | Reference genome |
| `-g <file>` | Gene annotations of the reference, in GFF format. This repo has no `genes.gff` for the test reference |
| `-l <labels>` | Names of the assemblies in the report, separated by commas |
| `-m <n>` | Minimum contig length. Default: 500 |
| `--threads <n>` | Number of CPUs |

## Outputs

QUAST writes its results to the output folder:

| File | Content |
|------|---------|
| `report.txt` / `report.tsv` / `report.html` | Summary of the assembly metrics (N50, number of contigs, total length, misassemblies, genome fraction...) |
| `transposed_report.txt` / `transposed_report.tsv` | The same summary, with one assembly per line |
| `icarus.html` | Icarus contig browser, to open in a browser |
| `basic_stats/` | Plots of the basic statistics |
| `quast.log` | Run log |

## Database setup

QUAST doesn't need a database.

## Running on AWS

These are ideas for deploying QUAST on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

   ```dockerfile
   RUN wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. In `/src/quast.sh`, link the **in** and **out** folders to AWS S3. You can put the links and the QUAST parameters in `conf/quast.ini`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/quast /src/quast.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the QUAST image in AWS ECR.

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=quast DOCKER_TAG=my_version BUILD_ARG="DEBIAN_FRONTEND=noninteractive"
docker run --rm quast:my_version quast.py -h
```

Or with Docker only:

```shell
cd tools/quast
docker build --platform=linux/amd64 --build-arg DEBIAN_FRONTEND=noninteractive -t quast:my_version .
```

`DEBIAN_FRONTEND=noninteractive` stops the build from asking for a timezone. Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with Python, Java and QUAST |
| `src/quast.sh` | Template script, copied to `/src` in the image: calls `quast.py` with the variables set in `quast.ini` |
| `conf/quast.ini` | Configuration template, copied to `/conf` in the image, for the input files and output folder |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| The build stops asking for a timezone | Add `--build-arg DEBIAN_FRONTEND=noninteractive` |
| Misassemblies and genome fraction are missing | They need a reference genome: add `-r` |
| Short contigs aren't counted | QUAST ignores contigs shorter than 500 bp. Change it with `-m` |

Known issues in the image, not fixed yet:

* QUAST runs on Python 2.7, which is no longer supported. QUAST 5.2.0 also runs on Python 3.
* `src/quast.sh` is a template: the variables it uses aren't read from `conf/quast.ini` yet. Its header comment was copied from SPAdes and still names that tool.
* Ubuntu 18.04 is no longer supported by Ubuntu.

## Citation

If you use this image, please cite QUAST:

> Gurevich, A., Saveliev, V., Vyahhi, N., & Tesler, G. (2013). QUAST: quality assessment tool for genome assemblies. *Bioinformatics*, 29(8), 1072–1075. https://doi.org/10.1093/bioinformatics/btt086

## Licence and references

* QUAST is distributed under its own licence: see the [QUAST repository](https://github.com/ablab/quast). This image only packages it.
* [QUAST software](https://github.com/ablab/quast)
* [QUAST manual](https://quast.sourceforge.net/docs/manual.html)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
