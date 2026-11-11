[![name](assets/genomixlogo.png)](https://genomixcloud.com/)

# Genomix Cloud Bioinformatic Tools

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/genomixcloud/bioinformatic?style=flat-square)
[![Docker Hub](https://img.shields.io/badge/docker%20hub-genomixcloud-blue?style=flat-square&logo=docker)](https://hub.docker.com/u/genomixcloud)
![Twitter Follow](https://img.shields.io/twitter/follow/genomixcloud?style=social)

## Table of Contents

* [About](#about)
  * [Tools](#tools)
  * [Microbial genome pipeline](#microbial-genome-pipeline)
* [Repository structure](#repository-structure)
* [Installing the images](#installing-the-images)
* [Building and publishing with make](#building-and-publishing-with-make)
* [Running the images](#running-the-images)
* [Running on AWS](#running-on-aws)
* [Helper scripts](#helper-scripts)
* [Test data](#test-data)
* [Support](#support)
* [License](#license)

## About

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.

This repository hosts the source code of the plain Docker images of the bioinformatic tools that are part of the Genomix Cloud platform. These images form the foundation of our suite of bioinformatic tools and support various genomic analysis tasks. You will find instructions on building the Docker images used in our workflows, and suggestions for improving performance and automation within the AWS ecosystem.

Please note that this repository is continuously evolving. See the [Manifest](Manifest.md) for the goals and roadmap of the project, and the [Changelog](CHANGELOG.md) for notable changes.

### Tools

| Tool | Purpose |
|------|---------|
| [Abricate](tools/abricate) | Screening of contigs for antimicrobial resistance and virulence genes |
| [Bakta](tools/bakta) | Annotation of bacterial genomes and plasmids |
| [CheckM](tools/checkm) | Quality assessment of genomes (completeness and contamination) |
| [FastQC](tools/fastqc) | Quality control of raw sequencing reads |
| [FastP](tools/fastp) | Trimming and filtering of sequencing reads |
| [FimTyper](tools/fimtyper) | FimH typing of *E. coli* |
| [Kraken2](tools/kraken2) | Taxonomic classification of sequencing reads |
| [Mlst](tools/mlst) | Multi-locus sequence typing of contigs |
| [Pilon](tools/pilon) | Polishing and improvement of genome assemblies |
| [Platon](tools/platon) | Identification of plasmid contigs |
| [Prokka](tools/prokka) | Annotation of prokaryotic genomes |
| [Quast](tools/quast) | Quality assessment of genome assemblies |
| [Roary](tools/roary) | Pan-genome analysis |
| [SPAdes](tools/spades) | Genome assembly |
| [MacSyFinder](tools/macsyfinder) | Detection of macromolecular systems (work in progress) |

### Microbial genome pipeline

![Microbial Genome Pipeline](assets/microbial_genome_pipeline.svg 'Microbial Genome Pipeline')

## Repository structure

```
bioinformatic/
├── tools/                  # one folder per tool
│   └── <tool>/
│       ├── Dockerfile
│       ├── README.md
│       ├── test.sh         # optional smoke test, run by `make test`
│       ├── conf/           # tool configuration (.ini)
│       └── src/            # entrypoint scripts
├── aws/
│   ├── database-setup/     # install tools and download their databases on EC2
│   └── performance/        # benchmark results and graphs per tool
├── data/                   # test data (reads, contigs, gff files)
├── binaries/               # third-party binaries used by some images
├── scripts/                # helper scripts used between the tools of the pipeline
├── assets/                 # images used in the documentation
├── dockerhub/              # Docker Hub page of each image (<tool>.md)
├── Makefile                # build, test and push any tool image
├── CHANGELOG.md
└── Manifest.md
```

## Installing the images

Prebuilt images (Linux/amd64, Ubuntu based) are available on [Docker Hub](https://hub.docker.com/u/genomixcloud):

```shell
docker pull genomixcloud/<tool>
```

To build an image from source, use the [Makefile](#building-and-publishing-with-make) from the root of the repository:

```shell
make build DOCKER_IMAGE=<tool> DOCKER_TAG=my_version
```

Or move to the tool folder and build it with Docker:

```shell
cd tools/<tool>
docker build --platform=linux/amd64 -t <tool>:my_version .
```

Building requires Docker > 24.0.2.

## Building and publishing with make

The [Makefile](Makefile) in the root of the repository is generic: the same targets work for every tool that has a `tools/<tool>/Dockerfile`. You choose the tool with `DOCKER_IMAGE`, and the Makefile builds the image from `tools/<tool>`, runs its smoke test and pushes it to Docker Hub. It saves you typing the same long `docker build`, `docker tag` and `docker push` commands for each tool, and makes every image get built the same way.

### Targets

| Target | What it does |
|--------|--------------|
| `make` or `make help` | Shows the usage, targets and variables |
| `make list` | Lists the tools that have a `tools/<tool>/Dockerfile` |
| `make build` | Builds `tools/<tool>` as the local image `<tool>:<tag>`, for `linux/amd64` |
| `make test` | Runs `tools/<tool>/test.sh <tool>:<tag>` if the tool has one, otherwise it says the test is skipped |
| `make push` | Tags `<tool>:<tag>` as `<account>/<tool>:<tag>` and pushes it to Docker Hub |
| `make build-all` | `build`, then `test`, then `push`. It stops at the first step that fails, so an image that fails its test is never pushed |
| `make clean` | Removes the local `<tool>:<tag>` and `<account>/<tool>:<tag>` images. Docker Hub isn't touched |

`build`, `test`, `push` and `clean` first check that `DOCKER_IMAGE` is set and that its folder has a Dockerfile. `push` also checks that the local image exists, so run `build` first.

### Variables

| Variable | Default | Meaning |
|----------|---------|---------|
| `DOCKER_IMAGE` | (required) | Tool name, the same as its folder in `tools/` |
| `DOCKER_TAG` | `latest` | Image tag |
| `DOCKER_DIR` | `tools/<DOCKER_IMAGE>` | Build context, if it's somewhere else |
| `DOCKERHUB_ACCOUNT` | `genomixcloud` | Docker Hub user or organisation to push to |
| `CACHE` | empty | `--no-cache` to build without the Docker cache |
| `BUILD_ARG` | empty | Build arguments: `"KEY=VALUE KEY2=VALUE2"` or `"--build-arg KEY=VALUE ..."` (both work) |
| `PLATFORM` | `linux/amd64` | Target platform. The images are built for `linux/amd64` only |

### Examples

```shell
# Build roary without cache
make build DOCKER_IMAGE=roary CACHE=--no-cache BUILD_ARG="DEBIAN_FRONTEND=noninteractive"

# Build, test and push quast as genomixcloud/quast:5.2.0
make build-all DOCKER_IMAGE=quast DOCKER_TAG=5.2.0 BUILD_ARG="--build-arg DEBIAN_FRONTEND=noninteractive"

# Push an image you already built to your own Docker Hub account
make push DOCKER_IMAGE=bakta DOCKERHUB_ACCOUNT=myuser
```

`DEBIAN_FRONTEND=noninteractive` stops Ubuntu based builds from asking for a timezone.

### Publishing to Docker Hub

`make push` assumes you are already logged in to Docker Hub with an account that can write to `DOCKERHUB_ACCOUNT`:

```shell
docker login
```

The Makefile doesn't handle credentials. If the repository `<account>/<tool>` doesn't exist yet, Docker Hub creates it on the first push, if the account allows it.

Push a fixed version tag, such as `3.13.0` or `3.13.0-2026.11`, and not only `latest`. Don't overwrite a tag that's in use in production. Then you can always go back to an image that you know works.

### Smoke tests

A tool can have a `tools/<tool>/test.sh`. It receives the image name (`<tool>:<tag>`) as its only argument and must exit with a non-zero code if something is wrong. `make test` and `make build-all` run it. Keep it short: check that the main commands start and have the expected versions, not a full analysis. See [tools/roary/test.sh](tools/roary/test.sh) for an example: it checks the roary and FastTree versions, builds a small tree, loads the modules of `roary2svg.pl` and converts an SVG to PNG.

Tools without a `test.sh` are built and pushed without a test.

## Running the images

Mount the folder with your data into the container at `/data` and run the tool:

```shell
docker run --name <tool> --rm -ti --mount src="$(pwd)",target=/data,type=bind \
genomixcloud/<tool>:my_version <tool command>
```

Each tool's README has the exact commands, test data and options.

## Running on AWS

The [aws](aws) folder contains guidance for running the tools in the AWS ecosystem:

* [database-setup](aws/database-setup): scripts to install the tools and download their databases on an EC2 Ubuntu instance.
* [performance](aws/performance): benchmark results and graphs of the tools on different instance types.

Each tool's README also explains how to add the AWS CLI to the image so it can read input from and write output to Amazon S3.

## Helper scripts

The [scripts](scripts) folder holds small scripts that prepare the output of one tool for the next one. They aren't part of any image yet.

### rename_contigs.sh

Prepares a Bakta GFF3 file so Roary can use it. Run it once for each sample, on the `.gff3` that Bakta writes:

```shell
scripts/rename_contigs.sh <input.gff3> <sample_name> <output.gff>
# Example
scripts/rename_contigs.sh data_out/assembly.gff3 S01 roary_in/S01.gff
```

**Why it's needed:**

* **Bakta names the contigs the same way in every sample** (`contig_1`, `contig_2`, ...). When Roary combines all the samples, the same contig ID appears in several genomes. The script renames `contig_N` to `<sample_name>_contig_N` everywhere in the file, in the features and in the `##FASTA` headers, so every contig ID is unique across samples.
* **Bakta writes a `##feature-ontology` header line that breaks Roary's GFF parser.** The script removes it.
* It also removes Windows line endings.

**Checks:** the script stops with an error if the input is missing or empty, if it has no `##FASTA` section (Roary needs the sequences at the end of the GFF), if the sample name has characters other than letters, digits, `_` or `-`, or if any `contig_N` is left without the prefix. When it succeeds, it prints the number of contigs and CDS in the output.

It doesn't fix gene names that differ only in punctuation, which Roary merges in the core alignment. See [Gene names from Bakta](tools/roary#gene-names-from-bakta) in the Roary README.

**Where it goes in the workflow:** between [Bakta](tools/bakta) and [Roary](tools/roary), on each Bakta GFF3 before all the samples are passed to Roary. The exact point where the platform pipeline calls it will be defined in a future refactoring.

## Test data

The [data](data) folder contains a complete dataset to test every tool in the pipeline:

* `data_in_raw`: raw paired-end reads
* `data_in_trimmed`: trimmed paired-end reads
* `data_fasta`: contigs, scaffolds and a reference genome
* `data_fna`: genomic sequences
* `data_gff_bakta`: annotation files from Bakta
* `data_gff_prokka`: annotation files from Prokka

## Support

* Email: ldipotet@genomixcloud.com

## License

Each bioinformatic tool packaged in these images is distributed under its own license. Please check the upstream project of each tool before using it.

