# Bakta Docker image

A ready-to-run Linux (Ubuntu) Docker image of [Bakta](https://github.com/oschwengers/bakta) 1.11.4, for the rapid and standardized annotation of bacterial genomes and plasmids.

## Quick start

This example uses the Bakta **light database** (a few GB) so you can try the image quickly. For real analyses use the full database (see [Database setup](#database-setup)).

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/bakta
docker run --name bakta --rm -ti genomixcloud/bakta /src/bakta.sh --version

# 2. Download the light database into the current directory (creates ./db-light)
docker run --name bakta --rm -ti --mount src="$(pwd)",target=/data,type=bind \
genomixcloud/bakta /bin/bash -c "source activate bakta_env && bakta_db download --output /data --type light"

# 3. Download a small test genome
curl -o contig.fasta.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz
gunzip contig.fasta.gz

# 4. Annotate it
docker run --name bakta --rm -ti --mount src="$(pwd)",target=/data,type=bind \
genomixcloud/bakta /src/bakta.sh --db /data/db-light contig.fasta --output data_out
```

## Requirements

* **Docker**
* **Reference database (mandatory):** Bakta can't run without its database. Two types are available:
  * **full:** > 30GB compressed (**around 64GB uncompressed**), recommended for real analyses
  * **light:** a few GB, good for testing
* **Storage:** keep the database in external storage, or on AWS EFS when running on AWS, and mount it into the container.
* **Input format:** genome assemblies (contigs) in FASTA format.
* **Resources:** annotation is CPU intensive, so use `--threads` to set the number of CPUs Bakta uses.

## Run locally

1. Change to the directory where you downloaded the test data or where you stored your data.
2. Run Bakta, mounting your data on `/data` and the database on `/db`:

```shell
docker run --name bakta --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
--mount src=/path/to/external/storage/db,target=/db,type=bind \
genomixcloud/bakta /src/bakta.sh --db /db --threads 8 contig.fasta --output data_out
```

Don't create `data_out` before running: Bakta creates it, and stops with `ERROR: output path (...) already exists!` if it's already there. To run again into the same folder, add `--force`.

Test data:

```shell
#wget
wget https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz -O contig.fasta.gz
gunzip contig.fasta.gz
```

```shell
#curl osx
curl -o contig.fasta.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz
gunzip contig.fasta.gz
```

### Expected outputs

Bakta writes its results to `data_out`, with the input file name as prefix:

| File | Content |
|------|---------|
| `.tsv` | Annotations as a simple tab-separated table |
| `.gff3` | Annotations and sequences in GFF3 format |
| `.gbff` | Annotations and sequences in GenBank format |
| `.embl` | Annotations and sequences in EMBL format |
| `.fna` | Replicon and contig DNA sequences |
| `.ffn` | Feature nucleotide sequences |
| `.faa` | CDS and sORF amino acid sequences |
| `.json` | All results in machine-readable JSON |
| `.txt` | Summary of the annotation |
| `.png` / `.svg` | Circular genome plot |
| `.hypotheticals.tsv` / `.hypotheticals.faa` | Further information on hypothetical proteins |
| `.inference.tsv` | Inference metrics for each feature |
| `.log` | Run log |

## Database setup

Because of its size, create the full database in external storage:

1. Change directory to your external storage.
2. Run the following commands:

```shell
docker run --name bakta --rm -ti --mount src="$(pwd)",target=/data,type=bind genomixcloud/bakta bash
## Inside the container /data is our workdir but you can specify a detailed path in your external storage
bakta_db download --output /data --type full
```

The database is downloaded to the `db` folder inside the output directory. Mount that folder on `/db` when you run Bakta.

To set up the database on an AWS EC2 instance, see [aws/database-setup/bakta](../../aws/database-setup/bakta).

ref: [bakta database download](https://github.com/oschwengers/bakta/blob/main/README.md#database-download)

## AWS deployment ideas

These are ideas for deploying Bakta on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

### Architecture

Input and output files live in **AWS S3**, the full database lives on **AWS EFS**, the image is stored in **AWS ECR**, and **AWS Batch** runs the annotation jobs.

### Required services

AWS S3, AWS ECR, AWS EFS and AWS Batch, plus AWS Networking and AWS IAM to connect them.

### Steps

1. Add the AWS CLI to the image: in the `environment.yaml` file, under **dependencies**, add `- awscli` and rebuild the image.
2. Store the full database (around 64GB) in a volume on AWS EFS.
3. In `/src/bakta.sh`, link the **in** and **out** directories to AWS S3 and the database path to the volume on AWS EFS. Both links can be configured in `conf/bakta.ini`.
4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job, linked to the volume on AWS EFS, that points to the Bakta image uploaded to AWS ECR.

This only covers the core aspects. For the detailed AWS guide, see [aws/database-setup/bakta](../../aws/database-setup/bakta) and the benchmarks in [aws/performance/bakta](../../aws/performance/bakta).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/bakta
docker build --platform=linux/amd64 -t genomixcloud/bakta:my_version .
```

### Test

```shell
docker run --name bakta --rm -ti genomixcloud/bakta:my_version /src/bakta.sh --version
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with Miniconda and the `bakta_env` conda environment |
| `environment.yaml` | Conda environment: Bakta, AMRFinderPlus and Python |
| `src/bakta.sh` | Entrypoint, copied to `/src` in the image: activates the conda environment and calls `bakta` with the given arguments |
| `conf/bakta.ini` | Configuration, such as the S3 bucket input and output folders |

## References and licence

* [Bakta Software](https://github.com/oschwengers/bakta/blob/main/README.md#installation)
* [Bakta Manual](https://github.com/oschwengers/bakta/blob/main/README.md)
* [Bakta database download](https://github.com/oschwengers/bakta/blob/main/README.md#database-download)
* Bakta is distributed under its own licence: [Bakta licence](https://github.com/oschwengers/bakta/blob/main/LICENSE)
