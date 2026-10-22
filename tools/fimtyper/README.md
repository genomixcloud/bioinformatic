# FimTyper Docker image

A ready-to-run Linux (Ubuntu) Docker image of [FimTyper](https://bitbucket.org/genomicepidemiology/fimtyper/), with its database included, for the FimH typing of *Escherichia coli* genomes. This is an alpha version image (see [Note.md](Note.md)).

## Quick start

The FimTyper database and a test genome are already inside the image:

```shell
# 1. Pull the image and check the installation (prints the FimTyper options)
docker pull genomixcloud/fimtyper
docker run --name fimtyper --rm -ti genomixcloud/fimtyper \
perl /usr/local/fimtyper/fimtyper.pl -h

# 2. Run the test genome, writing the results to ./data_out
docker run --name fimtyper --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/fimtyper perl /usr/local/fimtyper/fimtyper.pl \
-d /usr/local/fimtyper/fimtyper_db \
-i /usr/local/fimtyper/test.fsa -o /data/data_out -k 95.00 -l 0.60
```

## Requirements

* **Docker**
* **Reference database:** included in the image at `/usr/local/fimtyper/fimtyper_db`.
* **Input format:** preassembled partial or complete genomes in FASTA format.
* **Resources:** light.

## Run locally

1. Change to the directory where you stored your data.
2. Run FimTyper, mounting the current directory on `/data`:

```shell
docker run --name fimtyper --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/fimtyper perl /usr/local/fimtyper/fimtyper.pl \
-d /usr/local/fimtyper/fimtyper_db \
-i /data/contigs.fasta -o /data/data_out -k 95.00 -l 0.60
```

| Option | Meaning |
|--------|---------|
| `-d` | Path to the database folder |
| `-i` | Input genome in FASTA format |
| `-o` | Output folder. Without it, FimTyper writes to a folder named `Output` inside the container, which is lost when the container stops |
| `-k` | Threshold for % identity, for example `95.00` for 95% |
| `-l` | Minimum length of the overlap, for example `0.60` for 60% |

ref: [FimTyper usage](https://bitbucket.org/genomicepidemiology/fimtyper/src/master/README.md#usage)

### Expected outputs

FimTyper writes its result files, with the FimH type found, to the output folder (`data_out`).

## Database setup

No setup is needed: the database is cloned from the [fimtyper_db repository](https://bitbucket.org/genomicepidemiology/fimtyper_db) when the image is built. To get a newer version, rebuild the image.

## Run on AWS

### Architecture

Input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs.

### Required services

AWS S3, AWS ECR and AWS Batch, plus AWS Networking and AWS IAM to connect them.

### Steps

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image. It also creates the `/src` and `/conf` folders, which this image doesn't have yet:

```shell
RUN wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
unzip -d /usr/src/  /usr/src/awscli-exe-linux-x86_64.zip && \
rm /usr/src/awscli-exe-linux-x86_64.zip && \
/usr/src/aws/install && \
mkdir /src && mkdir /conf
```

2. Create `/src/fimtyper.sh`. It must call `/usr/local/fimtyper/fimtyper.pl` with the **input** directory linked to AWS S3. You can place the S3 configuration and the FimTyper parameters in the `/conf` folder.
3. Test it locally with your AWS credentials:

```shell
docker run --name fimtyper --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/fimtyper /src/fimtyper.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the FimTyper image uploaded to AWS ECR.

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/fimtyper
docker build -t genomixcloud/fimtyper:my_version .
```

### Test

```shell
docker run --name fimtyper --rm -ti genomixcloud/fimtyper:my_version \
perl /usr/local/fimtyper/fimtyper.pl -h
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with Perl, BLAST+, FimTyper and its database |
| `src/tmp_brew.sh` | Installs cpanm and the FimTyper Perl dependencies when the image is built |
| `src/update_blast-ver.sh` | Installs a specific ncbi-blast+ version in `/usr/local/fimtyper/` (see [Note.md](Note.md)) |
| `conf/fimtyper.ini` | Configuration for the FimTyper parameters (not copied into the image yet) |
| `Note.md` | Notes on how the image was made and the improvements planned |

The scripts in `src/` are copied to `/usr/local/fimtyper` in the image, not to `/src`.

## References and licence

* [FimTyper main documentation](https://bitbucket.org/genomicepidemiology/fimtyper/)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* FimTyper is distributed under the [Apache License, Version 2.0](https://bitbucket.org/genomicepidemiology/fimtyper/src/master/README.md#license)
