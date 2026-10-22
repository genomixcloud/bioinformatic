# mlst Docker image

A ready-to-run Linux (Ubuntu) Docker image of [mlst](https://github.com/tseemann/mlst) 2.23.0, for the multi-locus sequence typing (MLST) of genome assemblies against the PubMLST schemes.

## Quick start

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/mlst
docker run --name mlst --rm -ti genomixcloud/mlst mlst --version

# 2. Type the example genome from the data folder of this repo
cd data
docker run --name mlst --rm \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/mlst mlst --csv /data/data_fna/example.fna.gz > mlst.csv
```

## Requirements

* **Docker**
* **Reference database:** none to download. The PubMLST schemes come with mlst and are inside the image. To list them, run `mlst --list`.
* **Input format:** genome assemblies in FASTA, GenBank or EMBL format (gzipped files are accepted).
* **Resources:** light. Use `--threads` to set the number of CPUs.

## Run locally

1. Move to the `data` directory of this repo, which contains the FASTA files (see the tree below).

```md
root_project
├── data
│   ├── data_fasta
│   │    └──  contigs.fasta
│   ├── data_fna
│   │    └──  example.fna.gz
```

2. Run mlst. It writes its results to standard output, so redirect them to a file:

```shell
docker run --name mlst --rm \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/mlst mlst --csv --nopath --quiet --threads 2 \
/data/data_fasta/contigs.fasta > mlst.csv
```

Don't use `-t` (`-ti`) when you redirect the output to a file: it mixes the log messages into the results and adds Windows line endings.

### Expected outputs

`mlst.csv`, with one line per genome: the file name, the MLST scheme found, the sequence type (ST) and the allele number of each locus.

## Database setup

No setup is needed: the PubMLST schemes and BLAST database come with the mlst release installed in the image. To get newer schemes, rebuild the image with a newer mlst version (`MlstVer` in the Dockerfile).

## AWS deployment ideas

These are ideas for deploying mlst on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

### Architecture

Input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs.

### Required services

AWS S3, AWS ECR and AWS Batch, plus AWS Networking and AWS IAM to connect them.

### Steps

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

```shell
RUN wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
unzip -d /usr/src/  /usr/src/awscli-exe-linux-x86_64.zip && \
rm /usr/src/awscli-exe-linux-x86_64.zip && \
/usr/src/aws/install
```

2. In `/src/mlst.sh`, link the **in** and **out** directories to AWS S3. The links and the mlst parameters can be configured in `conf/mlst.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name mlst --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/mlst /src/mlst.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the mlst image uploaded to AWS ECR.

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/mlst
docker build -t genomixcloud/mlst:my_version .
```

### Test

```shell
docker run --name mlst --rm -ti genomixcloud/mlst:my_version mlst --version
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with mlst, BLAST+ (2.9.0, the minimum mlst needs) and any2fasta |
| `src/mlst.sh` | Template script, copied to `/src` in the image: calls `mlst` with the variables set in `mlst.ini` |
| `conf/mlst.ini` | Configuration, copied to `/conf` in the image, such as the input file and output folder |

## References and licence

* [mlst Software](https://github.com/tseemann/mlst)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* mlst is distributed under its own licence: [mlst licence](https://github.com/tseemann/mlst/blob/master/LICENSE)
