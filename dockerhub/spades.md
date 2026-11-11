# SPAdes

<!-- short: SPAdes 3.15.5: de novo genome assembly from sequencing reads. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [SPAdes](https://github.com/ablab/spades) 3.15.5 for the de novo assembly of genomes from sequencing reads. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | SPAdes | Other tools in the image |
|-----|--------|--------------------------|
| `latest` | 3.15.5 | Ubuntu 20.04, Python 3.8. SPAdes is the prebuilt Linux release |

## Quick start

```shell
# 1. Pull the image and run the SPAdes self-test on its built-in toy data
docker pull genomixcloud/spades
docker run --rm genomixcloud/spades spades.py --isolate --test

# 2. Download paired-end test reads (if you don't have your own)
curl -o forwardPairedReads_1.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz
curl -o reversePairedReads_2.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz

# 3. Assemble them: run from the folder with the reads
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/spades spades.py --careful \
  -1 forwardPairedReads_1.fastq.gz -2 reversePairedReads_2.fastq.gz \
  -o data_out
```

On Linux you can download the test reads with `wget` instead:

```shell
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz -O forwardPairedReads_1.fastq.gz
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz -O reversePairedReads_2.fastq.gz
```

The example adds `--careful`, but you can add any other SPAdes option you need (for example `--isolate` for high-coverage isolates; it can't be combined with `--careful`). SPAdes creates the output folder and writes the assembly to `data_out/contigs.fasta` and `data_out/scaffolds.fasta`. These raw test reads are untrimmed: for real data, trim the reads first, for example with [genomixcloud/fastp](https://hub.docker.com/r/genomixcloud/fastp).

## Requirements

* **Input:** single-end or paired-end reads in FASTQ format. Gzipped files are accepted.
* **Database:** none.
* **Resources:** assembly is memory and CPU intensive. Give Docker enough memory, set the CPUs with `-t` and the memory limit in GB with `-m` (250 GB by default).

## Documentation

Full documentation, options, outputs and test data: [tools/spades on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/spades).

* [Running SPAdes on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/spades#running-on-aws)
* [How to build the SPAdes image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/spades#build-and-test)

## Licence

SPAdes is distributed under the [GPL v2 licence](https://github.com/ablab/spades/blob/main/LICENSE). The image only packages it.

If you use SPAdes, please cite: Bankevich, A., et al. (2012). SPAdes: a new genome assembly algorithm and its applications to single-cell sequencing. *Journal of Computational Biology*, 19(5), 455–477. https://doi.org/10.1089/cmb.2012.0021

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
