# Roary

<!-- short: Roary 3.13.0 pan-genome analysis, with FastTree 2.2.0 and roary2svg. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [Roary](https://github.com/sanger-pathogens/Roary/) 3.13.0 for the pan-genome analysis of prokaryotic genomes, with FastTree for the core-genome tree and roary2svg for the gene presence and absence picture. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | Roary | Other tools in the image |
|-----|-------|--------------------------|
| `latest` | 3.13.0 | Ubuntu 20.04, FastTree 2.2.0, roary2svg.pl (Roary v3.13.0, with perl-svg 2.87), BLAST+ 2.16.0, MAFFT 7.526, PRANK 251117, CD-HIT 4.8.1, MCL 22.282, bedtools 2.31.1, Perl 5.32.1, ImageMagick 6.9.10, AWS CLI v2 |
| `3.13.0` | 3.13.0 | Earlier build, from April 2024 |

The conda environment is installed from an exact lock file, so every build of a tag contains the same package versions. It includes the SVG Perl module that `roary2svg.pl` needs: builds from late October 2026, before the lock, missed it.

## Quick start

```shell
# 1. Pull the image and check the installation
docker pull genomixcloud/roary
docker run --rm genomixcloud/roary /src/roary.sh -w

# 2. Download 3 test genomes annotated with Prokka (if you don't have your own)
mkdir -p data/data_gff_prokka && cd data/data_gff_prokka
curl -O https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_gff_prokka/PROKKA_v1.gff
curl -O https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_gff_prokka/PROKKA_v2.gff
curl -O https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_gff_prokka/PROKKA_v3.gff

# 3. Pan-genome and core gene alignment: run from the folder with the GFF files
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/roary /src/roary.sh -e --mafft -p 8 -f pangenome *.gff

# 4. Core-genome tree
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/roary /src/fasttree.sh -nt -gtr pangenome/core_gene_alignment.aln > pangenome/core_gene_alignment.newick

# 5. Gene presence and absence picture
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/roary /src/roary2svg.sh pangenome/gene_presence_absence.csv --colour=Blue > pangenome/pangenome.svg
```

On Linux you can download the test genomes with `wget` instead:

```shell
wget https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_gff_prokka/PROKKA_v1.gff
wget https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_gff_prokka/PROKKA_v2.gff
wget https://raw.githubusercontent.com/genomixcloud/bioinformatic/main/data/data_gff_prokka/PROKKA_v3.gff
```

The files are for testing only. The folder layout:

```md
data
└── data_gff_prokka
    ├── PROKKA_v1.gff
    ├── PROKKA_v2.gff
    └── PROKKA_v3.gff
```

* Don't use `-t` (`-ti`) in steps 4 and 5, where the output is redirected to a file: it mixes log messages into the results.
* If `pangenome` already exists, Roary writes to a new folder with another name, so remove it before running step 3 again.
* Roary writes the pan-genome to `pangenome`: `summary_statistics.txt`, `gene_presence_absence.csv` / `.Rtab`, `core_gene_alignment.aln` (with `-e`) and `pan_genome_reference.fa`.
* **GFF3 files from Bakta** need preparation before Roary: unique contig names and gene names that don't collide. See [Input from Bakta](https://github.com/genomixcloud/bioinformatic/tree/main/tools/roary#input-from-bakta).

## Requirements

* **Input:** at least 2 annotated genomes in GFF3 format (Prokka or Bakta), with the sequences at the end of each file.
* **Database:** none.
* **Resources:** set the CPUs with `-p`. FastTree needs about the core alignment length × 4 KB of memory: about 7 GB for a 1.9 Mbp core alignment and 23 GB for 5.3 Mbp. If it runs out of memory, `core_gene_alignment.newick` is left empty.

## Documentation

Full documentation, expected outputs, memory limits and build instructions: [tools/roary on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/roary).

* [Running Roary on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/roary#running-on-aws)
* [Limits and memory](https://github.com/genomixcloud/bioinformatic/tree/main/tools/roary#limits-and-memory)
* [How to build the Roary image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/roary#build-and-test)

## Licence

Roary is distributed under the [GPL v3 licence](https://github.com/sanger-pathogens/Roary/blob/master/GPL-LICENSE). FastTree and the other tools have their own licences. The image only packages them.

If you use this image, please cite Roary, and FastTree for the tree: Page, A. J., et al. (2015). Roary: rapid large-scale prokaryote pan genome analysis. *Bioinformatics*, 31(22), 3691–3693. https://doi.org/10.1093/bioinformatics/btv421, and Price, M. N., Dehal, P. S., & Arkin, A. P. (2010). FastTree 2 – approximately maximum-likelihood trees for large alignments. *PLoS ONE*, 5(3), e9490. https://doi.org/10.1371/journal.pone.0009490

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
