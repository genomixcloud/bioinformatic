# fastp Docker image

A ready-to-run Linux (Ubuntu) Docker image of [fastp](https://github.com/OpenGene/fastp) 1.0.1, for fast all-in-one quality control, trimming and filtering of sequencing reads.

## Quick start

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/fastp
docker run --name fastp --rm -ti genomixcloud/fastp fastp --version

# 2. Download paired-end test reads
curl -o rawreads_1.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_1.fastq.gz
curl -o rawreads_2.fastq.gz ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR333/004/ERR3335404/ERR3335404_2.fastq.gz

# 3. Trim them
mkdir data_out
docker run --name fastp --rm -ti --mount src="$(pwd)",target=/data,type=bind \
genomixcloud/fastp fastp \
-i rawreads_1.fastq.gz -I rawreads_2.fastq.gz \
-o data_out/out_rawreads_1.fastq.gz -O data_out/out_rawreads_2.fastq.gz
```

## Requirements

* **Docker**
* **Reference database:** none.
* **Input format:** single-end or paired-end reads in FASTQ format (gzipped files are accepted).
* **Resources:** light. Use `-w` to set the number of worker threads.

## Run locally

1. Change to the directory where you downloaded the test data or where you stored your data.
2. Create the output directory (**data_out** in our example). fastp doesn't create it.
3. Run fastp:

```shell
docker run --name fastp --rm -ti --mount src="$(pwd)",target=/data,type=bind \
genomixcloud/fastp fastp \
-i rawreads_1.fastq.gz \
-I rawreads_2.fastq.gz \
-o data_out/out_rawreads_1.fastq.gz \
-O data_out/out_rawreads_2.fastq.gz
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

| File | Content |
|------|---------|
| `data_out/out_rawreads_1.fastq.gz` / `data_out/out_rawreads_2.fastq.gz` | Trimmed and filtered reads |
| `fastp.html` | Quality control report (before and after filtering), in the current directory |
| `fastp.json` | The same report in JSON format, in the current directory |

To choose where the reports go, add `-h data_out/fastp.html -j data_out/fastp.json`.

## Database setup

fastp doesn't need a database.

## AWS deployment ideas

These are ideas for deploying fastp on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

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

2. In `/src/fastp.sh`, link the **in** and **out** directories to AWS S3. The links and the fastp parameters can be configured in `conf/fastp.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name fastp --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/fastp /src/fastp.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the fastp image uploaded to AWS ECR.

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/fastp
docker build --platform=linux/amd64 -t genomixcloud/fastp:my_version .
```

### Test

```shell
docker run --name fastp --rm -ti genomixcloud/fastp:my_version fastp --version
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with the prebuilt fastp binary |
| `src/fastp.sh` | Template script, copied to `/src` in the image: calls `fastp` with the variables set in `fastp.ini` |
| `conf/fastp.ini` | Configuration, copied to `/conf` in the image, such as the input reads and output folder |

## References and licence

* [fastp Software](https://github.com/OpenGene/fastp)
* [fastp installer](https://github.com/OpenGene/fastp#or-download-the-latest-prebuilt-binary-for-linux-users)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* fastp is distributed under its own licence: [fastp licence](https://github.com/OpenGene/fastp/blob/master/LICENSE)
