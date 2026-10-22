# FastQC Docker image

A ready-to-run Linux (Ubuntu) Docker image of [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) 0.12.1, for the quality control of raw sequencing reads.

## Quick start

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/fastqc
docker run --name fastqc --rm -ti genomixcloud/fastqc fastqc --version

# 2. Download paired-end test reads
curl -o rawreads_1.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz
curl -o rawreads_2.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz

# 3. Check their quality
mkdir data_out
docker run --name fastqc --rm -ti --mount src="$(pwd)",target=/data,type=bind \
genomixcloud/fastqc fastqc rawreads_1.fastq.gz rawreads_2.fastq.gz -t 4 -o ./data_out
```

## Requirements

* **Docker**
* **Reference database:** none.
* **Input format:** reads in FASTQ format (gzipped files are accepted), or SAM/BAM files.
* **Resources:** light. Use `-t` to set the number of files processed at the same time.

## Run locally

1. Change to the directory where you downloaded the test data or where you stored your data.
2. Create the output directory (**data_out** in our example). FastQC doesn't create it.
3. Run FastQC:

```shell
docker run --name fastqc --rm -ti --mount src="$(pwd)",target=/data,type=bind \
genomixcloud/fastqc fastqc rawreads_1.fastq.gz rawreads_2.fastq.gz -t 4 -o ./data_out
```

Test data:

```shell
#wget
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz -O rawreads_1.fastq.gz
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz -O rawreads_2.fastq.gz
```

```shell
#curl osx
curl -o rawreads_1.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz
curl -o rawreads_2.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz
```

### Expected outputs

For each input file, FastQC writes to `data_out`:

| File | Content |
|------|---------|
| `<name>_fastqc.html` | Quality control report, to open in a browser |
| `<name>_fastqc.zip` | The report data, images and a text summary |

## Database setup

FastQC doesn't need a database.

## AWS deployment ideas

These are ideas for deploying FastQC on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

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

2. In `/src/fastqc.sh`, link the **in** and **out** directories to AWS S3. The links and the FastQC parameters can be configured in `conf/fastqc.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name fastqc --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/fastqc /src/fastqc.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the FastQC image uploaded to AWS ECR.

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/fastqc
docker build -t genomixcloud/fastqc:my_version .
```

### Test

```shell
docker run --name fastqc --rm -ti genomixcloud/fastqc:my_version fastqc --version
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with Java and FastQC |
| `src/fastqc.sh` | Template script, copied to `/src` in the image: calls `fastqc` with the variables set in `fastqc.ini` |
| `conf/fastqc.ini` | Configuration, copied to `/conf` in the image, such as the input reads and output folder |

## References and licence

* [FastQC Software](https://raw.githubusercontent.com/s-andrews/FastQC/master/INSTALL.txt)
* [FastQC main documentation](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
* [FastQC Manual](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* FastQC is distributed under its own licence: see the [FastQC repository](https://github.com/s-andrews/FastQC)
