# Prokka Docker image

A ready-to-run Linux (Ubuntu) Docker image of [Prokka](https://github.com/tseemann/prokka) 1.14.6, for the rapid annotation of prokaryotic genomes.

## Quick start

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/prokka
docker run --name prokka --rm genomixcloud/prokka prokka --version

# 2. Annotate the test contigs from the data folder of this repo
cd data
docker run --name prokka --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/prokka prokka data_fasta/contigs.fasta --outdir data_out/prokka --cpu 4 --force
```

## Requirements

* **Docker**
* **Reference database:** none to download. The Prokka databases are set up inside the image when it's built (`prokka --setupdb`). To list them, run `prokka --listdb`.
* **Input format:** genome assemblies (contigs) in FASTA format.
* **Resources:** use `--cpu` to set the number of CPUs.

## Run locally

1. Move to the `data` directory of this repo, which contains the FASTA files (see the tree below).

```md
root_project
├── data
│   ├── data_fasta
│   │    └──  contigs.fasta
```

2. Run Prokka:

```shell
docker run --name prokka --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/prokka prokka data_fasta/contigs.fasta --outdir data_out/prokka --cpu 4 --force
```

Prokka creates the `--outdir` folder. `--force` lets it write into the folder if it already exists. Without `--outdir`, Prokka writes to a new `PROKKA_<date>` folder.

### Expected outputs

Prokka writes its results to `data_out/prokka`, with the prefix `PROKKA_<date>` (set your own with `--prefix`):

| File | Content |
|------|---------|
| `.gff` | Annotations and sequences in GFF3 format |
| `.gbk` | Annotations and sequences in GenBank format |
| `.fna` | Contig nucleotide sequences |
| `.faa` | Protein sequences of the CDS |
| `.ffn` | Nucleotide sequences of all the features |
| `.sqn`, `.fsa`, `.tbl` | Files to submit the annotation to GenBank |
| `.tsv` | Table of all the features |
| `.txt` | Summary of the annotation |
| `.err`, `.log` | Error and run logs |

## Database setup

No setup is needed: the databases are indexed when the image is built.

If you face any problem with tbl2asn (you shouldn't), you can find the appropriate tbl2asn release in the [binaries folder](../../binaries/README_tbl2asn.md).

## AWS deployment ideas

These are ideas for deploying Prokka on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

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

2. In `/src/prokka.sh`, link the **in** and **out** directories to AWS S3. The links and the Prokka parameters can be configured in `conf/prokka.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name prokka --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/prokka /src/prokka.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the Prokka image uploaded to AWS ECR.

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/prokka
docker build --platform=linux/amd64 --build-arg DEBIAN_FRONTEND=noninteractive -t genomixcloud/prokka:my_version .
```

`DEBIAN_FRONTEND=noninteractive` stops the build from asking for a timezone.

### Test

```shell
docker run --name prokka --rm genomixcloud/prokka:my_version prokka --version
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with Prokka, BLAST+ 2.9.0, barrnap, bedtools and tbl2asn |
| `src/prokka.sh` | Script, copied to `/src` in the image: calls `prokka` with the given arguments |
| `conf/prokka.ini` | Configuration, copied to `/conf` in the image, such as the S3 input and output folders |

## References and licence

* [Prokka Software](https://github.com/tseemann/prokka)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* Prokka is distributed under its own licence: [Prokka licence](https://github.com/tseemann/prokka/blob/master/LICENSE)
