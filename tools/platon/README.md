# Platon Docker image

A ready-to-run Linux (Ubuntu) Docker image of [Platon](https://github.com/oschwengers/platon) 1.7, for the identification and characterization of plasmid contigs in bacterial genome assemblies.

## Quick start

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/platon
docker run --name platon --rm -ti genomixcloud/platon platon --version

# 2. Download the Platon database into ./platon_db (see Database setup)

# 3. Classify the test contigs from the data folder of this repo
#    (run from the data folder, with platon_db inside it)
mkdir data_out
docker run --name platon --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/platon platon \
--mode sensitivity --threads 8 --db /data/platon_db \
/data/data_fasta/contigs.fasta -o /data/data_out
```

## Requirements

* **Docker**
* **Reference database (mandatory):** Platon can't run without its database (see [Database setup](#database-setup)).
* **Storage:** keep the database in external storage, or on AWS EFS when running on AWS, and mount it into the container.
* **Input format:** genome assemblies (contigs) in FASTA format.
* **Resources:** Platon needs a lot of memory. With 16GB of RAM it failed with **diamond execution failed! diamond-error-code=-11**; it ran successfully with **24GB** ([error reference](https://github.com/oschwengers/platon/issues/45#issuecomment-1983151977)). Use `--threads` to set the number of CPUs.

## Run locally

1. [Download the Platon database](#database-setup) to the **platon_db** directory.
2. Move to the `data` directory of this repo, which contains the FASTA files, and put `platon_db` inside it.
3. Create the output directory (**data_out** in our example).

```md
root_project
├── data
│   ├── data_fasta
│   │    └──contigs.fasta
│   ├── data_out
│   ├── platon_db
```

4. Run Platon:

```shell
docker run --name platon --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/platon platon \
--mode sensitivity --threads 8 --db /data/platon_db \
/data/data_fasta/contigs.fasta -o /data/data_out
```

`--mode` can be `sensitivity`, `accuracy` or `specificity`.

### Expected outputs

Platon writes its results to `data_out`, with the input file name as prefix:

| File | Content |
|------|---------|
| `.tsv` | Summary of the contigs classified as plasmids |
| `.plasmid.fasta` | Sequences of the plasmid contigs |
| `.chromosome.fasta` | Sequences of the chromosome contigs |
| `.json` | All results in machine-readable JSON |
| `.log` | Run log |

## Database setup

Download and extract the Platon database, then rename the extracted `db` folder to `platon_db`:

```shell
wget https://zenodo.org/record/4066768/files/db.tar.gz
tar -xzf db.tar.gz
rm db.tar.gz
mv db platon_db
```

ref: [Platon database download](https://github.com/oschwengers/platon?tab=readme-ov-file#database-download)

## Run on AWS

### Architecture

Input and output files live in **AWS S3**, the Platon database lives on **AWS EFS**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs.

### Required services

AWS S3, AWS ECR, AWS EFS and AWS Batch, plus AWS Networking and AWS IAM to connect them.

### Steps

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

```shell
RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
unzip -d /usr/src/  /usr/src/awscli-exe-linux-x86_64.zip && \
rm /usr/src/awscli-exe-linux-x86_64.zip && \
/usr/src/aws/install
```

2. Store the Platon database in a volume on AWS EFS. We recommend **AWS EFS for storing the Platon database in production**.
3. In `/src/platon.sh`, link the **in** and **out** directories to AWS S3 and the database path to the volume on AWS EFS. The links and the Platon parameters can be configured in `conf/platon.ini`.
4. Test it locally with your AWS credentials:

```shell
docker run --name platon --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/platon /src/platon.sh
```

5. Push the image to your AWS account (**AWS ECR**).
6. Create an AWS Batch job, linked to the volume on AWS EFS, that points to the Platon image uploaded to AWS ECR. Give it at least 24GB of memory (see [Requirements](#requirements)).

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/platon
docker build -t genomixcloud/platon:my_version .
```

### Test

```shell
docker run --name platon --rm -ti genomixcloud/platon:my_version platon --version
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with Miniconda and Platon (from bioconda) |
| `src/platon.sh` | Template script, copied to `/src` in the image: calls `platon` with the variables set in `platon.ini` |
| `conf/platon.ini` | Configuration, copied to `/conf` in the image, such as the input file, database and output folder |

## References and licence

* [Platon Documentation](https://github.com/oschwengers/platon)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* Platon is distributed under its own licence: see the [Platon repository](https://github.com/oschwengers/platon)
