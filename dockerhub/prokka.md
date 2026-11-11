# Prokka

<!-- short: Prokka 1.14.6: rapid annotation of prokaryotic genomes. Databases included. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [Prokka](https://github.com/tseemann/prokka) 1.14.6 for the rapid annotation of prokaryotic genomes. The Prokka databases are included in the image, and its GFF3 output is ready for pan-genome analysis with [genomixcloud/roary](https://hub.docker.com/r/genomixcloud/roary). It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | Prokka | Other tools in the image |
|-----|--------|--------------------------|
| `latest` | 1.14.6 | Ubuntu 22.04, BLAST+ 2.9.0, barrnap 0.9, bedtools 2.29.0, Prodigal 2.6.3, ARAGORN 1.2.38, HMMER 3.3.2, tbl2asn 25.6, Perl 5.34 |
| `1.14.6` | 1.14.6 | Earlier build, from July 2024 |

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/prokka
docker run --rm genomixcloud/prokka prokka --version

# 2. Download test contigs (if you don't have your own)
mkdir -p data/data_fasta && cd data
curl -o data_fasta/contigs.fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta

# 3. Annotate them: run from the data folder
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/prokka prokka data_fasta/contigs.fasta --outdir data_out/prokka --cpu 4 --force
```

On Linux you can download the test contigs with `wget` instead:

```shell
wget -P data_fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta
```

The file is for testing only. The folder layout:

```md
data
└── data_fasta
    └── contigs.fasta
```

* Prokka creates the `--outdir` folder; `--force` lets it write into the folder if it already exists. Without `--outdir`, Prokka writes to a new `PROKKA_<date>` folder.
* The results have the prefix `PROKKA_<date>` (set your own with `--prefix`): `.gff` (annotation and sequences, the input of Roary), `.gbk`, `.faa`, `.ffn`, `.fna`, `.tsv`, `.txt` and the GenBank submission files `.sqn`, `.fsa`, `.tbl`.
* `tbl2asn` 25.6 refuses to run once it's more than a year old, so the image runs it with a fixed date (2019-01-01). The GenBank files carry that date.

## Requirements

* **Input:** genome assemblies (contigs) in FASTA format.
* **Database:** none to download: the Prokka databases are inside the image (`prokka --listdb` lists them).
* **Resources:** set the CPUs with `--cpu`.

## Documentation

Full documentation, options and outputs: [tools/prokka on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/prokka).

* [Running Prokka on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/prokka#running-on-aws)
* [How to build the Prokka image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/prokka#build-and-test)

## Licence

Prokka is distributed under the [GPL v3 licence](https://github.com/tseemann/prokka/blob/master/LICENSE). The tools it bundles have their own licences. The image only packages them.

If you use Prokka, please cite: Seemann, T. (2014). Prokka: rapid prokaryotic genome annotation. *Bioinformatics*, 30(14), 2068–2069. https://doi.org/10.1093/bioinformatics/btu153

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
