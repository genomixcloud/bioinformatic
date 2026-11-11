# fastp

<!-- short: fastp 1.0.1: quality control, adapter trimming and filtering of sequencing reads. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [fastp](https://github.com/OpenGene/fastp) 1.0.1 for fast all-in-one quality control, adapter trimming and filtering of sequencing reads. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | fastp | Other tools in the image |
|-----|-------|--------------------------|
| `latest` | 1.0.1 | Ubuntu 22.04. The fastp binary is the prebuilt release from opengene.org, checked with its SHA-256 |

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/fastp
docker run --rm genomixcloud/fastp fastp --version

# 2. Download paired-end test reads (if you don't have your own)
curl -o rawreads_1.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz
curl -o rawreads_2.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz

# 3. Trim them: run from the folder with the reads, and create the output folder first
mkdir data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/fastp fastp \
  -i rawreads_1.fastq.gz -I rawreads_2.fastq.gz \
  -o data_out/out_rawreads_1.fastq.gz -O data_out/out_rawreads_2.fastq.gz \
  -h data_out/fastp.html -j data_out/fastp.json
```

On Linux you can download the test reads with `wget` instead:

```shell
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz -O rawreads_1.fastq.gz
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz -O rawreads_2.fastq.gz
```

fastp doesn't create the output folder. Without `-h` and `-j`, the HTML and JSON reports are written to the current folder.

## Requirements

* **Input:** single-end or paired-end reads in FASTQ format. Gzipped files are accepted.
* **Database:** none.
* **Resources:** light. Use `-w` to set the number of worker threads.

## Documentation

Full documentation, options, outputs and test data: [tools/fastp on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/fastp).

* [Running fastp on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/fastp#running-on-aws)
* [How to build the fastp image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/fastp#build-and-test)

## Licence

fastp is distributed under the [MIT licence](https://github.com/OpenGene/fastp/blob/master/LICENSE). The image only packages it.

If you use fastp, please cite: Chen, S., Zhou, Y., Chen, Y., & Gu, J. (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. *Bioinformatics*, 34(17), i884–i890. https://doi.org/10.1093/bioinformatics/bty560

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
