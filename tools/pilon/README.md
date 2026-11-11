# Pilon Docker image

A ready-to-run Linux Docker image of [Pilon](https://github.com/broadinstitute/pilon), with bwa-mem2 and samtools, for polishing and improving genome assemblies with sequencing reads.

| | |
|---|---|
| **Image** | [`genomixcloud/pilon`](https://hub.docker.com/r/genomixcloud/pilon) |
| **Tool version** | Pilon 1.24, bwa-mem2 2.2.1, samtools 1.9 |
| **Platform** | `linux/amd64` |
| **Database** | None: Pilon uses your own assembly as the reference |
| **Input → output** | Assembly (FASTA) and paired-end reads (FASTQ) → polished assembly (FASTA) |
| **Pipeline step** | After assembly ([SPAdes](../spades)) and before quality assessment ([QUAST](../quast), [CheckM](../checkm)) and annotation ([Bakta](../bakta), [Prokka](../prokka)) |

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
# Pull the image and check the versions
docker pull genomixcloud/pilon
docker run --rm genomixcloud/pilon pilon --help
docker run --rm genomixcloud/pilon bwa-mem2 version
docker run --rm genomixcloud/pilon samtools --help
```

Pilon needs the reads aligned to the assembly first, so the example with the test data in this repo runs in 6 steps: see [Usage](#usage).

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 22.04 | |
| Pilon | 1.24 | Java JAR from the GitHub release, with a `pilon` launcher in `/usr/src/pilon` |
| bwa-mem2 | 2.2.1 | Prebuilt binary from the GitHub release |
| samtools | 1.9 | Built from source |
| Java | OpenJDK 8 (headless) | |

## Requirements

* **Docker** (version 24 or later to build the image).
* **Input:** the assembly (contigs) in FASTA format, and paired-end reads in FASTQ format. Pilon itself reads one or more BAM files of reads aligned to the assembly; the image includes bwa-mem2 and samtools to make them.
* **Database:** none.
* **Resources:** Pilon runs on Java and can use a lot of memory on large genomes, so give Docker enough memory. Use `-t`, `--threads` or `-@` to set the number of CPUs of each step.

## Usage

1. Move to the `data` folder of this repo, which contains the trimmed sample reads and the FASTA file.
2. Create the output folder (`data_out` in this example). The tools don't create it.

```md
data
├── data_fasta
│   └── contigs.fasta
├── data_out
└── data_in_trimmed
    ├── trimmed_reads_1.fastq.gz
    └── trimmed_reads_2.fastq.gz
```

3. Run these commands in order:

**Step 1.** Index the assembly. The index files are written next to `contigs.fasta`:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon bwa-mem2 index /data/data_fasta/contigs.fasta
```

**Step 2.** Align the reads to the assembly:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon bwa-mem2 mem -t 4 -P -S -Y -M \
  -o /data/data_out/sample.sam \
  /data/data_fasta/contigs.fasta \
  /data/data_in_trimmed/trimmed_reads_1.fastq.gz /data/data_in_trimmed/trimmed_reads_2.fastq.gz
```

**Step 3.** Convert the alignment to BAM:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon samtools view -Sb /data/data_out/sample.sam \
  -o /data/data_out/sample.bam -@ 8
```

**Step 4.** Sort it:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon samtools sort /data/data_out/sample.bam \
  -o /data/data_out/sample.sort.bam
```

**Step 5.** Index it:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon samtools index /data/data_out/sample.sort.bam
```

**Step 6.** Polish the assembly:

```shell
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/pilon pilon --genome /data/data_fasta/contigs.fasta \
  --bam /data/data_out/sample.sort.bam \
  --outdir /data/data_out/ --output assembly.polish --threads 8 --minqual 30 --nostrays
```

Useful Pilon options:

| Option | Meaning |
|--------|---------|
| `--genome <file>` | Assembly to polish |
| `--bam <file>` | Sorted and indexed BAM of reads aligned to the assembly. `--frags` marks it as paired-end |
| `--outdir`, `--output` | Output folder and prefix of the output files |
| `--threads <n>` | Number of CPUs |
| `--minqual <n>` | Minimum base quality to use |
| `--nostrays` | Skip the analysis of stray read pairs. Faster |
| `--changes` | Also write a file listing every change Pilon made |
| `--fix <list>` | What to fix: `snps`, `indels`, `gaps`, `local`, `all`. Default: `all` |

## Outputs

| File | Content |
|------|---------|
| `sample.sam`, `sample.bam`, `sample.sort.bam`, `sample.sort.bam.bai` | The read alignment, from steps 2 to 5 |
| `assembly.polish.fasta` | The polished assembly |
| `assembly.polish.changes` | Every change Pilon made (with `--changes`) |

## Database setup

Pilon doesn't need a database.

## Running on AWS

These are ideas for deploying Pilon on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. Add the AWS CLI to the image: in the Dockerfile, under the comment **# install awscli**, add the following code and rebuild the image:

   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
       wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
       unzip -d /usr/src/ /usr/src/awscli-exe-linux-x86_64.zip && \
       rm /usr/src/awscli-exe-linux-x86_64.zip && \
       /usr/src/aws/install
   ```

2. In `/src/pilon.sh`, link the **in** and **out** folders to AWS S3. The script already runs bwa-mem2, samtools and Pilon in the order above. You can put the links and the parameters in `conf/pilon.ini`.
3. Test it locally with your AWS credentials:

   ```shell
   docker run --rm \
     -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
     -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
     --mount src="$(pwd)",target=/data,type=bind \
     ${your_own_workspace}/pilon /src/pilon.sh
   ```

4. Push the image to your AWS account (**AWS ECR**).
5. Create an AWS Batch job that points to the Pilon image in AWS ECR.

For more about running the tools on AWS, see the [AWS guide](../../aws).

## Build and test

For contributors and developers. From the root of the repository:

```shell
make build DOCKER_IMAGE=pilon DOCKER_TAG=my_version
docker run --rm pilon:my_version pilon --help
docker run --rm pilon:my_version bwa-mem2 version
docker run --rm pilon:my_version samtools --help
```

Or with Docker only:

```shell
cd tools/pilon
docker build --platform=linux/amd64 -t pilon:my_version .
```

Then run the steps in [Usage](#usage) with your `my_version` tag. `make push` and `make build-all` publish the image to Docker Hub; see the [root README](../../README.md#building-and-publishing-with-make).

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 22.04 image with Java 8, Pilon, bwa-mem2 and samtools (built from source) |
| `test.sh` | Smoke test, run by `make test`: checks the Pilon, bwa-mem2 and samtools versions |
| `src/pilon.sh` | Script, copied to `/src` in the image: runs bwa-mem2, samtools and Pilon with the settings in `/conf/pilon.ini` (an environment variable with the same name overrides each one) |
| `conf/pilon.ini` | Configuration, copied to `/conf` in the image: one `KEY=VALUE` line per setting, for the assembly, reads and output folder |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| `bash pilon` in old scripts | Still works. Images built before 11 Nov 2026 need it, because their launcher has no `#!/bin/bash` line |
| `Please verify that both the operating system and the processor support Intel(R) CLWB instructions` from bwa-mem2 | The CPU check of bwa-mem2 fails under emulation, for example Docker on Apple silicon. On x86 machines and AWS it works. Locally you can call `/usr/src/bwa/bwa-mem2.sse41` directly |
| Pilon is killed or Java reports `OutOfMemoryError` | Give Docker more memory. Large genomes need several GB |
| `samtools` or `pilon` can't find the BAM index | Run steps 4 and 5: Pilon needs a sorted and indexed BAM |

Known issues in the image, not fixed yet:

* The Broad Institute no longer develops Pilon. 1.24 is its last release.

## Citation

If you use this image, please cite Pilon, and bwa-mem2 and samtools for the alignment:

> Walker, B. J., Abeel, T., Shea, T., Priest, M., Abouelliel, A., Sakthikumar, S., Cuomo, C. A., Zeng, Q., Wortman, J., Young, S. K., & Earl, A. M. (2014). Pilon: an integrated tool for comprehensive microbial variant detection and genome assembly improvement. *PLoS ONE*, 9(11), e112963. https://doi.org/10.1371/journal.pone.0112963

> Vasimuddin, Md., Misra, S., Li, H., & Aluru, S. (2019). Efficient architecture-aware acceleration of BWA-MEM for multicore systems. *2019 IEEE International Parallel and Distributed Processing Symposium (IPDPS)*. https://doi.org/10.1109/IPDPS.2019.00041

> Danecek, P., Bonfield, J. K., Liddle, J., Marshall, J., Ohan, V., Pollard, M. O., Whitwham, A., Keane, T., McCarthy, S. A., Davies, R. M., & Li, H. (2021). Twelve years of SAMtools and BCFtools. *GigaScience*, 10(2), giab008. https://doi.org/10.1093/gigascience/giab008

## Licence and references

* Pilon is distributed under its own licence: [Pilon licence](https://github.com/broadinstitute/pilon/blob/master/LICENSE). bwa-mem2 and samtools have their own licences. This image only packages them.
* [Pilon software](https://github.com/broadinstitute/pilon)
* [Pilon manual](https://github.com/broadinstitute/pilon/wiki)
* [bwa-mem2](https://github.com/bwa-mem2/bwa-mem2), [samtools](https://github.com/samtools/samtools)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
