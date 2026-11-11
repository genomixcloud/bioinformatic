# FimTyper Docker image

A ready-to-run Linux Docker image of [FimTyper](https://bitbucket.org/genomicepidemiology/fimtyper/), with its database included, for the FimH typing of *Escherichia coli* genomes. This is an **alpha** image (see [Note.md](Note.md)).

| | |
|---|---|
| **Image** | [`genomixcloud/fimtyper`](https://hub.docker.com/r/genomixcloud/fimtyper) |
| **Tool version** | FimTyper commit `311023b` (10 Mar 2022; image label `0.0.1-a.0`) |
| **Platform** | `linux/amd64` |
| **Database** | Included in the image: fimtyper_db commit `820782c` (27 Jul 2023) |
| **Input → output** | *E. coli* assembly (FASTA) → FimH type |
| **Pipeline step** | After assembly ([SPAdes](../spades), [Pilon](../pilon)), next to [mlst](../mlst) for typing |

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

The FimTyper database and a test genome are already inside the image:

```shell
# 1. Pull the image and check the installation (prints the FimTyper options)
docker pull genomixcloud/fimtyper
docker run --rm genomixcloud/fimtyper perl /usr/local/fimtyper/fimtyper.pl -h

# 2. Run the test genome, writing the results to ./data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/fimtyper perl /usr/local/fimtyper/fimtyper.pl \
  -d /usr/local/fimtyper/fimtyper_db \
  -i /usr/local/fimtyper/test.fsa -o /data/data_out -k 95.00 -l 0.60
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 20.04 | |
| FimTyper | commit `311023be5c2c` (10 Mar 2022) | No release tags: pinned with `FIMTYPER_COMMIT` in the Dockerfile |
| FimTyper database | commit `820782c9dd73` (27 Jul 2023) | In `/usr/local/fimtyper/fimtyper_db`. Pinned with `FIMTYPER_DB_COMMIT`. Upstream has two newer monthly updates |
| BLAST+ | Ubuntu 20.04 package (`ncbi-blast+`) | `src/update_blast-ver.sh` can add another version next to it |
| Perl and modules | Ubuntu 20.04 Perl, modules installed with cpanm | Installed by `src/tmp_brew.sh` |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** preassembled partial or complete *E. coli* genomes in FASTA format.
* **Database:** included in the image at `/usr/local/fimtyper/fimtyper_db`.
* **Resources:** light.

## Usage

Mount your data folder on `/data`:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
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

More options: [FimTyper usage](https://bitbucket.org/genomicepidemiology/fimtyper/src/master/README.md#usage).

## Outputs

FimTyper writes its result files, with the FimH type found and the alignment of the best hit, to the output folder.

## Database setup

No setup is needed: the database is cloned from the [fimtyper_db repository](https://bitbucket.org/genomicepidemiology/fimtyper_db) at the pinned commit when the image is built. To use a newer version, change `FIMTYPER_DB_COMMIT` in the Dockerfile and rebuild; results can then change.

## Running on AWS

These are ideas for deploying FimTyper on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image. It also creates the `/src` and `/conf` folders, which this image doesn't have yet:

   ```dockerfile
   RUN wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install && \
       mkdir /src && mkdir /conf
   ```

2. Create `/src/fimtyper.sh`. It must call `/usr/local/fimtyper/fimtyper.pl` with the **input** folder linked to AWS S3. You can put the S3 configuration and the FimTyper parameters in `/conf`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/fimtyper /src/fimtyper.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the FimTyper image in AWS ECR.

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=fimtyper DOCKER_TAG=my_version
docker run --rm fimtyper:my_version perl /usr/local/fimtyper/fimtyper.pl -h
```

Or with Docker only:

```shell
cd tools/fimtyper
docker build --platform=linux/amd64 -t fimtyper:my_version .
```

Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with Perl, BLAST+, FimTyper and its database |
| `src/tmp_brew.sh` | Installs cpanm and the FimTyper Perl dependencies when the image is built |
| `src/update_blast-ver.sh` | Installs a specific BLAST+ version in `/usr/local/fimtyper/` (default 2.14.0, see [Note.md](Note.md)) |
| `conf/fimtyper.ini` | Configuration template for the FimTyper parameters. It isn't copied into the image yet |
| `test.sh` | Smoke test, run by `make test`: checks the pinned commits and types the test genome |
| `Note.md` | Notes on how the image was made and the improvements planned |

The scripts in `src/` are copied to `/usr/local/fimtyper` in the image, not to `/src`.

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| No results after the container stops | Add `-o /data/<folder>`: without it the results stay inside the container |
| No FimH type found | The genome may not be *E. coli*, or the thresholds are too strict. Check `-k` and `-l` |

Known issues in the image, not fixed yet:

* Planned in [Note.md](Note.md): a multi-stage build to make the image smaller, and a non-root user.

## Citation

If you use this image, please cite FimTyper:

> Roer, L., Tchesnokova, V., Allesøe, R., Muradova, M., Chattopadhyay, S., Ahrenfeldt, J., Thomsen, M. C. F., Lund, O., Hansen, F., Hammerum, A. M., Sokurenko, E., & Hasman, H. (2017). Development of a web tool for *Escherichia coli* subtyping based on *fimH* alleles. *Journal of Clinical Microbiology*, 55(8), 2538–2543. https://doi.org/10.1128/JCM.00737-17

## Licence and references

* FimTyper is distributed under the [Apache License, Version 2.0](https://bitbucket.org/genomicepidemiology/fimtyper/src/master/README.md#license). This image only packages it.
* [FimTyper main documentation](https://bitbucket.org/genomicepidemiology/fimtyper/)
* [fimtyper_db repository](https://bitbucket.org/genomicepidemiology/fimtyper_db)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
