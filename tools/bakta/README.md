# Bakta Docker image

A ready-to-run Linux Docker image of [Bakta](https://github.com/oschwengers/bakta), for the rapid and standardized annotation of bacterial genomes, metagenome-assembled genomes (MAGs) and plasmids.

| | |
|---|---|
| **Image** | [`genomixcloud/bakta`](https://hub.docker.com/r/genomixcloud/bakta) |
| **Tool version** | Bakta 1.11.4 |
| **Platform** | `linux/amd64` |
| **Database** | Required: light (a few GB) or full (about 64 GB) |
| **Input → output** | Assembly (FASTA) → annotation (GFF3, GenBank, EMBL, TSV, FASTA, JSON) |
| **Pipeline step** | After assembly ([SPAdes](../spades), [Pilon](../pilon)) and before pan-genome analysis ([Roary](../roary)) |

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

This example uses the Bakta **light database** so you can try the image quickly. For real analyses use the full database (see [Database setup](#database-setup)).

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/bakta
docker run --rm genomixcloud/bakta /src/bakta.sh --version

# 2. Download the light database into the current folder (creates ./db-light)
docker run --rm --mount src="$(pwd)",target=/data,type=bind genomixcloud/bakta \
  /bin/bash -c "source activate bakta_env && bakta_db download --output /data --type light"

# 3. Download a small test genome
curl -o contig.fasta.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz
gunzip contig.fasta.gz

# 4. Annotate it
docker run --rm --mount src="$(pwd)",target=/data,type=bind genomixcloud/bakta \
  /src/bakta.sh --db /data/db-light contig.fasta --output data_out
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 20.04 | |
| Bakta | 1.11.4 | Pinned in `environment.yaml` |
| AMRFinderPlus | ≥ 3.11.2 | Annotation of antimicrobial resistance genes. Only a minimum version is set |
| pyhmmer | 0.11.3 | |
| Python | 3.10 | |
| Conda environment | `bakta_env` | Activated by `/src/bakta.sh` |

The other dependencies are resolved by conda when the image is built. See [Troubleshooting](#troubleshooting) about reproducibility.

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** genome assemblies (contigs) in FASTA format.
* **Database (mandatory):** Bakta can't run without its database:
  * **full:** more than 30 GB compressed, **about 64 GB uncompressed**. Recommended for real analyses.
  * **light:** a few GB. Good for testing.
* **Storage:** keep the database in external storage, or on AWS EFS when running on AWS, and mount it into the container.
* **Resources:** annotation is CPU intensive. Use `--threads` to set the number of CPUs. Benchmarks on several AWS instance types are in [aws/performance/bakta](../../aws/performance/bakta).

## Usage

Mount your data folder on `/data` (the working folder of the container) and the database on `/db`:

```shell
docker run --rm \
  --mount src="$(pwd)",target=/data,type=bind \
  --mount src=/path/to/external/storage/db,target=/db,type=bind \
  genomixcloud/bakta /src/bakta.sh --db /db --threads 16 contig.fasta --output data_out
```

`/src/bakta.sh` activates the conda environment and passes all its arguments to `bakta`, so every [Bakta option](https://github.com/oschwengers/bakta#usage) works. Some useful ones:

| Option | Meaning |
|--------|---------|
| `--db <path>` | Database folder (mandatory) |
| `--output <folder>` | Output folder. Bakta creates it |
| `--prefix <name>` | Prefix of the output files. Default: the input file name |
| `--threads <n>` | Number of CPUs |
| `--genus`, `--species`, `--strain` | Organism names written into the annotation |
| `--force` | Write into an output folder that already exists |

Test data, if you don't have your own genome:

```shell
# Linux
wget https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz -O contig.fasta.gz
# macOS
curl -o contig.fasta.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz

gunzip contig.fasta.gz
```

## Outputs

Bakta writes its results to the output folder, with the input file name as prefix:

| File | Content |
|------|---------|
| `.tsv` | Annotations as a simple tab-separated table |
| `.gff3` | Annotations and sequences in GFF3 format. This is the input of [Roary](../roary) |
| `.gbff` | Annotations and sequences in GenBank format |
| `.embl` | Annotations and sequences in EMBL format |
| `.fna` | Replicon and contig DNA sequences |
| `.ffn` | Feature nucleotide sequences |
| `.faa` | CDS and sORF amino acid sequences |
| `.json` | All results in machine-readable JSON |
| `.txt` | Summary of the annotation |
| `.png` / `.svg` | Circular genome plot |
| `.hypotheticals.tsv` / `.hypotheticals.faa` | Further information on hypothetical proteins |
| `.inference.tsv` | Inference metrics for each feature |
| `.log` | Run log |

## Database setup

Because of its size, download the full database to external storage:

1. Move to your external storage.
2. Start a shell in the container and download the database. Inside the container `/data` is the working folder, but you can give any path of your external storage:

```shell
docker run --rm -ti --mount src="$(pwd)",target=/data,type=bind genomixcloud/bakta bash
bakta_db download --output /data --type full
```

The database is downloaded to the `db` folder inside the output folder. Mount that folder on `/db` when you run Bakta.

To set up the database on an AWS EC2 instance, see [aws/database-setup/bakta](../../aws/database-setup/bakta). More options: [Bakta database download](https://github.com/oschwengers/bakta/blob/main/README.md#database-download).

## Running on AWS

These are ideas for deploying Bakta on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the full database lives on **AWS EFS**, the image is stored in **AWS ECR**, and **AWS Batch** runs the annotation jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in `environment.yaml`, under **dependencies**, add `- awscli` and rebuild the image.
2. Store the full database (about 64 GB) in a volume on AWS EFS.
3. In `/src/bakta.sh`, link the **in** and **out** folders to AWS S3 and the database path to the volume on AWS EFS. You can put both in `conf/bakta.ini`.
4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job, linked to the volume on AWS EFS, that points to the Bakta image in AWS ECR.

For the detailed AWS guide see [aws/database-setup/bakta](../../aws/database-setup/bakta), and for benchmarks [aws/performance/bakta](../../aws/performance/bakta).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=bakta DOCKER_TAG=my_version BUILD_ARG="DEBIAN_FRONTEND=noninteractive"
docker run --rm bakta:my_version /src/bakta.sh --version
```

Or with Docker only:

```shell
cd tools/bakta
docker build --platform=linux/amd64 --build-arg DEBIAN_FRONTEND=noninteractive -t bakta:my_version .
```

Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with Miniconda and the `bakta_env` conda environment |
| `environment.yaml` | Conda environment: Bakta, AMRFinderPlus, pyhmmer and Python |
| `src/bakta.sh` | Entrypoint, copied to `/src` in the image: activates the conda environment and calls `bakta` with the given arguments |
| `conf/bakta.ini` | Configuration template for the S3 input and output folders. It isn't copied into the image yet |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| `ERROR: output path (...) already exists!` | Bakta creates the output folder itself. Don't create it before running, or add `--force` to write into it |
| Bakta stops at the start with a database error | `--db` must point to the folder that contains the database files (`db` or `db-light`), as seen inside the container |
| The run is slow | Set `--threads` to the number of CPUs you gave Docker |

Known issues in the image, not fixed yet:

* **Builds aren't reproducible.** The Dockerfile installs `Miniconda3-latest`, runs `conda update`, and `environment.yaml` pins only some packages (AMRFinderPlus has only a minimum version). Two builds of the same Dockerfile on different dates can contain different versions. The [Roary](../roary#reproducible-builds) image solves the same problem with an exact conda lock.
* `ENV PATH` points to `/opt/conda/envs/bakta_env/bin`, which doesn't exist; the environment is in `/root/miniconda3/envs/bakta_env`. `/src/bakta.sh` activates the environment, so it works, but calling `bakta` directly without activating it doesn't.

## Citation

If you use this image, please cite Bakta:

> Schwengers, O., Jelonek, L., Dieckmann, M. A., Beyvers, S., Blom, J., & Goesmann, A. (2021). Bakta: rapid and standardized annotation of bacterial genomes via alignment-free sequence identification. *Microbial Genomics*, 7(11). https://doi.org/10.1099/mgen.0.000685

## Licence and references

* Bakta is distributed under its own licence: [Bakta licence](https://github.com/oschwengers/bakta/blob/main/LICENSE). This image only packages it.
* [Bakta software and manual](https://github.com/oschwengers/bakta/blob/main/README.md)
* [Bakta database download](https://github.com/oschwengers/bakta/blob/main/README.md#database-download)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
