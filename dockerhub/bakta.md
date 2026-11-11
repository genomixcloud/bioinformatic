# Bakta

<!-- short: Bakta 1.11.4: rapid and standardized annotation of bacterial genomes and plasmids. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [Bakta](https://github.com/oschwengers/bakta) 1.11.4 for the rapid and standardized annotation of bacterial genomes, metagenome-assembled genomes (MAGs) and plasmids. Its GFF3 output is ready for pan-genome analysis with [genomixcloud/roary](https://hub.docker.com/r/genomixcloud/roary). It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | Bakta | Other tools in the image |
|-----|-------|--------------------------|
| `latest` | 1.11.4 | Ubuntu 20.04, conda environment `bakta_env` with Python 3.10 and pyhmmer 0.11.3. In this build: AMRFinderPlus 4.2.7, DIAMOND 2.2.8, BLAST+ 2.17.0, INFERNAL 1.1.5, tRNAscan-SE 2.0.13, ARAGORN 1.2.41, PILER-CR 1.06, pyrodigal 3.7.1 |
| `v1.8.2` | 1.8.2 | Earlier build, from November 2023 |

Bakta, pyhmmer and Python are pinned; the other dependencies (AMRFinderPlus has only a minimum version) are resolved by conda when the image is built, so another build of the same tag can have newer versions of them. If you need exactly the same image for a study, pull it by its digest and record it.

## Quick start

This example uses the Bakta **light database** (a few GB) so you can try the image quickly. For real analyses use the full database (see below).

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/bakta
docker run --rm genomixcloud/bakta /src/bakta.sh --version

# 2. Download the light database into the current folder (creates ./db-light)
docker run --rm --mount src="$(pwd)",target=/data,type=bind genomixcloud/bakta \
  /bin/bash -c "source activate bakta_env && bakta_db download --output /data --type light"

# 3. Download a small test genome (if you don't have your own)
curl -o contig.fasta.gz https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz
gunzip contig.fasta.gz

# 4. Annotate it: Bakta creates data_out, so don't create it first
docker run --rm --mount src="$(pwd)",target=/data,type=bind genomixcloud/bakta \
  /src/bakta.sh --db /data/db-light --threads 16 contig.fasta --output data_out
```

On Linux you can download the test genome with `wget` instead:

```shell
wget https://sra-download.ncbi.nlm.nih.gov/traces/wgs03/wgs_aux/AG/QU/AGQU01/AGQU01.1.fsa_nt.gz -O contig.fasta.gz
gunzip contig.fasta.gz
```

* If `data_out` already exists, Bakta stops with `ERROR: output path (...) already exists!`. Add `--force` to write into it.
* Bakta writes its results with the input file name as prefix: `.gff3` (the input of Roary), `.gbff`, `.embl`, `.tsv`, `.fna`, `.ffn`, `.faa`, `.json`, `.txt`, a circular genome plot (`.png` / `.svg`) and `.log`.

### The full database

The full database is more than 30 GB compressed (**about 64 GB uncompressed**), so download it to external storage. Move to your external storage and run:

```shell
docker run --rm -ti --mount src="$(pwd)",target=/data,type=bind genomixcloud/bakta bash
# Inside the container /data is the working folder, but you can give any path of your external storage
bakta_db download --output /data --type full
```

The database is downloaded to the `db` folder inside the output folder. Mount it on `/db` and pass `--db /db` when you run Bakta. More options: [Bakta database download](https://github.com/oschwengers/bakta/blob/main/README.md#database-download).

## Requirements

* **Input:** genome assemblies (contigs) in FASTA format.
* **Database (mandatory, not included):** light (a few GB) for testing, full (about 64 GB) for real analyses. Keep it in external storage, or on AWS EFS, and mount it into the container.
* **Resources:** annotation is CPU intensive. Set the number of CPUs with `--threads`.

## Documentation

Full documentation, options, outputs and benchmarks: [tools/bakta on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/bakta).

* [Running Bakta on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/bakta#running-on-aws)
* [How to build the Bakta image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/bakta#build-and-test)
* [Preparing Bakta GFF3 files for Roary](https://github.com/genomixcloud/bioinformatic/tree/main#helper-scripts)

## Licence

Bakta is distributed under the [GPL v3 licence](https://github.com/oschwengers/bakta/blob/main/LICENSE). AMRFinderPlus and the other tools have their own licences. The image only packages them.

If you use Bakta, please cite: Schwengers, O., Jelonek, L., Dieckmann, M. A., Beyvers, S., Blom, J., & Goesmann, A. (2021). Bakta: rapid and standardized annotation of bacterial genomes via alignment-free sequence identification. *Microbial Genomics*, 7(11). https://doi.org/10.1099/mgen.0.000685

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
