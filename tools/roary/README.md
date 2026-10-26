# Roary Docker image

A ready-to-run Linux (Ubuntu) Docker image of [Roary](https://github.com/sanger-pathogens/Roary/) 3.13.0, with FastTree and roary2svg, for the pan-genome analysis of prokaryotic genomes.

## Quick start

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/roary
docker run --name roary --rm -ti genomixcloud/roary /src/roary.sh -w

# 2. Build the pan-genome of the 3 test genomes in the data folder of this repo
cd data/data_gff
docker run --name roary --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/roary /src/roary.sh -e --mafft -p 8 -f pangenome *.gff
```

## Requirements

* **Docker**
* **Reference database:** none.
* **Input format:** at least 2 annotated genomes in GFF3 format, as produced by [Prokka](../prokka), with the sequences included at the end of each file.
* **Resources:** use `-p` to set the number of CPUs. Memory and run time grow with the number of genomes.

## Run locally

1. Move to the `data/data_gff` directory of this repo, which contains the GFF files (see the tree below).

```md
root_project
├── data
    ├── data_gff
        ├── PROKKA_v1.gff
        ├── PROKKA_v2.gff
        └── PROKKA_v3.gff
```

2. Run the commands below in order:

1: Build the pan-genome and the core gene alignment:
```shell
docker run --name roary --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/roary /src/roary.sh -e --mafft -p 8 -f pangenome *.gff
```

2: Build a phylogenetic tree from the core gene alignment:
```shell
docker run --name fasttree --rm \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/roary /src/fasttree.sh -nt \
-gtr pangenome/core_gene_alignment.aln > pangenome/core_gene_alignment.newick
```

3: Draw the gene presence and absence:
```shell
docker run --name roary2svg --rm \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/roary /src/roary2svg.sh pangenome/gene_presence_absence.csv --colour=Blue > pangenome/pangenome.svg
```

Don't use `-t` (`-ti`) in steps 2 and 3, where the output is redirected to a file: it mixes the log messages into the results and adds Windows line endings.

If the `pangenome` folder already exists, Roary writes to a new folder with a different name, so remove it before running step 1 again.

### Expected outputs

Roary writes its results to `pangenome`:

| File | Content |
|------|---------|
| `summary_statistics.txt` | Number of core, soft core, shell and cloud genes |
| `gene_presence_absence.csv` / `.Rtab` | Which genes are in which genome |
| `core_gene_alignment.aln` | Alignment of the core genes (with `-e`) |
| `pan_genome_reference.fa` | One sequence for each gene of the pan-genome |
| `accessory_binary_genes.fa.newick` | Tree based on the presence and absence of the accessory genes |
| `core_gene_alignment.newick` | Tree from step 2 |
| `pangenome.svg` | Picture from step 3 |

## Database setup

Roary doesn't need a database.

## AWS deployment ideas

These are ideas for deploying Roary on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

### Architecture

Input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs.

### Required services

AWS S3, AWS ECR and AWS Batch, plus AWS Networking and AWS IAM to connect them.

### Steps

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image (`src/Dockerfile` already includes it):

```shell
RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
unzip -d /usr/src/  /usr/src/awscli-exe-linux-x86_64.zip && \
rm /usr/src/awscli-exe-linux-x86_64.zip && \
/usr/src/aws/install
```

2. In `/src/roary.sh`, link the **in** and **out** directories to AWS S3 and call Roary, FastTree and roary2svg in the order above (the commands are already in the script, commented out). You can place the S3 configuration and the parameters in `conf/roary.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name roary --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/roary /src/roary.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the Roary image uploaded to AWS ECR.

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/roary
docker build --platform=linux/amd64 --build-arg DEBIAN_FRONTEND=noninteractive -t genomixcloud/roary:my_version .
```

`DEBIAN_FRONTEND=noninteractive` stops the build from asking for a timezone.

### Test

We test **roary**, **fasttree** and **roary2svg**:

```shell
docker run --name roary --rm -ti genomixcloud/roary:my_version /src/roary.sh -w
docker run --name roary --rm -ti genomixcloud/roary:my_version /src/roary.sh --help
docker run --name roary2svg --rm -ti genomixcloud/roary:my_version /src/roary2svg.sh --help
docker run --name fasttree --rm -ti genomixcloud/roary:my_version /src/fasttree.sh --help
```

Then run the steps in [Run locally](#run-locally) with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with Miniconda, the `roary_env` conda environment and roary2svg |
| `environment.yaml` | Conda environment: Roary (FastTree, MAFFT and the other dependencies come with it) |
| `src/roary.sh` | Script, copied to `/src` in the image: activates the conda environment and calls `roary` with the given arguments |
| `src/fasttree.sh` | Same for `fasttree` |
| `src/roary2svg.sh` | Same for `roary2svg.pl` |
| `src/Dockerfile` | Variant of the Dockerfile that already installs the AWS CLI |
| `conf/roary.ini` | Configuration, copied to `/conf` in the image, such as the input and output folders |

## References and licence

* [Roary Software](https://github.com/sanger-pathogens/Roary/)
* [Source data to generate Roary input data](https://github.com/microgenomics/tutorials/blob/master/pangenome.md)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* Roary is distributed under its own licence: [Roary licence](https://github.com/sanger-pathogens/Roary/blob/master/GPL-LICENSE)
