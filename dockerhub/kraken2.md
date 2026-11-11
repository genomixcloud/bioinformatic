# Kraken2

<!-- short: Kraken2 2.1.6: taxonomic classification of sequencing reads. Database not included. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [Kraken2](https://github.com/DerrickWood/kraken2) 2.1.6 for the taxonomic classification of sequencing reads, to check the species and contamination of a sample. It includes `kraken2-build` to build your own database. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | Kraken2 | Other tools in the image |
|-----|---------|--------------------------|
| `latest` | 2.1.6 | Ubuntu 22.04, BLAST+ 2.12.0 (used by `kraken2-build`), rsync, Python 3 |
| `2.1.3` | 2.1.3 | Earlier build, from April 2024 |

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/kraken2
docker run --rm genomixcloud/kraken2 kraken2 --version
docker run --rm genomixcloud/kraken2 blastn -version
docker run --rm genomixcloud/kraken2 kraken2-build --help

# 2. Download the MiniKraken2 test database (8 GB) and trimmed test reads
mkdir -p data/kraken_db data/data_in_trimmed data/data_out/taxonomic_identification && cd data
curl -o minikraken2_v2_8GB_201904.tgz https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v2_8GB_201904.tgz
tar -xzf minikraken2_v2_8GB_201904.tgz -C kraken_db   # move the .k2d files up to kraken_db if they end up in a subfolder
curl -o data_in_trimmed/trimmed_reads_1.fastq.gz https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_in_trimmed/trimmed_reads_1.fastq.gz
curl -o data_in_trimmed/trimmed_reads_2.fastq.gz https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_in_trimmed/trimmed_reads_2.fastq.gz

# 3. Classify the reads: run from the data folder
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/kraken2 kraken2 --paired \
  /data/data_in_trimmed/trimmed_reads_1.fastq.gz /data/data_in_trimmed/trimmed_reads_2.fastq.gz \
  --db /data/kraken_db --threads 8 --memory-mapping \
  --output /data/data_out/taxonomic_identification/kraken-output.txt \
  --report /data/data_out/taxonomic_identification/kraken-report.txt
```

On Linux you can download the test data with `wget` instead:

```shell
wget https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v2_8GB_201904.tgz
wget -P data_in_trimmed https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_in_trimmed/trimmed_reads_1.fastq.gz
wget -P data_in_trimmed https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_in_trimmed/trimmed_reads_2.fastq.gz
```

The files are for testing only. The folder layout:

```md
data
├── kraken_db
├── data_out
│   └── taxonomic_identification
└── data_in_trimmed
    ├── trimmed_reads_1.fastq.gz
    └── trimmed_reads_2.fastq.gz
```

* **Create the output folder first:** Kraken2 doesn't create it.
* **`--memory-mapping`** reads the database from disk instead of loading it into memory. Use it on a computer with less memory than the database; don't use it in production.
* **`--output`** saves one line per read. Without it, Kraken2 prints every read on the screen.
* **`kraken-report.txt`** is the summary per taxon: percentage of reads, reads in the clade and assigned directly, rank, NCBI taxonomy ID and name.

## Requirements

* **Input:** single-end or paired-end reads in FASTQ or FASTA format. Gzipped files are accepted.
* **Database (mandatory, not included):** use a prebuilt database instead of building one. They're published at [benlangmead.github.io/aws-indexes/k2](https://benlangmead.github.io/aws-indexes/k2), section **Kraken2 + Bracken**, table **Latest: <month> <year> update**: Standard for real analyses, Standard-8 or Standard-16 (capped at 8 or 16 GB) for testing or less memory. They're updated about every 3 to 4 months, with the release date in the file name, so copy the current URL from that page. Keep the database in external storage, or on AWS EFS, and mount it into the container.
* **Resources:** Kraken2 loads the whole database into memory, so give the container at least the database size, or use `--memory-mapping`. Set the CPUs with `--threads`.

## Documentation

Full documentation, database setup, options, outputs and benchmarks: [tools/kraken2 on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/kraken2).

* [Running Kraken2 on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/kraken2#running-on-aws)
* [How to build the Kraken2 image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/kraken2#build-and-test)

## Licence

Kraken2 is distributed under the [MIT licence](https://github.com/DerrickWood/kraken2/blob/master/LICENSE). The databases have their own terms of use. The image only packages Kraken2.

If you use Kraken2, please cite: Wood, D. E., Lu, J., & Langmead, B. (2019). Improved metagenomic analysis with Kraken 2. *Genome Biology*, 20(1), 257. https://doi.org/10.1186/s13059-019-1891-0

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
