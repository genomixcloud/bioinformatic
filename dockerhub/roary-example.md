# Roary

<!-- short: Roary 3.13.0 pan-genome analysis, with FastTree 2.2.0 and roary2svg. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [Roary](https://github.com/sanger-pathogens/Roary/) 3.13.0 for the pan-genome analysis of prokaryotic genomes, with FastTree for the core-genome tree and roary2svg for the gene presence and absence picture. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | Roary | Other tools in the image |
|-----|-------|--------------------------|
| `latest` | 3.13.0 | FastTree 2.2.0, roary2svg.pl (Roary v3.13.0), BLAST+ 2.16.0, MAFFT 7.526, PRANK 251117, CD-HIT 4.8.1, MCL 22.282, Perl 5.32.1, ImageMagick 6.9.10 |

The conda environment is installed from an exact lock file, so every build of a tag contains the same package versions.

## Quick start

```shell
docker pull genomixcloud/roary
docker run --rm genomixcloud/roary /src/roary.sh -w

# In a folder with your GFF3 files:
# 1. Pan-genome and core gene alignment
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/roary /src/roary.sh -e --mafft -p 8 -f pangenome *.gff

# 2. Core-genome tree
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/roary /src/fasttree.sh -nt -gtr pangenome/core_gene_alignment.aln > pangenome/core_gene_alignment.newick

# 3. Gene presence and absence picture
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/roary /src/roary2svg.sh pangenome/gene_presence_absence.csv --colour=Blue > pangenome/pangenome.svg
```

Don't use `-t` in steps 2 and 3, where the output is redirected to a file. If `pangenome` already exists, Roary writes to a new folder, so remove it before running step 1 again.

## Requirements

* **Input:** at least 2 annotated genomes in GFF3 format (Prokka or Bakta), with the sequences at the end of each file.
* **Database:** none.
* **Resources:** set the CPUs with `-p`. FastTree needs about the core alignment length x 4 KB of memory: about 7 GB for a 1.9 Mbp core alignment and 23 GB for 5.3 Mbp.

## Documentation

Full documentation, expected outputs, memory limits and build instructions: [tools/roary on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/roary).

## Licence

Roary is distributed under the [GPL-3.0 licence](https://github.com/sanger-pathogens/Roary/blob/master/GPL-LICENSE). FastTree and the other tools keep their own licences. The image only packages them.
