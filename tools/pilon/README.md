# Pilon Docker image

A ready-to-run Linux (Ubuntu) Docker image of [Pilon](https://github.com/broadinstitute/pilon) 1.24, with bwa-mem2 2.2.1 and samtools 1.9, for polishing and improving genome assemblies with sequencing reads.

## Quick start

```shell
# 1. Pull the image and check the versions
docker pull genomixcloud/pilon
docker run --name pilon --rm -ti genomixcloud/pilon bash pilon --help
docker run --name bwa-mem2 --rm -ti genomixcloud/pilon bwa-mem2 version
docker run --name samtools --rm -ti genomixcloud/pilon samtools --help
```

Pilon needs the reads aligned to the assembly first, so the example with the test data in this repo runs in 6 steps: see [Run locally](#run-locally).

## Requirements

* **Docker**
* **Reference database:** none. Pilon uses your own assembly as the reference.
* **Input format:** the assembly (contigs) in FASTA format, and paired-end reads in FASTQ format. Pilon itself reads one or more BAM files of reads aligned to the assembly: the image includes bwa-mem2 and samtools to make them.
* **Resources:** Pilon runs on Java and can use a lot of memory on large genomes, so give Docker enough memory. Use `-t`, `--threads` or `-@` to set the number of CPUs of each step.

## Run locally

1. Move to the `data` directory of this repo, which contains the trimmed sample reads and the FASTA file.
2. Create the output directory (**data_out** in our example). The tools don't create it.

```md
root_project
├── data
│   ├── data_fasta
│   │    └── contigs.fasta
│   ├── data_out
│   ├── data_in_trimmed
│       ├── trimmed_reads_1.fastq.gz
│       ├── trimmed_reads_2.fastq.gz
```

3. Run the commands below in order:

1: Index the assembly (the index files are written next to `contigs.fasta`):
```shell
docker run --name bwa-mem2-index --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/pilon bwa-mem2 index /data/data_fasta/contigs.fasta
```

2: Align the reads to the assembly:
```shell
docker run --name bwa-mem2 --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/pilon bwa-mem2 mem -t 4 -P -S -Y -M \
-o /data/data_out/sample.sam \
/data/data_fasta/contigs.fasta \
/data/data_in_trimmed/trimmed_reads_1.fastq.gz /data/data_in_trimmed/trimmed_reads_2.fastq.gz
```

3: Convert the alignment to BAM:
```shell
docker run --name samtools-view --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/pilon samtools view -Sb /data/data_out/sample.sam \
-o /data/data_out/sample.bam -@ 8
```

4: Sort it:
```shell
docker run --name samtools-sort --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/pilon samtools sort /data/data_out/sample.bam \
-o /data/data_out/sample.sort.bam
```

5: Index it:
```shell
docker run --name samtools-index --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/pilon samtools index /data/data_out/sample.sort.bam
```

6: Polish the assembly:
```shell
docker run --name pilon --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/pilon bash pilon --genome /data/data_fasta/contigs.fasta \
--bam /data/data_out/sample.sort.bam \
--outdir /data/data_out/ --output assembly.polish --threads 8 --minqual 30 --nostrays
```

Call Pilon as `bash pilon` (as above): the `pilon` launcher in the image has no `#!/bin/bash` line, so Docker can't run it directly.

### Expected outputs

| File | Content |
|------|---------|
| `data_out/sample.sam`, `sample.bam`, `sample.sort.bam`, `sample.sort.bam.bai` | The read alignment, from steps 2 to 5 |
| `data_out/assembly.polish.fasta` | The polished assembly |

To also get a file listing every change Pilon made, add `--changes`.

## Database setup

Pilon doesn't need a database.

## AWS deployment ideas

These are ideas for deploying Pilon on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

### Architecture

Input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs.

### Required services

AWS S3, AWS ECR and AWS Batch, plus AWS Networking and AWS IAM to connect them.

### Steps

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

```shell
RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
unzip -d /usr/src/  /usr/src/awscli-exe-linux-x86_64.zip && \
rm /usr/src/awscli-exe-linux-x86_64.zip && \
/usr/src/aws/install
```

2. In `/src/pilon.sh`, link the **in** and **out** directories to AWS S3. The script already runs bwa-mem2, samtools and Pilon in the order above. The links and the parameters can be configured in `conf/pilon.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name pilon --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/pilon /src/pilon.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the Pilon image uploaded to AWS ECR.

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/pilon
docker build -t genomixcloud/pilon:my_version .
```

### Test

```shell
docker run --name pilon --rm -ti genomixcloud/pilon:my_version bash pilon --help
docker run --name bwa-mem2 --rm -ti genomixcloud/pilon:my_version bwa-mem2 version
docker run --name samtools --rm -ti genomixcloud/pilon:my_version samtools --help
```

Then run the steps in [Run locally](#run-locally) with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with Java 8, Pilon, bwa-mem2 and samtools (built from source) |
| `src/pilon.sh` | Template script, copied to `/src` in the image: runs bwa-mem2, samtools and Pilon with the variables set in `pilon.ini` |
| `conf/pilon.ini` | Configuration, copied to `/conf` in the image, such as the assembly, reads and output folder |

## References and licence

* [Pilon Software](https://github.com/broadinstitute/pilon)
* [Pilon Manual](https://github.com/broadinstitute/pilon/wiki)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* Pilon is distributed under its own licence: [Pilon licence](https://github.com/broadinstitute/pilon/blob/master/LICENSE)
