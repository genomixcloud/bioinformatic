# mlst Docker image

A ready-to-run Linux Docker image of [mlst](https://github.com/tseemann/mlst), for the multi-locus sequence typing (MLST) of genome assemblies against the PubMLST schemes.

| | |
|---|---|
| **Image** | [`genomixcloud/mlst`](https://hub.docker.com/r/genomixcloud/mlst) |
| **Tool version** | mlst 2.23.0 |
| **Platform** | `linux/amd64` |
| **Database** | Included: the PubMLST schemes that come with the mlst release |
| **Input → output** | Assembly (FASTA, GenBank or EMBL) → scheme, sequence type (ST) and alleles |
| **Pipeline step** | After assembly ([SPAdes](../spades), [Pilon](../pilon)), next to [FimTyper](../fimtyper) for typing |

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
docker pull genomixcloud/mlst
docker run --rm genomixcloud/mlst mlst --version

# 2. Type the example genome from the data folder of this repo
cd data
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/mlst mlst --csv /data/data_fna/example.fna.gz > mlst.csv
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 20.04 | Chosen for BLAST+ 2.9.0: Ubuntu 18.04 only has 2.6.0, and mlst needs 2.9.0 or later |
| mlst | 2.23.0 | From the GitHub release `v2.23.0` |
| PubMLST schemes and BLAST database | as included in mlst 2.23.0 | `mlst --list` shows them |
| BLAST+ | 2.9.0 (Ubuntu 20.04 package) | |
| any2fasta | 0.4.2 | Converts GenBank and EMBL input to FASTA |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** genome assemblies in FASTA, GenBank or EMBL format. Gzipped files are accepted.
* **Database:** none to download. The PubMLST schemes come with mlst and are inside the image.
* **Resources:** light. Use `--threads` to set the number of CPUs.

## Usage

From the `data` folder of this repo:

```md
data
├── data_fasta
│   └── contigs.fasta
└── data_fna
    └── example.fna.gz
```

mlst writes its results to standard output, so redirect them to a file:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/mlst mlst --csv --nopath --quiet --threads 2 \
  /data/data_fasta/contigs.fasta > mlst.csv
```

Useful options:

| Option | Meaning |
|--------|---------|
| `--csv` | Comma-separated output instead of tab-separated |
| `--nopath` | Write only the file name, without the folder |
| `--scheme <name>` | Use this scheme instead of detecting it automatically. `mlst --list` shows the names |
| `--threads <n>` | Number of CPUs |
| `--quiet` | Only print the results |
| `--minid`, `--mincov` | Minimum % identity and coverage of an allele |

## Outputs

`mlst.csv`, with one line per genome: the file name, the MLST scheme found, the sequence type (ST) and the allele number of each locus. Symbols next to an allele mean an exact match (`n`), a novel allele (`~n`), a partial match (`n?`), several alleles (`n,m`) or a missing allele (`-`).

## Database setup

No setup is needed: the PubMLST schemes and BLAST database come with the mlst release installed in the image. To get newer schemes, rebuild the image with a newer mlst version (`MlstVer` in the Dockerfile).

## Running on AWS

These are ideas for deploying mlst on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

   ```dockerfile
   RUN wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. In `/src/mlst.sh`, link the **in** and **out** folders to AWS S3. You can put the links and the mlst parameters in `conf/mlst.ini`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/mlst /src/mlst.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the mlst image in AWS ECR.

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=mlst DOCKER_TAG=my_version
docker run --rm mlst:my_version mlst --version
```

Or with Docker only:

```shell
cd tools/mlst
docker build --platform=linux/amd64 -t mlst:my_version .
```

Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with mlst, BLAST+ and any2fasta |
| `src/mlst.sh` | Template script, copied to `/src` in the image: calls `mlst` with the variables set in `mlst.ini` |
| `conf/mlst.ini` | Configuration template, copied to `/conf` in the image, for the input file and output folder |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| The output file has log messages or Windows line endings | Don't use `-t` (`-ti`) in `docker run` when you redirect the output to a file. Add `--quiet` |
| The scheme column is `-` | No scheme matched. Check the species, or set it with `--scheme` |

Known issues in the image, not fixed yet:

* `src/mlst.sh` is a template: the variables it uses aren't read from `conf/mlst.ini` yet. The header comments of the script and of `conf/mlst.ini` were copied from SPAdes and QUAST and still name those tools.

## Citation

If you use this image, please cite mlst and PubMLST:

> Seemann, T. mlst: scan contig files against PubMLST typing schemes. https://github.com/tseemann/mlst

> Jolley, K. A., Bray, J. E., & Maiden, M. C. J. (2018). Open-access bacterial population genomics: BIGSdb software, the PubMLST.org website and their applications. *Wellcome Open Research*, 3, 124. https://doi.org/10.12688/wellcomeopenres.14826.1

## Licence and references

* mlst is distributed under its own licence: [mlst licence](https://github.com/tseemann/mlst/blob/master/LICENSE). The PubMLST schemes have their own terms of use. This image only packages them.
* [mlst software and manual](https://github.com/tseemann/mlst)
* [PubMLST](https://pubmlst.org/)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
