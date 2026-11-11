# ABRicate

<!-- short: ABRicate 1.0.1: screening of contigs for antimicrobial resistance and virulence genes. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [ABRicate](https://github.com/tseemann/abricate) 1.0.1 for the mass screening of contigs for antimicrobial resistance and virulence genes. The databases are included in the image. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | ABRicate | Other tools in the image |
|-----|----------|--------------------------|
| `latest` | 1.0.1 | Ubuntu 22.04, BLAST+ 2.12.0, any2fasta 0.9.0, and the 9 databases bundled with ABRicate 1.0.1 |
| `v.1.0.1` | 1.0.1 | Earlier build, from November 2023 |

Databases in the image (as bundled with ABRicate 1.0.1, so they don't change between builds):

| Database | Sequences | Content |
|----------|-----------|---------|
| `ncbi` (default) | 5,386 | NCBI AMRFinderPlus resistance genes |
| `card` | 2,631 | CARD resistance genes |
| `resfinder` | 3,077 | ResFinder resistance genes |
| `argannot` | 2,223 | ARG-ANNOT resistance genes |
| `megares` | 6,635 | MEGARes resistance genes |
| `vfdb` | 2,597 | VFDB virulence factors |
| `ecoli_vf` | 2,701 | *E. coli* virulence factors |
| `plasmidfinder` | 460 | PlasmidFinder replicons |
| `ecoh` | 597 | EcOH *E. coli* O and H antigen genes |

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/abricate
docker run --rm genomixcloud/abricate abricate --version

# 2. Download a small test genome (if you don't have your own contigs)
curl -o contig.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz
gunzip -k < contig.gz > contig.fasta

# 3. Screen it: run from the folder with the contigs, and create the output folder first
mkdir data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/abricate abricate contig.fasta > data_out/out.tab
```

On Linux you can download the test genome with `wget` instead:

```shell
wget https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz -O contig.gz
gunzip -k < contig.gz > contig.fasta
```

ABRicate writes a tab-separated table to standard output, one line per gene found, so redirect it to a file. Don't use `-t` (`-ti`) in `docker run` when you redirect the output: it mixes log messages into the results. Use `--db <name>` for another database, for example `--db vfdb`, and `abricate --list` to see them all.

## Requirements

* **Input:** contigs in FASTA, GenBank or EMBL format. Gzipped files are accepted.
* **Database:** none to download: the databases are inside the image.
* **Resources:** light. Use `--threads` to set the number of CPUs.

## Documentation

Full documentation, options, outputs and test data: [tools/abricate on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/abricate).

* [Running ABRicate on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/abricate#running-on-aws)
* [How to build the ABRicate image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/abricate#build-and-test)

## Licence

ABRicate is distributed under the [GPL v2 licence](https://github.com/tseemann/abricate/blob/master/LICENSE). Each database has its own licence. The image only packages them.

ABRicate has no paper. Please cite the software, and the database you used: Seemann, T. ABRicate: mass screening of contigs for antimicrobial and virulence genes. https://github.com/tseemann/abricate

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
