# Platon

<!-- short: Platon 1.7: identification of plasmid contigs in bacterial assemblies. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [Platon](https://github.com/oschwengers/platon) 1.7 for the identification and characterization of plasmid contigs in bacterial genome assemblies. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | Platon | Other tools in the image |
|-----|--------|--------------------------|
| `latest` | 1.7 | Ubuntu 20.04, Miniconda. In this build: DIAMOND 2.2.8, BLAST+ 2.17.0, HMMER 3.4, INFERNAL 1.1.5, MUMmer 4.0.1, Prodigal 2.6.3, Python 3.14 |
| `1.7` | 1.7 | Earlier build, from April 2024 |

Only Platon is pinned: its dependencies are resolved by conda when the image is built, so another build of the same tag can have newer versions of them. If you need exactly the same image for a study, pull it by its digest and record it.

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/platon
docker run --rm genomixcloud/platon platon --version

# 2. Download the Platon database (mandatory) and test contigs
mkdir -p data/data_fasta data/data_out && cd data
curl -L -o db.tar.gz https://zenodo.org/record/4066768/files/db.tar.gz
tar -xzf db.tar.gz && rm db.tar.gz && mv db platon_db
curl -o data_fasta/contigs.fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta

# 3. Classify the contigs: run from the data folder
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/platon platon \
  --mode sensitivity --threads 8 --db /data/platon_db \
  /data/data_fasta/contigs.fasta -o /data/data_out
```

On Linux you can download the data with `wget` instead:

```shell
wget https://zenodo.org/record/4066768/files/db.tar.gz
wget -P data_fasta https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_fasta/contigs.fasta
```

The contigs are for testing only. The folder layout:

```md
data
├── data_fasta
│   └── contigs.fasta
├── data_out
└── platon_db
```

* More about the database: [Platon database download](https://github.com/oschwengers/platon?tab=readme-ov-file#database-download).
* `--mode` can be `sensitivity`, `accuracy` (default) or `specificity`.
* Platon writes to the output folder, with the input file name as prefix: `.tsv` (summary of the plasmid contigs), `.plasmid.fasta`, `.chromosome.fasta`, `.json` and `.log`.
* **Memory:** with 16 GB of RAM Platon failed with `diamond execution failed! diamond-error-code=-11`; it ran with **24 GB**. Give Docker at least 24 GB.

## Requirements

* **Input:** genome assemblies (contigs) in FASTA format.
* **Database (mandatory, not included):** download it from Zenodo (see above). Keep it in external storage, or on AWS EFS, and mount it into the container.
* **Resources:** at least 24 GB of memory. Set the CPUs with `--threads`.

## Documentation

Full documentation, options and outputs: [tools/platon on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/platon).

* [Running Platon on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/platon#running-on-aws)
* [How to build the Platon image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/platon#build-and-test)

## Licence

Platon is distributed under the [GPL v3 licence](https://github.com/oschwengers/platon/blob/main/LICENSE). The image only packages it.

If you use Platon, please cite: Schwengers, O., et al. (2020). Platon: identification and characterization of bacterial plasmid contigs in short-read draft assemblies exploiting protein sequence-based replicon distribution scores. *Microbial Genomics*, 6(10). https://doi.org/10.1099/mgen.0.000398

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
