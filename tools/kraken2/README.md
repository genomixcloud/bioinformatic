# Kraken2 Docker image

A ready-to-run Linux (Ubuntu) Docker image of [Kraken2](https://github.com/DerrickWood/kraken2) 2.1.6, for the taxonomic classification of sequencing reads.

## Quick start

This example uses the 8GB **MiniKraken2 database** so you can try the image quickly. For real analyses use a full database (see [Database setup](#database-setup)).

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/kraken2
docker run --name kraken2 --rm -ti genomixcloud/kraken2 kraken2 --version

# 2. Download the MiniKraken2 database into ./kraken_db
#    (move the .k2d files to kraken_db if the archive extracts them into a subfolder)
mkdir kraken_db
curl -o minikraken2.tgz https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v2_8GB_201904.tgz
tar -xzf minikraken2.tgz -C kraken_db

# 3. Classify the trimmed test reads from the data folder of this repo
#    (copy data_in_trimmed next to kraken_db first)
mkdir -p data_out/taxonomic_identification
docker run --name kraken2 --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/kraken2 kraken2 --paired \
/data/data_in_trimmed/trimmed_reads_1.fastq.gz /data/data_in_trimmed/trimmed_reads_2.fastq.gz \
--db /data/kraken_db --threads 8 --memory-mapping \
--output /data/data_out/taxonomic_identification/kraken-output.txt \
--report /data/data_out/taxonomic_identification/kraken-report.txt
```

## Requirements

* **Docker**
* **Reference database (mandatory):** Kraken2 can't run without a database. The MiniKraken2 database (8GB) is good for testing. The Kraken2 Standard database is much bigger and is recommended for real analyses.
* **Storage:** keep the database in external storage, or on AWS EFS when running on AWS, and mount it into the container.
* **Input format:** single-end or paired-end reads in FASTQ or FASTA format (gzipped files are accepted).
* **Resources:** Kraken2 loads the whole database into memory. If Docker has less memory than the size of the database, add `--memory-mapping` (see [Run locally](#run-locally)). Use `--threads` to set the number of CPUs.

## Run locally

1. Download the Kraken2 database to the **kraken_db** directory (for a local test, use the [MiniKraken2 database](https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v2_8GB_201904.tgz)).
2. Move to the `data` directory of this repo, which contains the trimmed sample reads, and put `kraken_db` inside it.
3. **Create** the output directory (**data_out/taxonomic_identification** in our example). Kraken2 doesn't create it.

```md
root_project
├── data
│   ├── kraken_db
│   ├── data_out
│   │   └── taxonomic_identification
│   ├── data_in_trimmed
│       ├── trimmed_reads_1.fastq.gz
│       ├── trimmed_reads_2.fastq.gz
```

4. Run Kraken2:

```shell
docker run --name kraken2 --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/kraken2 kraken2 --paired \
/data/data_in_trimmed/trimmed_reads_1.fastq.gz /data/data_in_trimmed/trimmed_reads_2.fastq.gz \
--db /data/kraken_db --threads 8 --memory-mapping \
--output /data/data_out/taxonomic_identification/kraken-output.txt \
--report /data/data_out/taxonomic_identification/kraken-report.txt
```

A remarkable aspect: the **--memory-mapping** option is **mandatory** in this configuration, because Docker usually has less memory than the database needs.

Without `--output`, Kraken2 prints one line per read on the screen. With millions of reads, save it to a file, or use `--output -` with care.

### Expected outputs

| File | Content |
|------|---------|
| `kraken-report.txt` | Summary per taxon: percentage of reads, number of reads in the clade, number of reads assigned directly, rank code, NCBI taxonomy ID and scientific name |
| `kraken-output.txt` | One line per read (or read pair): classified (`C`) or unclassified (`U`), read ID, taxonomy ID, length and k-mer mapping |

## Database setup

* **For testing:** the [MiniKraken2 database](https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v2_8GB_201904.tgz) (8GB).
* **For real analyses:** the Kraken2 Standard database. See [How to create Kraken2 Standard (v2.1.3) DB in AWS](https://github.com/ldipotetjob/kraken2/tree/kraken2aws_profilingfromv2.1.3/docs/awsStandardDB#readme).
* **On an AWS EC2 instance:** see [aws/database-setup/kraken2](../../aws/database-setup/kraken2).

The image also includes `kraken2-build` to build your own database:

```shell
docker run --name kraken2-build --rm -ti genomixcloud/kraken2 kraken2-build --help
```

## AWS deployment ideas

These are ideas for deploying Kraken2 on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

### Architecture

Input and output files live in **AWS S3**, the Kraken2 database lives on **AWS EFS**, the image is stored in **AWS ECR**, and **AWS Batch** runs the classification jobs.

### Required services

AWS S3, AWS ECR, AWS EFS and AWS Batch, plus AWS Networking and AWS IAM to connect them.

### Steps

1. Add the AWS CLI to the image: in the Dockerfile, add the following code and rebuild the image:

```shell
RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
unzip -d /usr/src/  /usr/src/awscli-exe-linux-x86_64.zip && \
rm /usr/src/awscli-exe-linux-x86_64.zip && \
/usr/src/aws/install
```

2. Store the Kraken2 Standard database in a volume on AWS EFS.
3. In `/src/kraken2.sh`, link the **in** and **out** directories to AWS S3 and the database path to the volume on AWS EFS. Kraken2 can't read `s3://` paths directly, so the script must copy the reads from S3 first and copy the results back afterwards. The links and the Kraken2 parameters can be configured in `conf/kraken.ini`.
4. Test it locally with your AWS credentials:

```shell
docker run --name kraken2 --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--mount src="$(pwd)",target=/data,type=bind \
${your_own_workspace}/kraken2 /src/kraken2.sh
```

5. Push the image to your AWS account (**AWS ECR**).
6. Create an AWS Batch job, linked to the volume on AWS EFS, that points to the Kraken2 image uploaded to AWS ECR.

Remarkable aspects:

1. We don't recommend [--memory-mapping in production environment](https://github.com/ldipotetjob/kraken2/blob/kraken2aws_profilingfromv2.1.3/docs/Kraken2paramsonAWS/memory-mapping.md#memory-mapping-option).
2. [Profiling info](https://github.com/ldipotetjob/kraken2/tree/kraken2aws_profilingfromv2.1.3/docs/awsStandardDB/profilingpngs)
3. We recommend AWS EFS for storing the Kraken2 Standard (v2.1.3) database in production.

This only covers the core aspects. For the detailed AWS guide, see [aws/database-setup/kraken2](../../aws/database-setup/kraken2) and the benchmarks in [aws/performance/kraken2](../../aws/performance/kraken2).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/kraken2
docker build --platform=linux/amd64 -t genomixcloud/kraken2:my_version .
```

### Test

```shell
docker run --name kraken2 --rm -ti genomixcloud/kraken2:my_version kraken2 --version
docker run --name blastn --rm -ti genomixcloud/kraken2:my_version blastn -version
docker run --name kraken2-build --rm -ti genomixcloud/kraken2:my_version kraken2-build --help
```

Then run the [Quick start](#quick-start) example with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 22.04 image with Kraken2 (built from source), BLAST+ and rsync |
| `src/kraken2.sh` | Template script, copied to `/src` in the image: calls `kraken2` with the variables set in `kraken.ini` |
| `conf/kraken.ini` | Configuration, copied to `/conf` in the image, such as the input reads, database and output folder |

## References and licence

* [Kraken2 Software](https://github.com/DerrickWood/kraken2)
* [Kraken2 Manual](https://github.com/DerrickWood/kraken2/blob/master/docs/MANUAL.markdown)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* Kraken2 is distributed under its own licence: [Kraken2 licence](https://github.com/DerrickWood/kraken2/blob/master/LICENSE)
