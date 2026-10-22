# SPAdes Docker image

A ready-to-run Linux (Ubuntu) Docker image of [SPAdes](https://github.com/ablab/spades) 3.15.5, for the de novo assembly of genomes from sequencing reads.

## Quick start

```shell
# 1. Pull the image and run the SPAdes self-test on its built-in toy data
docker pull genomixcloud/spades
docker run --name spades-test --rm -ti genomixcloud/spades spades.py --isolate --test

# 2. Assemble the trimmed test reads from the data folder of this repo
cd data/data_in_trimmed
docker run --name spades --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/spades spades.py --careful \
-1 trimmed_reads_1.fastq.gz -2 trimmed_reads_2.fastq.gz \
-o ./data_out
```

## Requirements

* **Docker**
* **Reference database:** none.
* **Input format:** single-end or paired-end reads in FASTQ format (gzipped files are accepted). Trim them first, for example with [fastp](../fastp).
* **Resources:** assembly is memory and CPU intensive. Give Docker enough memory, use `-t` to set the number of CPUs and `-m` to set the memory limit in GB (250GB by default).

## Run locally

1. Move to the `data/data_in_trimmed` directory of this repo, which contains the trimmed reads.
2. Run SPAdes:

```shell
docker run --name spades --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/spades spades.py --careful \
-1 trimmed_reads_1.fastq.gz \
-2 trimmed_reads_2.fastq.gz \
-o ./data_out
```

SPAdes creates the output directory (**data_out** in our example).

### Expected outputs

SPAdes writes its results to `data_out`:

| File | Content |
|------|---------|
| `contigs.fasta` | The assembled contigs |
| `scaffolds.fasta` | The assembled scaffolds |
| `assembly_graph.fastg` / `assembly_graph_with_scaffolds.gfa` | The assembly graph |
| `params.txt` | Parameters used for the run |
| `spades.log` | Run log |

## Database setup

SPAdes doesn't need a database.

## Run on AWS

### Architecture

Input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the assembly jobs.

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

2. In `/src/spades.sh`, link the **in** and **out** directories to AWS S3. The links and the SPAdes parameters can be configured in `conf/spades.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name spades --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/spades /src/spades.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the SPAdes image uploaded to AWS ECR. Give it enough memory for the assembly (see [Requirements](#requirements)).

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/spades
docker build -t genomixcloud/spades:my_version .
```

The SPAdes release used by the Dockerfile is also stored in the [binaries folder](../../binaries) of this repo.

### Test

```shell
docker run --name spades-test --rm -ti genomixcloud/spades:my_version spades.py --isolate --test
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with Python and the prebuilt SPAdes binaries |
| `src/spades.sh` | Template script, copied to `/src` in the image: calls `spades.py` with the variables set in `spades.ini` |
| `conf/spades.ini` | Configuration, copied to `/conf` in the image, such as the input reads and output folder |

## References and licence

* [SPAdes Software](https://cab.spbu.ru/software/spades/)
* [SPAdes Manual](https://cab.spbu.ru/files/release3.15.4/manual.html#sec2.4)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* SPAdes is distributed under its own licence: see the [SPAdes repository](https://github.com/ablab/spades)
