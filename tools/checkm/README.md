# CheckM Docker image

A ready-to-run Linux Docker image of [CheckM](https://github.com/Ecogenomics/CheckM), with its reference database included, for assessing the quality (completeness and contamination) of genomes recovered from isolates, single cells and metagenomes.

| | |
|---|---|
| **Image** | [`genomixcloud/checkm`](https://hub.docker.com/r/genomixcloud/checkm) |
| **Tool version** | CheckM 1.2.5 |
| **Platform** | `linux/amd64` |
| **Database** | Included in the image: CheckM data release 2015-01-16, about 1.4 GB |
| **Input → output** | Genomes or bins (FASTA) → completeness, contamination and strain heterogeneity |
| **Pipeline step** | After assembly ([SPAdes](../spades), [Pilon](../pilon)), next to [QUAST](../quast) |

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

The database is already inside the image, so you can test it straight away with the test genome that comes with it:

```shell
docker pull genomixcloud/checkm
docker run --rm genomixcloud/checkm \
  checkm taxonomy_wf species "Escherichia coli" /data/checkm_db/test_data/ /tmp/checkm_test_results
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 22.04 (jammy) | |
| CheckM (`checkm-genome`) | 1.2.5 | From PyPI, pinned. The Dockerfile used to declare 1.2.4 but installed the latest release; 1.2.5 is the version in the image of 23 Oct 2026 |
| numpy, matplotlib, pysam, scipy | 2.2.6, 3.10.9, 0.24.1, 1.15.3 | From PyPI, pinned to the versions of the 23 Oct 2026 image |
| pplacer | v1.1.alpha19 | Used by the `tree` step |
| HMMER, Prodigal | Ubuntu 22.04 packages | |
| CheckM database | release 2015-01-16 | In `/data/checkm_db`, registered with `checkm data setRoot` |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** genomes or bins in FASTA format, one file per genome, all in one folder. Use `-x` to set the file extension, for example `-x fasta`.
* **Database:** included in the image at `/data/checkm_db`.
* **Storage:** don't mount your data on `/data`: it hides the database inside the image. Mount it on `/data/work` instead.
* **Resources:** `taxonomy_wf` needs little memory. The `tree` step runs pplacer, which needs about **40 GB** of RAM with the full tree, or about **14 GB** with `--reduced_tree`.

## Usage

From the `data` folder of this repo, which contains `data_fasta`, mount the current folder on `/data/work`:

```shell
docker run --rm --mount src="$(pwd)",target=/data/work,type=bind \
  genomixcloud/checkm checkm taxonomy_wf life Prokaryote \
  /data/work/data_fasta -x fasta /data/work/data_out
```

For a lineage-specific analysis, run these CheckM commands the same way, in this order:

1. `checkm tree /data/work/data_fasta/ -x fasta /data/work/data_out --reduced_tree --threads 8`
2. `checkm tree_qa -o 2 /data/work/data_out`
3. `checkm gc_plot /data/work/data_out/bins /data/work/data_out/plots 95`

Useful options:

| Option | Meaning |
|--------|---------|
| `-x <ext>` | Extension of the genome files in the input folder |
| `-t`, `--threads <n>` | Number of CPUs |
| `--reduced_tree` | Use the smaller tree in the `tree` step: about 14 GB of RAM instead of 40 GB |
| `-f <file> --tab_table` | Save the results table to a tab-separated file |

## Outputs

* A table, printed on screen, with for each genome the marker lineage, the number of marker genes found, and the **Completeness**, **Contamination** and **Strain heterogeneity**. To save it to a file, add `-f /data/work/data_out/results.tsv --tab_table`.
* The output folder, with the intermediate files (`bins/`, `storage/`) and `checkm.log`.
* With `gc_plot`: plots of GC content, coding density and coding strand in `plots/`.

## Database setup

No setup is needed: the database is downloaded when the image is built and registered with `checkm data setRoot`.

To use another copy of the database, download it from the [CheckM databases](https://data.ace.uq.edu.au/public/CheckM_databases/), mount it into the container (for example on `/checkm_db`) and run `checkm data setRoot /checkm_db` before your CheckM command, in the same container.

## Running on AWS

These are ideas for deploying CheckM on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, add the following code and rebuild the image:

   ```dockerfile
   RUN wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. In `/src/checkm.sh`, link the **data_in** and **data_out** folders to AWS S3. You can put the links and the CheckM parameters in `conf/checkm.ini`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     ${your_own_workspace}/checkm /src/checkm.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the CheckM image in AWS ECR. Give it enough memory for the `tree` step (see [Requirements](#requirements)).

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=checkm DOCKER_TAG=my_version
docker run --rm checkm:my_version \
  checkm taxonomy_wf species "Escherichia coli" /data/checkm_db/test_data/ /tmp/checkm_test_results
```

Or with Docker only:

```shell
cd tools/checkm
docker build --platform=linux/amd64 -t checkm:my_version .
```

The build downloads the CheckM database (about 1.4 GB uncompressed) into the image. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 22.04 image with CheckM (pip), pplacer, HMMER, Prodigal and the CheckM database |
| `src/checkm.sh` | Script, copied to `/src` in the image: runs `taxonomy_wf`, `tree`, `tree_qa` and `gc_plot` with the settings in `/conf/checkm.ini` (an environment variable with the same name overrides each one) |
| `test.sh` | Smoke test, run by `make test`: checks the CheckM version and runs the test genome of the database |
| `conf/checkm.ini` | Configuration, copied to `/conf` in the image: one `KEY=VALUE` line per setting, for the input and output folders |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| CheckM can't find its database | You mounted your data on `/data` and hid `/data/checkm_db`. Mount it on `/data/work` |
| The `tree` step is killed | pplacer ran out of memory. Give Docker more memory or add `--reduced_tree` |
| No genomes found | Set `-x` to the extension of your files (`fasta`, `fa`, `fna`) |

No known issues in the image at the moment.

## Citation

If you use this image, please cite CheckM:

> Parks, D. H., Imelfort, M., Skennerton, C. T., Hugenholtz, P., & Tyson, G. W. (2015). CheckM: assessing the quality of microbial genomes recovered from isolates, single cells, and metagenomes. *Genome Research*, 25(7), 1043–1055. https://doi.org/10.1101/gr.186072.114

## Licence and references

* CheckM is distributed under its own licence: [CheckM licence](https://github.com/Ecogenomics/CheckM/blob/master/LICENSE). This image only packages it.
* [CheckM software](https://github.com/Ecogenomics/CheckM)
* [CheckM manual](https://ecogenomics.github.io/CheckM/)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
