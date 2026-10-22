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
* [Running the images](#running-the-images)
* [Running on AWS](#running-on-aws)
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
│       ├── conf/           # tool configuration (.ini)
│       └── src/            # entrypoint scripts
├── aws/
│   ├── database-setup/     # install tools and download their databases on EC2
│   └── performance/        # benchmark results and graphs per tool
├── data/                   # test data (reads, contigs, gff files)
├── binaries/               # third-party binaries used by some images
├── assets/                 # images used in the documentation
├── CHANGELOG.md
└── Manifest.md
```

## Installing the images

Prebuilt images (Linux/amd64, Ubuntu based) are available on [Docker Hub](https://hub.docker.com/u/genomixcloud):

```shell
docker pull genomixcloud/<tool>
```

To build an image from source, move to the tool folder and build it:

```shell
cd tools/<tool>
docker build -t genomixcloud/<tool>:my_version .
```

Building requires Docker > 24.0.2.

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

## Test data

The [data](data) folder contains a complete dataset to test every tool in the pipeline:

* `data_in_raw`: raw paired-end reads
* `data_in_trimmed`: trimmed paired-end reads
* `data_fasta`: contigs, scaffolds and a reference genome
* `data_fna`: genomic sequences
* `data_gff`: annotation files

## Support

* Email: ldipotet@genomixcloud.com

## License

Each bioinformatic tool packaged in these images is distributed under its own license. Please check the upstream project of each tool before using it.

