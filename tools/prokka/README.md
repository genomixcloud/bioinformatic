# Prokka Docker image

A ready-to-run Linux Docker image of [Prokka](https://github.com/tseemann/prokka), for the rapid annotation of prokaryotic genomes.

| | |
|---|---|
| **Image** | [`genomixcloud/prokka`](https://hub.docker.com/r/genomixcloud/prokka) |
| **Tool version** | Prokka 1.14.6 |
| **Platform** | `linux/amd64` |
| **Database** | Included (indexed at build time) |
| **Input → output** | Assembly (FASTA) → annotation (GFF3, GenBank, FASTA, TSV) |
| **Pipeline step** | After assembly ([SPAdes](../spades), [Pilon](../pilon)) and before pan-genome analysis ([Roary](../roary)). An alternative to [Bakta](../bakta) |

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
docker pull genomixcloud/prokka
docker run --rm genomixcloud/prokka prokka --version

# 2. Annotate the test contigs from the data folder of this repo
cd data
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/prokka prokka data_fasta/contigs.fasta --outdir data_out/prokka --cpu 4 --force
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 22.04 | |
| Prokka | 1.14.6 | From the GitHub release `v1.14.6`. Includes Prodigal, Aragorn and the other binaries that come with it |
| BLAST+ | 2.9.0 | From the NCBI FTP |
| barrnap | 0.9 | rRNA prediction |
| bedtools | 2.29.0 | Built from source. barrnap needs 2.27.0 or later |
| tbl2asn | 25.6 | From bioconda. Runs under `faketime` with the date 2019-01-01, because this release stops working when it's more than a year old. Needs `libidn11`, installed from the Ubuntu 20.04 package. Older copies are in [binaries](../../binaries/README_tbl2asn.md) |
| HMMER, BioPerl, Java | Ubuntu 22.04 packages | BioPerl's HMMER3 parser comes from `libbio-searchio-hmmer-perl` |
| Prokka databases | as included in Prokka 1.14.6 | Indexed with `prokka --setupdb` at build time |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** genome assemblies (contigs) in FASTA format.
* **Database:** none to download. The Prokka databases are inside the image. To list them, run `prokka --listdb`.
* **Resources:** use `--cpu` to set the number of CPUs.

## Usage

From the `data` folder of this repo:

```md
data
└── data_fasta
    └── contigs.fasta
```

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/prokka prokka data_fasta/contigs.fasta --outdir data_out/prokka --cpu 4 --force
```

`/src/prokka.sh` passes all its arguments to `prokka`, so you can also call `/src/prokka.sh` instead of `prokka`. Useful options:

| Option | Meaning |
|--------|---------|
| `--outdir <folder>` | Output folder. Prokka creates it. Without it, Prokka writes to a new `PROKKA_<date>` folder |
| `--force` | Write into the output folder if it already exists |
| `--prefix <name>` | Prefix of the output files. Default: `PROKKA_<date>` |
| `--cpu <n>` | Number of CPUs. `0` means all |
| `--kingdom <name>` | `Bacteria` (default), `Archaea`, `Mitochondria` or `Viruses` |
| `--genus`, `--species`, `--strain` | Organism names written into the annotation |
| `--locustag <tag>` | Prefix of the locus tags |

## Outputs

Prokka writes its results to the output folder, with the prefix `PROKKA_<date>` (set your own with `--prefix`):

| File | Content |
|------|---------|
| `.gff` | Annotations and sequences in GFF3 format. This is the input of [Roary](../roary) |
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

If you have a problem with tbl2asn (you shouldn't), you can find other tbl2asn releases in the [binaries folder](../../binaries/README_tbl2asn.md).

## Running on AWS

These are ideas for deploying Prokka on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
       wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. In `/src/prokka.sh`, link the **in** and **out** folders to AWS S3. You can put the links and the Prokka parameters in `conf/prokka.ini`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/prokka /src/prokka.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the Prokka image in AWS ECR.

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=prokka DOCKER_TAG=my_version BUILD_ARG="DEBIAN_FRONTEND=noninteractive"
docker run --rm prokka:my_version prokka --version
```

Or with Docker only:

```shell
cd tools/prokka
docker build --platform=linux/amd64 --build-arg DEBIAN_FRONTEND=noninteractive -t prokka:my_version .
```

`DEBIAN_FRONTEND=noninteractive` stops the build from asking for a timezone. Then run the [Quick start](#quick-start) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 22.04 image with Prokka, BLAST+ 2.9.0, barrnap, bedtools and tbl2asn |
| `test.sh` | Smoke test, run by `make test`: checks the Prokka and BLAST+ versions and annotates a 20 kb sequence (GFF and GenBank) |
| `src/prokka.sh` | Entrypoint, copied to `/src` in the image: calls `prokka` with the given arguments |
| `conf/prokka.ini` | Configuration, copied to `/conf` in the image: one `KEY=VALUE` line per setting, for the S3 input and output folders |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| `Folder 'data_out/prokka' already exists! Please change --outdir or use --force` | Add `--force`, or choose another `--outdir` |
| `Could not run command: tbl2asn ...` and exit code 2 | `tbl2asn` 25.6 refuses to run once it's more than a year old. This image runs it with a fixed date (`faketime`); if you build your own image, keep the wrapper. Other releases are in [binaries](../../binaries/README_tbl2asn.md) |
| Roary fails on the GFF | Prokka's `.gff` includes the sequences at the end, which Roary needs. Don't use the `.gbk` or strip the `##FASTA` section |

Known issues in the image, not fixed yet:

* Prokka 1.14.6 is the last Prokka release. For new projects, [Bakta](../bakta) is its successor.
* The GenBank files (`.gbk`, `.sqn`) carry the date that `tbl2asn` sees, 2019-01-01, instead of the real date.

## Citation

If you use this image, please cite Prokka:

> Seemann, T. (2014). Prokka: rapid prokaryotic genome annotation. *Bioinformatics*, 30(14), 2068–2069. https://doi.org/10.1093/bioinformatics/btu153

## Licence and references

* Prokka is distributed under its own licence: [Prokka licence](https://github.com/tseemann/prokka/blob/master/LICENSE). The tools it bundles have their own licences. This image only packages them.
* [Prokka software and manual](https://github.com/tseemann/prokka)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
