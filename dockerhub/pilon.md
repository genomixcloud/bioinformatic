# Pilon

<!-- short: Pilon 1.24 with bwa-mem2 2.2.1 and samtools 1.9: polishing of genome assemblies. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [Pilon](https://github.com/broadinstitute/pilon) 1.24, with bwa-mem2 and samtools, for polishing and improving genome assemblies with sequencing reads. Pilon reads the assembly in FASTA format and one or more BAM files of reads aligned to it; the image includes bwa-mem2 and samtools to make them. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | Pilon | Other tools in the image |
|-----|-------|--------------------------|
| `latest` | 1.24 | Ubuntu 22.04, bwa-mem2 2.2.1, samtools 1.9, Java (OpenJDK 8). `pilon` runs directly |
| `1.24` | 1.24 | Earlier build, from April 2024. Call Pilon as `bash pilon` in it |

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/pilon
docker run --rm genomixcloud/pilon pilon --help
docker run --rm genomixcloud/pilon bwa-mem2 version
docker run --rm genomixcloud/pilon samtools --help

# 2. Download test data: an assembly and trimmed paired-end reads (if you don't have your own)
mkdir -p data/data_fasta data/data_in_trimmed data/data_out && cd data
curl -o data_fasta/contigs.fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta
curl -o data_in_trimmed/trimmed_reads_1.fastq.gz https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_in_trimmed/trimmed_reads_1.fastq.gz
curl -o data_in_trimmed/trimmed_reads_2.fastq.gz https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_in_trimmed/trimmed_reads_2.fastq.gz
```

On Linux you can download the test data with `wget` instead:

```shell
wget -P data_fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta
wget -P data_in_trimmed https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_in_trimmed/trimmed_reads_1.fastq.gz
wget -P data_in_trimmed https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_in_trimmed/trimmed_reads_2.fastq.gz
```

The files are for testing only. Create the output folder first (the tools don't create it); the folder layout:

```md
data
├── data_fasta
│   └── contigs.fasta
├── data_out
└── data_in_trimmed
    ├── trimmed_reads_1.fastq.gz
    └── trimmed_reads_2.fastq.gz
```

Then run these steps in order, from the `data` folder:

```shell
# 1. Index the assembly (the index files are written next to contigs.fasta)
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon bwa-mem2 index /data/data_fasta/contigs.fasta

# 2. Align the reads to the assembly
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon bwa-mem2 mem -t 4 -P -S -Y -M \
  -o /data/data_out/sample.sam \
  /data/data_fasta/contigs.fasta \
  /data/data_in_trimmed/trimmed_reads_1.fastq.gz /data/data_in_trimmed/trimmed_reads_2.fastq.gz

# 3. Convert the alignment to BAM
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon samtools view -Sb /data/data_out/sample.sam -o /data/data_out/sample.bam -@ 8

# 4. Sort it
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon samtools sort /data/data_out/sample.bam -o /data/data_out/sample.sort.bam

# 5. Index it
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon samtools index /data/data_out/sample.sort.bam

# 6. Polish the assembly
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon pilon --genome /data/data_fasta/contigs.fasta \
  --bam /data/data_out/sample.sort.bam \
  --outdir /data/data_out/ --output assembly.polish --threads 8 --minqual 30 --nostrays
```

The polished assembly is `data_out/assembly.polish.fasta`. Add `--changes` to also get a file listing every change Pilon made.

On Docker for Apple silicon, `bwa-mem2` can stop with `Please verify that both the operating system and the processor support Intel(R) CLWB instructions`: its CPU check fails under emulation. It works on x86 machines and on AWS; locally, call `/usr/src/bwa/bwa-mem2.sse41` instead of `bwa-mem2`.

## Requirements

* **Input:** the assembly (contigs) in FASTA format, and paired-end reads in FASTQ format.
* **Database:** none: Pilon uses your own assembly as the reference.
* **Resources:** Pilon runs on Java and can use a lot of memory on large genomes, so give Docker enough memory. Set the CPUs of each step with `-t`, `--threads` or `-@`.

## Documentation

Full documentation, options and outputs: [tools/pilon on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/pilon).

* [Running Pilon on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/pilon#running-on-aws)
* [How to build the Pilon image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/pilon#build-and-test)

## Licence

Pilon is distributed under the [GPL v2 licence](https://github.com/broadinstitute/pilon/blob/master/LICENSE). bwa-mem2 and samtools have their own licences. The image only packages them.

If you use Pilon, please cite: Walker, B. J., et al. (2014). Pilon: an integrated tool for comprehensive microbial variant detection and genome assembly improvement. *PLoS ONE*, 9(11), e112963. https://doi.org/10.1371/journal.pone.0112963

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
