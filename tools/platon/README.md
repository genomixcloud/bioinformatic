# Platon Docker image

A ready-to-run Linux Docker image of [Platon](https://github.com/oschwengers/platon), for the identification and characterization of plasmid contigs in bacterial genome assemblies.

| | |
|---|---|
| **Image** | [`genomixcloud/platon`](https://hub.docker.com/r/genomixcloud/platon) |
| **Tool version** | Platon 1.7 |
| **Platform** | `linux/amd64` |
| **Database** | Required (downloaded from Zenodo) |
| **Input → output** | Assembly (FASTA) → plasmid and chromosome contigs (FASTA), summary (TSV, JSON) |
| **Pipeline step** | After assembly ([SPAdes](../spades), [Pilon](../pilon)) |

## Contents

* [Quick start](#quick-start)
* [Image contents](#image-contents)
* [Requirements](#requirements)
* [Usage](#usage)
* [Outputs](#outputs)
* [Database setup](#database-setup)
* [Running on AWS](#running-on-aws)
* [Build and test](#build-and-test)
* [Troubleshooting](#troubleshooting)
* [Citation](#citation)
* [Licence and references](#licence-and-references)

## Quick start

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/platon
docker run --rm genomixcloud/platon platon --version

# 2. Download the Platon database into ./platon_db (see Database setup)

# 3. Classify the test contigs from the data folder of this repo
#    (run from the data folder, with platon_db inside it)
mkdir data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/platon platon \
  --mode sensitivity --threads 8 --db /data/platon_db \
  /data/data_fasta/contigs.fasta -o /data/data_out
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 20.04 | |
| Platon | 1.7 | From bioconda, installed in the conda **base** environment |
| Dependencies (DIAMOND, BLAST+, HMMER, MUMmer, INFERNAL, Prodigal) | resolved by conda at build time | Not pinned |
| Miniconda | latest at build time | Not pinned |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** genome assemblies (contigs) in FASTA format.
* **Database (mandatory):** Platon can't run without its database (see [Database setup](#database-setup)).
* **Storage:** keep the database in external storage, or on AWS EFS when running on AWS, and mount it into the container.
* **Resources:** Platon needs a lot of memory. With 16 GB of RAM it failed with `diamond execution failed! diamond-error-code=-11`; it ran with **24 GB** ([error reference](https://github.com/oschwengers/platon/issues/45#issuecomment-1983151977)). Use `--threads` to set the number of CPUs.

## Usage

1. [Download the Platon database](#database-setup) to a **platon_db** folder.
2. Move to the `data` folder of this repo, which contains the FASTA files, and put `platon_db` inside it.
3. Create the output folder (`data_out` in this example).

```md
data
├── data_fasta
│   └── contigs.fasta
├── data_out
└── platon_db
```

4. Run Platon:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/platon platon \
  --mode sensitivity --threads 8 --db /data/platon_db \
  /data/data_fasta/contigs.fasta -o /data/data_out
```

Useful options:

| Option | Meaning |
|--------|---------|
| `--db <folder>` | Database folder |
| `-o`, `--output <folder>` | Output folder |
| `--mode <mode>` | `sensitivity`, `accuracy` (default) or `specificity` |
| `--characterize` | Characterize all contigs, not only the plasmid ones |
| `--threads <n>` | Number of CPUs |
| `--prefix <name>` | Prefix of the output files. Default: the input file name |

## Outputs

Platon writes its results to the output folder, with the input file name as prefix:

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

More details: [Platon database download](https://github.com/oschwengers/platon?tab=readme-ov-file#database-download).

## Running on AWS

These are ideas for deploying Platon on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the Platon database lives on **AWS EFS**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
       wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. Store the Platon database in a volume on AWS EFS. We recommend **AWS EFS for the Platon database in production**.
3. In `/src/platon.sh`, link the **in** and **out** folders to AWS S3 and the database path to the volume on AWS EFS. You can put the links and the Platon parameters in `conf/platon.ini`.
4. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/platon /src/platon.sh
   ```

5. Push the image to your AWS account (**AWS ECR**).
6. Create an AWS Batch job, linked to the volume on AWS EFS, that points to the Platon image in AWS ECR. Give it at least 24 GB of memory (see [Requirements](#requirements)).

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=platon DOCKER_TAG=my_version
docker run --rm platon:my_version platon --version
```

Or with Docker only:

```shell
cd tools/platon
docker build --platform=linux/amd64 -t platon:my_version .
```

Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with Miniconda and Platon (from bioconda) |
| `src/platon.sh` | Script, copied to `/src` in the image: calls `platon` with the settings in `/conf/platon.ini` (an environment variable with the same name overrides each one) |
| `conf/platon.ini` | Configuration, copied to `/conf` in the image: one `KEY=VALUE` line per setting, for the input file, database and output folder |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| `diamond execution failed! diamond-error-code=-11` | Not enough memory. Give Docker or the AWS Batch job at least 24 GB |
| Platon can't find the database | `--db` must point to the extracted database folder (`platon_db`), as seen inside the container |

### Builds can change over time (by choice)

The Dockerfile installs `Miniconda3-latest` and pins only Platon 1.7. Its dependencies (DIAMOND, BLAST+, HMMER, INFERNAL, MUMmer, Prodigal) are resolved by conda at build time, in the base environment. So two builds on different dates can contain different versions of those tools; Platon itself is always 1.7. For example, the image built on 23 Oct 2026 has DIAMOND 2.2.8 and BLAST+ 2.17.0.

We keep it this way **on purpose** in this public repository: the Dockerfile stays short and easy to read and change, which matters more for most users than byte-identical rebuilds. If you need exactly the same image for a study:

* **Use a published image by its tag or digest** instead of rebuilding it, and write down the digest.
* **Record the versions in your image** with `conda list`. `make test` prints the DIAMOND and BLAST+ versions.
* **Freeze your own build** if you need to rebuild it: export the environment with `conda list --explicit > platon_env.lock.txt` and create it from that file, as the [Roary](../roary#reproducible-builds) image does.

## Citation

If you use this image, please cite Platon:

> Schwengers, O., Barth, P., Falgenhauer, L., Hain, T., Chakraborty, T., & Goesmann, A. (2020). Platon: identification and characterization of bacterial plasmid contigs in short-read draft assemblies exploiting protein sequence-based replicon distribution scores. *Microbial Genomics*, 6(10). https://doi.org/10.1099/mgen.0.000398

## Licence and references

* Platon is distributed under its own licence: see the [Platon repository](https://github.com/oschwengers/platon). This image only packages it.
* [Platon documentation](https://github.com/oschwengers/platon)
* [Platon database download](https://github.com/oschwengers/platon?tab=readme-ov-file#database-download)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
