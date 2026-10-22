# CheckM Docker image

A ready-to-run Linux (Ubuntu) Docker image of [CheckM](https://github.com/Ecogenomics/CheckM), with its reference database included, for assessing the quality (completeness and contamination) of genomes.

## Quick start

The CheckM database is already inside the image, so you can test it straight away with the test genome that comes with the database:

```shell
# 1. Pull the image
docker pull genomixcloud/checkm

# 2. Run the test genome
docker run --name checkm --rm -ti genomixcloud/checkm \
checkm taxonomy_wf species "Escherichia coli" /data/checkm_db/test_data/ /tmp/checkm_test_results
```

## Requirements

* **Docker**
* **Reference database:** included in the image at `/data/checkm_db` (CheckM data release 2015-01-16).
* **Storage:** don't mount your data on `/data`, because it hides the database inside the image. Mount it on `/data/work` instead (see [Run locally](#run-locally)).
* **Input format:** genomes or bins in FASTA format, one file per genome. Use `-x` to set the file extension (for example `-x fasta`).
* **Resources:** `taxonomy_wf` needs little memory. The `tree` step runs pplacer, which needs around 40GB of RAM with the full tree, or around 14GB with `--reduced_tree`.

## Run locally

1. Change to the `data` folder of this repo, which contains the `data_fasta` folder.
2. Run CheckM, mounting the current directory on `/data/work`:

```shell
docker run --name checkm --rm -ti \
--mount src="$(pwd)",target=/data/work,type=bind \
genomixcloud/checkm checkm taxonomy_wf life Prokaryote \
/data/work/data_fasta -x fasta /data/work/data_out
```

You can also call the following CheckM commands the same way (follow the order):

1. `checkm tree /data/work/data_fasta/ -x fasta /data/work/data_out --reduced_tree --threads 8`
2. `checkm tree_qa -o 2 /data/work/data_out`
3. `checkm gc_plot /data/work/data_out/bins /data/work/data_out/plots 95`

### Expected outputs

* A table printed on screen with, for each genome, the marker lineage, the number of marker genes found, and the **Completeness**, **Contamination** and **Strain heterogeneity**. To save it to a file, add `-f /data/work/data_out/results.tsv --tab_table`.
* The `data_out` folder, with the intermediate files (`bins/`, `storage/`) and `checkm.log`.

## Database setup

No setup is needed: the database is downloaded when the image is built and registered with `checkm data setRoot`.

To use a different copy of the database, download it from the [CheckM databases](https://data.ace.uq.edu.au/public/CheckM_databases/), mount it into the container (for example on `/checkm_db`) and run `checkm data setRoot /checkm_db` before your CheckM command in the same container.

## AWS deployment ideas

These are ideas for deploying CheckM on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

### Architecture

Input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs.

### Required services

AWS S3, AWS ECR and AWS Batch, plus AWS Networking and AWS IAM to connect them.

### Steps

1. Add the AWS CLI to the image: in the Dockerfile, add the following code and rebuild the image:

```shell
RUN wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
unzip -d /usr/src/  /usr/src/awscli-exe-linux-x86_64.zip && \
rm /usr/src/awscli-exe-linux-x86_64.zip && \
/usr/src/aws/install
```

2. In `/src/checkm.sh`, link the **data_in** and **data_out** directories to AWS S3. The links and the CheckM parameters can be configured in `conf/checkm.ini`.
3. Test it locally with your AWS credentials:

```shell
docker run --name checkm --rm -ti \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
${your_own_workspace}/checkm /src/checkm.sh
```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the CheckM image uploaded to AWS ECR. Give it enough memory for the `tree` step (see [Requirements](#requirements)).

This only covers the core aspects. For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test the image

For contributors and developers.

### Build

```shell
cd tools/checkm
docker build -t genomixcloud/checkm:my_version .
```

The build downloads the CheckM database (around 1.4GB uncompressed) into the image.

### Test

```shell
docker run --name checkm --rm -ti genomixcloud/checkm:my_version \
checkm taxonomy_wf species "Escherichia coli" /data/checkm_db/test_data/ /tmp/checkm_test_results
```

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 22.04 (jammy) image with CheckM (pip), pplacer, HMMER, Prodigal and the CheckM database |
| `src/checkm.sh` | Template script, copied to `/src` in the image: runs `taxonomy_wf`, `tree`, `tree_qa` and `gc_plot` with the variables set in `checkm.ini` |
| `conf/checkm.ini` | Configuration, copied to `/conf` in the image, such as the input and output folders |

## References and licence

* [CheckM Software](https://github.com/Ecogenomics/CheckM)
* [CheckM Manual](https://ecogenomics.github.io/CheckM/)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
* CheckM is distributed under its own licence: [CheckM licence](https://github.com/Ecogenomics/CheckM/blob/master/LICENSE)
