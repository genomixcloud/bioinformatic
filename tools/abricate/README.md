# ABRicate Docker image

A ready-to-run Linux (Ubuntu) Docker image of [ABRicate](https://github.com/tseemann/abricate) 1.0.1, for the mass screening of contigs for antimicrobial resistance and virulence genes.

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/abricate
docker run --name abricate --rm -ti genomixcloud/abricate abricate --version
docker run --name abricate --rm -ti genomixcloud/abricate abricate --check

# 2. Download a small test genome
curl -o contig.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz
gunzip -k < contig.gz > contig.fasta

# 3. Screen it
docker run --name abricate --rm \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/abricate abricate contig.fasta > out.tab
```

## Requirements

* **Docker**
* **Reference database:** none to download. The ABRicate databases are set up inside the image when it's built (`abricate --setupdb`). To list them, run `abricate --list`.
* **Input format:** contigs in FASTA, GenBank or EMBL format (gzipped files are accepted).
* **Resources:** light. Use `--threads` to set the number of CPUs.

## Run locally

1. Change to the directory where you downloaded the test data or where you stored your data.
2. Create the output directory (**data_out** in our example).
3. Run ABRicate. It writes its results to standard output, so redirect them to a file:

```shell
docker run --name abricate --rm \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/abricate abricate contig.fasta > data_out/out.tab
```

Don't use `-t` (`-ti`) when you redirect the output to a file: it mixes the log messages into the results and adds Windows line endings.

To use a database other than the default (`ncbi`), add `--db <name>`, for example `--db vfdb`.

Test data:

```shell
#wget
wget https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz -O contig.gz
gunzip -k < contig.gz > contig.fasta
```

```shell
#curl osx
curl -o contig.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz
gunzip -k < contig.gz > contig.fasta
```

### Expected outputs

A tab-separated table with one line per gene found, with the columns `FILE`, `SEQUENCE`, `START`, `END`, `STRAND`, `GENE`, `COVERAGE`, `COVERAGE_MAP`, `GAPS`, `%COVERAGE`, `%IDENTITY`, `DATABASE`, `ACCESSION`, `PRODUCT` and `RESISTANCE`.

## Database setup

No setup is needed: the databases are downloaded and indexed when the image is built. To get newer versions of the databases, rebuild the image (see [Build and test the image](#build-and-test-the-image)).

## AWS deployment ideas

These are ideas for deploying ABRicate on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

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

2. In `/src/abricate.sh`, link the **in** and **out** directories to AWS S3. The links and the ABRicate parameters can be configured in `conf/abricate.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name abricate --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/abricate /src/abricate.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the ABRicate image uploaded to AWS ECR.

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/abricate
docker build -t genomixcloud/abricate:my_version .
```

### Test

```shell
docker run --name abricate --rm -ti genomixcloud/abricate:my_version abricate --check
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with ABRicate, BLAST+ and any2fasta |
| `src/abricate.sh` | Template script, copied to `/src` in the image: calls `abricate` with the variables set in `abricate.ini` |
| `conf/abricate.ini` | Configuration, copied to `/conf` in the image, such as the input file, database and output folder |

## References and licence

* [ABRicate Software](https://github.com/tseemann/abricate)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* ABRicate is distributed under its own licence: [ABRicate licence](https://github.com/tseemann/abricate/blob/master/LICENSE)
