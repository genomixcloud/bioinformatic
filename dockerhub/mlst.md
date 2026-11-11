# mlst

<!-- short: mlst 2.23.0: multi-locus sequence typing of assemblies against the PubMLST schemes. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [mlst](https://github.com/tseemann/mlst) 2.23.0 for the multi-locus sequence typing (MLST) of genome assemblies against the PubMLST schemes. The schemes are included in the image. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | mlst | Other tools in the image |
|-----|------|--------------------------|
| `latest` | 2.23.0 | Ubuntu 20.04, BLAST+ 2.9.0, any2fasta 0.4.2, and the 144 PubMLST schemes bundled with mlst 2.23.0 |
| `2.23.0` | 2.23.0 | Earlier build, from April 2024 |

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/mlst
docker run --rm genomixcloud/mlst mlst --version

# 2. Download the test genome and test contigs (if you don't have your own)
mkdir -p data/data_fna data/data_fasta && cd data
curl -o data_fna/example.fna.gz https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fna/example.fna.gz
curl -o data_fasta/contigs.fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta

# 3. Type them: run from the data folder
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/mlst mlst --csv /data/data_fna/example.fna.gz > mlst.csv

docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/mlst mlst --csv --nopath --quiet --threads 2 \
  /data/data_fasta/contigs.fasta > mlst_contigs.csv
```

On Linux you can download the test data with `wget` instead:

```shell
wget -P data_fna https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fna/example.fna.gz
wget -P data_fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta
```

The files are for testing only. The folder layout:

```md
data
├── data_fna
│   └── example.fna.gz
└── data_fasta
    └── contigs.fasta
```

mlst writes one line per genome to standard output, so redirect it to a file: the file name, the scheme found, the sequence type (ST) and the allele number of each locus. Don't use `-t` (`-ti`) in `docker run` when you redirect the output: it mixes log messages into the results. `mlst --list` shows the schemes, and `--scheme <name>` forces one.

## Requirements

* **Input:** genome assemblies in FASTA, GenBank or EMBL format. Gzipped files are accepted.
* **Database:** none to download: the PubMLST schemes are inside the image.
* **Resources:** light. Use `--threads` to set the number of CPUs.

## Documentation

Full documentation, options, outputs and test data: [tools/mlst on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/mlst).

* [Running mlst on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/mlst#running-on-aws)
* [How to build the mlst image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/mlst#build-and-test)

## Licence

mlst is distributed under the [GPL v2 licence](https://github.com/tseemann/mlst/blob/master/LICENSE). The PubMLST schemes have their own terms of use. The image only packages them.

If you use mlst, please cite the software and PubMLST: Seemann, T. mlst: scan contig files against PubMLST typing schemes. https://github.com/tseemann/mlst, and Jolley, K. A., Bray, J. E., & Maiden, M. C. J. (2018). Open-access bacterial population genomics: BIGSdb software, the PubMLST.org website and their applications. *Wellcome Open Research*, 3, 124. https://doi.org/10.12688/wellcomeopenres.14826.1

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
