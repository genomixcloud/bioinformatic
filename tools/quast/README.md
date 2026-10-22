# QUAST Docker image

A ready-to-run Linux (Ubuntu) Docker image of [QUAST](https://github.com/ablab/quast) 5.2.0, for the quality assessment of genome assemblies.

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/quast
docker run --name quast --rm -ti genomixcloud/quast quast.py --version

# 2. Compare the two test assemblies from the data folder of this repo
cd data
docker run --name quast --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/quast quast.py \
/data/data_fasta/contigs_1.fasta /data/data_fasta/contigs_2.fasta \
-r /data/data_fasta/reference.fasta.gz \
-o /data/data_out
```

## Requirements

* **Docker**
* **Reference database:** none. A reference genome (`-r`) and its gene annotations (`-g`) are optional, but give more metrics.
* **Input format:** one or more assemblies (contigs or scaffolds) in FASTA format (gzipped files are accepted). The reference in FASTA format and the genes in GFF format.
* **Resources:** light for bacterial genomes. Use `--threads` to set the number of CPUs.

## Run locally

1. Move to the `data` directory of this repo, which contains the FASTA files and the reference (see the tree below).

```md
root_project
├── data
│   ├── data_fasta
│   │    ├── contigs_1.fasta
│   │    ├── contigs_2.fasta
│   │    └── reference.fasta.gz
│   └── data_gff
```

2. Run QUAST:

```shell
docker run --name quast --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/quast quast.py \
/data/data_fasta/contigs_1.fasta /data/data_fasta/contigs_2.fasta \
-r /data/data_fasta/reference.fasta.gz \
-o /data/data_out
```

If you have the gene annotations of the reference genome, add `-g /data/data_gff/genes.gff`. This repo doesn't include a `genes.gff` file for the test reference.

### Expected outputs

QUAST writes its results to `data_out`:

| File | Content |
|------|---------|
| `report.txt` / `report.tsv` / `report.html` | Summary of the assembly metrics (N50, number of contigs, total length, misassemblies, genome fraction...) |
| `transposed_report.txt` / `transposed_report.tsv` | The same summary, with one assembly per line |
| `icarus.html` | Icarus contig browser, to open in a browser |
| `basic_stats/` | Plots of the basic statistics |
| `quast.log` | Run log |

## Database setup

QUAST doesn't need a database.

## AWS deployment ideas

These are ideas for deploying QUAST on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

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

2. In `/src/quast.sh`, link the **in** and **out** directories to AWS S3. The links and the QUAST parameters can be configured in `conf/quast.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name quast --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/quast /src/quast.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the QUAST image uploaded to AWS ECR.

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/quast
docker build --build-arg DEBIAN_FRONTEND=noninteractive -t genomixcloud/quast:my_version .
```

`DEBIAN_FRONTEND=noninteractive` stops the build from asking for a timezone.

### Test

```shell
docker run --name quast --rm -ti genomixcloud/quast:my_version quast.py -h
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 18.04 image with Python, Java and QUAST |
| `src/quast.sh` | Template script, copied to `/src` in the image: calls `quast.py` with the variables set in `quast.ini` |
| `conf/quast.ini` | Configuration, copied to `/conf` in the image, such as the input files and output folder |

## References and licence

* [QUAST Software](https://github.com/ablab/quast)
* [QUAST Manual](https://quast.sourceforge.net/docs/manual.html)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* QUAST is distributed under its own licence: see the [QUAST repository](https://github.com/ablab/quast)
