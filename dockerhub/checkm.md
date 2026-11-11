# CheckM

<!-- short: CheckM 1.2.5: completeness and contamination of genomes. Database included. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [CheckM](https://github.com/Ecogenomics/CheckM) 1.2.5 for assessing the quality (completeness, contamination and strain heterogeneity) of genomes recovered from isolates, single cells and metagenomes. The CheckM reference database is included in the image. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | CheckM | Other tools in the image |
|-----|--------|--------------------------|
| `latest` | 1.2.5 | Ubuntu 22.04, Python 3.10, pplacer v1.1.alpha19, HMMER 3.3.2, Prodigal 2.6.3, CheckM database release 2015-01-16 (in `/data/checkm_db`) |
| `v1.2.2` | 1.2.2 | Earlier build, from April 2024 |

## Quick start

```shell
# 1. Pull the image and run the test genome that comes with the database
docker pull genomixcloud/checkm
docker run --rm genomixcloud/checkm \
  checkm taxonomy_wf species "Escherichia coli" /data/checkm_db/test_data/ /tmp/checkm_test_results

# 2. Download test assemblies (if you don't have your own)
mkdir -p data/data_fasta && cd data
curl -o data_fasta/contigs.fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta
curl -o data_fasta/scaffolds.fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/scaffolds.fasta

# 3. Assess them: run from the data folder, and mount it on /data/work (not /data)
docker run --rm --mount src="$(pwd)",target=/data/work,type=bind \
  genomixcloud/checkm checkm taxonomy_wf life Prokaryote \
  /data/work/data_fasta -x fasta /data/work/data_out
```

On Linux you can download the test data with `wget` instead:

```shell
wget -P data_fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta
wget -P data_fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/scaffolds.fasta
```

The files are for testing only. The folder layout:

```md
data
└── data_fasta
    ├── contigs.fasta
    └── scaffolds.fasta
```

* **Mount your data on `/data/work`, not on `/data`:** the database is inside the image at `/data/checkm_db`, and a mount on `/data` hides it. You don't need to download the database.
* CheckM treats each FASTA file in the input folder as one genome; `-x` sets the file extension. It creates the output folder.
* The results table, with **Completeness**, **Contamination** and **Strain heterogeneity** for each genome, is printed on screen. Add `-f /data/work/data_out/results.tsv --tab_table` to save it to a file.

## Requirements

* **Input:** genomes or bins in FASTA format, one file per genome, all in one folder.
* **Database:** none to download: CheckM data release 2015-01-16 is in the image. To use another copy, mount it (for example on `/checkm_db`) and run `checkm data setRoot /checkm_db` before your CheckM command.
* **Resources:** `taxonomy_wf` needs little memory. The lineage-specific `tree` step runs pplacer, which needs about 40 GB of RAM, or about 14 GB with `--reduced_tree`.

## Documentation

Full documentation, the lineage-specific workflow, options and outputs: [tools/checkm on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/checkm).

* [Running CheckM on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/checkm#running-on-aws)
* [How to build the CheckM image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/checkm#build-and-test)

## Licence

CheckM is distributed under the [GPL v3 licence](https://github.com/Ecogenomics/CheckM/blob/master/LICENSE). The image only packages it.

If you use CheckM, please cite: Parks, D. H., Imelfort, M., Skennerton, C. T., Hugenholtz, P., & Tyson, G. W. (2015). CheckM: assessing the quality of microbial genomes recovered from isolates, single cells, and metagenomes. *Genome Research*, 25(7), 1043–1055. https://doi.org/10.1101/gr.186072.114

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
