# FastQC

<!-- short: FastQC 0.12.1: quality control of raw sequencing reads (FASTQ, SAM, BAM). -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) 0.12.1 for the quality control of raw sequencing reads. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | FastQC | Other tools in the image |
|-----|--------|--------------------------|
| `latest` | 0.12.1 | Ubuntu 22.04, Java (OpenJDK 11, headless) |

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/fastqc
docker run --rm genomixcloud/fastqc fastqc --version

# 2. Download paired-end test reads (if you don't have your own)
curl -o rawreads_1.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz
curl -o rawreads_2.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz

# 3. Check their quality: run from the folder with the reads, and create the output folder first
mkdir data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/fastqc fastqc rawreads_1.fastq.gz rawreads_2.fastq.gz -t 4 -o ./data_out
```

On Linux you can download the test reads with `wget` instead:

```shell
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz -O rawreads_1.fastq.gz
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz -O rawreads_2.fastq.gz
```

FastQC doesn't create the output folder. For each input file it writes `<name>_fastqc.html`, the report to open in a browser, and `<name>_fastqc.zip`, with the report data.

## Requirements

* **Input:** reads in FASTQ format (gzipped files are accepted), or SAM/BAM files.
* **Database:** none.
* **Resources:** light. Use `-t` to set the number of files processed at the same time; each one uses about 250 MB of memory.

## Documentation

Full documentation, options, outputs and test data: [tools/fastqc on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/fastqc).

* [Running FastQC on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/fastqc#running-on-aws)
* [How to build the FastQC image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/fastqc#build-and-test)

## Licence

FastQC is distributed under the [GPL v3 licence](https://github.com/s-andrews/FastQC/blob/master/LICENSE). The image only packages it.

If you use FastQC, please cite: Andrews, S. (2010). FastQC: a quality control tool for high throughput sequence data. https://www.bioinformatics.babraham.ac.uk/projects/fastqc/

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
