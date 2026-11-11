# QUAST

<!-- short: QUAST 5.2.0: quality assessment of genome assemblies, with or without a reference. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [QUAST](https://github.com/ablab/quast) 5.2.0 for the quality assessment of genome assemblies (N50, number of contigs, misassemblies, genome fraction...), with or without a reference genome. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | QUAST | Other tools in the image |
|-----|-------|--------------------------|
| `latest` | 5.2.0 | Ubuntu 22.04, Python 3.10 with matplotlib, simplejson and joblib, Java (headless) |

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/quast
docker run --rm genomixcloud/quast quast.py --version

# 2. Download two test assemblies and a reference genome (if you don't have your own)
mkdir -p data/data_fasta && cd data
curl -o data_fasta/contigs_1.fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs_1.fasta
curl -o data_fasta/contigs_2.fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs_2.fasta
curl -o data_fasta/reference.fasta.gz https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/reference.fasta.gz

# 3. Compare them against the reference: run from the data folder
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/quast quast.py \
  /data/data_fasta/contigs_1.fasta /data/data_fasta/contigs_2.fasta \
  -r /data/data_fasta/reference.fasta.gz \
  -o /data/data_out
```

On Linux you can download the test data with `wget` instead:

```shell
wget -P data_fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs_1.fasta
wget -P data_fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs_2.fasta
wget -P data_fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/reference.fasta.gz
```

The files are for testing only. The folder layout:

```md
data
├── data_fasta
│   ├── contigs_1.fasta
│   ├── contigs_2.fasta
│   └── reference.fasta.gz
└── data_out
```

QUAST writes its report to `data_out`: `report.txt`, `report.tsv` and `report.html`, plus the Icarus contig browser (`icarus.html`). If you have the gene annotations of your reference genome in GFF format, add `-g <genes.gff>` for gene-based metrics; the test data has no gene file.

## Requirements

* **Input:** one or more assemblies (contigs or scaffolds) in FASTA format. Gzipped files are accepted.
* **Reference (optional):** a reference genome in FASTA format (`-r`) and its genes in GFF format (`-g`) give more metrics, such as misassemblies and genome fraction.
* **Database:** none.
* **Resources:** light for bacterial genomes. Use `--threads` to set the number of CPUs.

## Documentation

Full documentation, options, outputs and test data: [tools/quast on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/quast).

* [Running QUAST on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/quast#running-on-aws)
* [How to build the QUAST image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/quast#build-and-test)

## Licence

QUAST is distributed under the [GPL v2 licence](https://github.com/ablab/quast/blob/master/LICENSE.txt). The image only packages it.

If you use QUAST, please cite: Gurevich, A., Saveliev, V., Vyahhi, N., & Tesler, G. (2013). QUAST: quality assessment tool for genome assemblies. *Bioinformatics*, 29(8), 1072–1075. https://doi.org/10.1093/bioinformatics/btt086

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
