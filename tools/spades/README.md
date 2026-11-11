# SPAdes Docker image

A ready-to-run Linux Docker image of [SPAdes](https://github.com/ablab/spades), for the de novo assembly of genomes from sequencing reads.

| | |
|---|---|
| **Image** | [`genomixcloud/spades`](https://hub.docker.com/r/genomixcloud/spades) |
| **Tool version** | SPAdes 3.15.5 |
| **Platform** | `linux/amd64` |
| **Database** | None |
| **Input → output** | Trimmed reads (FASTQ) → contigs and scaffolds (FASTA) |
| **Pipeline step** | After trimming ([fastp](../fastp)) and before polishing ([Pilon](../pilon)) and quality assessment ([QUAST](../quast), [CheckM](../checkm)) |

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
# 1. Pull the image and run the SPAdes self-test on its built-in toy data
docker pull genomixcloud/spades
docker run --rm genomixcloud/spades spades.py --isolate --test

# 2. Assemble the trimmed test reads from the data folder of this repo
cd data/data_in_trimmed
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/spades spades.py --careful \
  -1 trimmed_reads_1.fastq.gz -2 trimmed_reads_2.fastq.gz \
  -o ./data_out
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 20.04 | The prebuilt SPAdes 3.15.5 binaries crash (segmentation fault) on Ubuntu 22.04 |
| SPAdes | 3.15.5 | Prebuilt Linux binaries from the GitHub release. A copy is in [binaries](../../binaries) |
| Python | 3.8 (Ubuntu 20.04) | Runs `spades.py`. `python-is-python3` provides the `python` command |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** single-end or paired-end reads in FASTQ format. Gzipped files are accepted. Trim them first, for example with [fastp](../fastp).
* **Database:** none.
* **Resources:** assembly is memory and CPU intensive. Give Docker enough memory, use `-t` to set the number of CPUs and `-m` to set the memory limit in GB (250 GB by default).

## Usage

From the `data/data_in_trimmed` folder of this repo, which contains the trimmed reads:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/spades spades.py --careful \
  -1 trimmed_reads_1.fastq.gz -2 trimmed_reads_2.fastq.gz \
  -o ./data_out
```

SPAdes creates the output folder. Useful options:

| Option | Meaning |
|--------|---------|
| `-1`, `-2` | Paired-end reads 1 and 2 |
| `-s` | Single-end reads |
| `-o <folder>` | Output folder. SPAdes creates it |
| `--careful` | Reduce mismatches and short indels. Not compatible with `--isolate` |
| `--isolate` | Recommended for high-coverage isolate data |
| `-t <n>` | Number of CPUs. Default: 16 |
| `-m <n>` | Memory limit in GB. Default: 250 |
| `-k <list>` | k-mer sizes, for example `21,33,55`. Default: chosen automatically |
| `--continue` | Restart a run that stopped, from the last checkpoint |

## Outputs

SPAdes writes its results to the output folder:

| File | Content |
|------|---------|
| `contigs.fasta` | The assembled contigs. This is the input of the next tools |
| `scaffolds.fasta` | The assembled scaffolds |
| `assembly_graph.fastg` / `assembly_graph_with_scaffolds.gfa` | The assembly graph |
| `params.txt` | Parameters used for the run |
| `spades.log` | Run log |

## Database setup

SPAdes doesn't need a database.

## Running on AWS

These are ideas for deploying SPAdes on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the assembly jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
       wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. In `/src/spades.sh`, link the **in** and **out** folders to AWS S3. You can put the links and the SPAdes parameters in `conf/spades.ini`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/spades /src/spades.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the SPAdes image in AWS ECR. Give it enough memory for the assembly, and set `-m` to the job's memory (see [Requirements](#requirements)).

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=spades DOCKER_TAG=my_version
docker run --rm spades:my_version spades.py --isolate --test
```

Or with Docker only:

```shell
cd tools/spades
docker build --platform=linux/amd64 -t spades:my_version .
```

Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with Python 3 and the prebuilt SPAdes binaries |
| `test.sh` | Smoke test, run by `make test`: checks the SPAdes and Python versions and runs the SPAdes self-test |
| `src/spades.sh` | Script, copied to `/src` in the image: calls `spades.py` with the settings in `/conf/spades.ini` (an environment variable with the same name overrides each one) |
| `conf/spades.ini` | Configuration, copied to `/conf` in the image: one `KEY=VALUE` line per setting, for the input reads and output folder |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| SPAdes is killed or says it ran out of memory | Give Docker more memory and set `-m` to that amount in GB |
| `--careful` and `--isolate` can't be used together | Use only one of them. `--isolate` is recommended for high-coverage isolates |
| A long run stopped | Run again with `--continue -o <same folder>` |

Known issues in the image, not fixed yet:

* Ubuntu 20.04 is past its standard support. The prebuilt SPAdes 3.15.5 binaries crash on Ubuntu 22.04, so moving further needs SPAdes built from source or a newer SPAdes release, which would change the main tool version.

## Citation

If you use this image, please cite SPAdes:

> Bankevich, A., Nurk, S., Antipov, D., Gurevich, A. A., Dvorkin, M., Kulikov, A. S., Lesin, V. M., Nikolenko, S. I., Pham, S., Prjibelski, A. D., Pyshkin, A. V., Sirotkin, A. V., Vyahhi, N., Tesler, G., Alekseyev, M. A., & Pevzner, P. A. (2012). SPAdes: a new genome assembly algorithm and its applications to single-cell sequencing. *Journal of Computational Biology*, 19(5), 455–477. https://doi.org/10.1089/cmb.2012.0021

> Prjibelski, A., Antipov, D., Meleshko, D., Lapidus, A., & Korobeynikov, A. (2020). Using SPAdes de novo assembler. *Current Protocols in Bioinformatics*, 70(1), e102. https://doi.org/10.1002/cpbi.102

## Licence and references

* SPAdes is distributed under its own licence: see the [SPAdes repository](https://github.com/ablab/spades). This image only packages it.
* [SPAdes software](https://cab.spbu.ru/software/spades/)
* [SPAdes manual](https://cab.spbu.ru/files/release3.15.4/manual.html#sec2.4)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
