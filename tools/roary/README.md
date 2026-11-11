# Roary Docker image

A ready-to-run Linux Docker image of [Roary](https://github.com/sanger-pathogens/Roary/), with FastTree and roary2svg, for the pan-genome analysis of prokaryotic genomes.

| | |
|---|---|
| **Image** | [`genomixcloud/roary`](https://hub.docker.com/r/genomixcloud/roary) |
| **Tool version** | Roary 3.13.0, FastTree 2.2.0, roary2svg.pl (Roary v3.13.0) |
| **Platform** | `linux/amd64` |
| **Database** | None |
| **Input → output** | Annotated genomes (GFF3) → pan-genome, core gene alignment, core-genome tree, presence/absence picture |
| **Pipeline step** | After annotation ([Bakta](../bakta) or [Prokka](../prokka)). Last step of the pipeline |

## Contents

* [Quick start](#quick-start)
* [Image contents](#image-contents)
* [Requirements](#requirements)
* [Usage](#usage)
* [Outputs](#outputs)
* [Input from Bakta](#input-from-bakta)
* [Database setup](#database-setup)
* [Running on AWS](#running-on-aws)
* [Build and test](#build-and-test)
* [Troubleshooting](#troubleshooting)
* [Citation](#citation)
* [Licence and references](#licence-and-references)

## Quick start

```shell
# 1. Pull the image and check the version
docker pull genomixcloud/roary
docker run --name roary --rm -ti genomixcloud/roary /src/roary.sh -w

# 2. Build the pan-genome of the 3 test genomes in the data folder of this repo
cd data/data_gff_prokka
docker run --name roary --rm -ti \
--mount src="$(pwd)",target=/data,type=bind \
genomixcloud/roary /src/roary.sh -e --mafft -p 8 -f pangenome *.gff
```

## Image contents

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | Ubuntu 20.04 | |
| Roary | 3.13.0 | From bioconda |
| FastTree | 2.2.0 | Called as `FastTree` or `fasttree` |
| roary2svg.pl | Roary v3.13.0 | In `/usr/bin/roary2svg.pl`. Needs the Perl module SVG (perl-svg 2.87) |
| BLAST+, MAFFT, PRANK, CD-HIT, MCL, bedtools | 2.16.0, 7.526, 251117, 4.8.1, 22.282, 2.31.1 | Called by Roary |
| Perl | 5.32.1 | |
| ImageMagick (`convert`) | 6.9.10 (Ubuntu 20.04) | Turns `pangenome.svg` into a PNG |
| AWS CLI | v2, latest at build time | |
| Conda environment | `roary_env` | Installed from the exact lock `roary_env.lock.txt` (410 packages, see [Reproducible builds](#reproducible-builds)) |

## Requirements

* **Docker**
* **Reference database:** none.
* **Input format:** at least 2 annotated genomes in GFF3 format, as produced by [Prokka](../prokka), with the sequences included at the end of each file.
* **Resources:** use `-p` to set the number of CPUs. Memory and run time grow with the number of genomes and the length of the core gene alignment. On the platform a job takes **at most 150 genomes** and runs with **45 GiB** of memory (see [Limits and memory](#limits-and-memory)).

## Usage

1. Move to the `data/data_gff_prokka` folder of this repo, which contains the GFF files (see the tree below).

```md
data
└── data_gff_prokka
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

## Outputs

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

## Input from Bakta

GFF3 files from [Bakta](../bakta) need two preparation steps before Roary: unique contig names, and gene names that don't collide.

### Contig names

Bakta names the contigs `contig_1`, `contig_2`, ... in every sample, and writes a `##feature-ontology` header line that Roary's GFF parser doesn't accept. [scripts/rename_contigs.sh](../../scripts/rename_contigs.sh) fixes both: it prefixes the contigs with the sample name and removes the header line. See [Helper scripts](../../README.md#helper-scripts) in the root README.

### Gene names from Bakta

Without this step the core gene alignment, and the tree built from it, can be wrong. Without it the core gene alignment, and the tree built from it, can be wrong.

**The problem.** When a gene has no gene symbol, Bakta puts the product description in `Name=`, and Roary uses it as the gene name. When Roary writes the core gene alignment, it replaces every character that isn't a letter, digit or `_` with `_`. Two different names can then end up the same, for example:

| Bakta name | Name in the alignment |
|------------|-----------------------|
| `Serine/threonine-protein kinase` | `Serine_threonine_protein_kinase` |
| `Serine/threonine protein kinase` | `Serine_threonine_protein_kinase` |
| `Amino acid ABC transporter ATP-binding protein` | `Amino_acid_ABC_transporter_ATP_binding_protein` |
| `Amino acid ABC transporter ATP binding protein` | `Amino_acid_ABC_transporter_ATP_binding_protein` |

When two genes share a name in the alignment, Roary writes one of them twice and drops the other. Which gene is kept can change from genome to genome and from run to run. If a block mixes different genes across genomes, it adds false variable sites and makes branches of the tree too long.

Measured with 5 genomes annotated with Bakta and run twice through Roary 3.13.0:

| | Run 1 | Run 2 |
|---|---|---|
| Clusters (same genes in each) | 6,236 | 6,236 |
| Core genes | 5,424 | 5,424 |
| Core blocks with identical sequences in both runs | 5,422 | 5,422 |
| Kinase block | 2 copies of one gene, but WGAOA2 has a different gene in both copies | 2 copies of one gene, the same in every genome |
| Variable sites in the core alignment | 23,657 | 22,777 |
| WGAOA2 branch length in the tree | 0.000215 | 0.0000073 |

The kinase block alone added 878 false variable sites to run 1 and made the WGAOA2 branch about 30 times longer. Run 2 was right by chance only.

Other differences between the two runs are harmless. When two clusters have exactly the same name, Roary keeps it for one cluster and names the other `group_N`, picking at random. Roary also shuffles the genome order for the `number_of_*.Rtab` curves.

**The fix.** Before running Roary, apply Roary's rule to the names in the GFF files. Names that would collide then become exactly the same, and Roary handles that case on its own: one cluster keeps the name and the other becomes `group_N`. Roary itself stays unchanged.

Save this script as `sanitize_gff_names.py`:

```python
# Usage: python3 sanitize_gff_names.py in.gff out.gff
# Applies Roary's name rule (any character other than a letter, digit or _
# becomes _) to the Name= and gene= attributes, so that names that would
# collide in the core alignment become identical before Roary runs.
import re
import sys


def fix(match):
    return match.group(1) + re.sub(r'\W', '_', match.group(2))


with open(sys.argv[1]) as fi, open(sys.argv[2], 'w') as fo:
    for line in fi:
        if line.startswith('##FASTA'):
            # copy the sequences at the end of the file unchanged
            fo.write(line)
            fo.writelines(fi)
            break
        cols = line.rstrip('\n').split('\t')
        if len(cols) == 9:
            cols[8] = re.sub(r'(\b(?:Name|gene)=)([^;]*)', fix, cols[8])
            line = '\t'.join(cols) + '\n'
        fo.write(line)
```

Run it on every GFF file, then run Roary on the new folder:

```shell
mkdir -p gff_sanitized
for f in *.gff; do python3 sanitize_gff_names.py "$f" gff_sanitized/"$f"; done
```

* Only `Name=` and `gene=` change. `product=` keeps the full description, so it still appears in the `Annotation` column of `gene_presence_absence.csv`.
* Gene names in the results show `_` instead of spaces and punctuation, for example `Serine_threonine_protein_kinase`.
* Names that differ only in upper or lower case, such as `Serine_...` and `serine_...`, stay different. That's fine on Linux, including AWS Batch. Roary writes one file per gene, though, and on macOS file names ignore case. If you run Docker on macOS with the data folder mounted from the Mac, two such genes can still collide. To avoid it, also make the names lower case: `re.sub(r'\W', '_', match.group(2)).lower()`.
* Check the result: no name in `core_alignment_header.embl` should cover sequences of different lengths in different genomes. Two runs on the same files should give the same number of variable sites and the same tree.

Other options considered:

* Making every name unique, for example by adding a suffix: the same gene must get the same new name in every genome, which is harder to get right.
* Removing `Name=` from genes without a gene symbol: it also works, but most clusters become `group_N` and the results are much harder to read.

This step isn't in the image or the pipeline yet, and it hasn't been tested with a new Roary run. It could become a step between Bakta and Roary, or the first command in `src/roary.sh`.

## Database setup

Roary doesn't need a database.

## Running on AWS

These are ideas for deploying Roary on AWS, not a tested step-by-step guide. Adapt them to your own AWS setup.

**Architecture:** input and output files live in **AWS S3**, the image is stored in **AWS ECR**, and **AWS Batch** runs the jobs. You also need AWS Networking and AWS IAM to connect them.

1. The image already includes the AWS CLI (see the `# install awscli` step in the Dockerfile).

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

### Limits and memory

| Limit | Value |
|-------|-------|
| Genomes per job | at most **150** |
| Job memory | **45 GiB** (`46080` MiB in the AWS Batch job definition) |
| Instance | m5.4xlarge (16 vCPU, 64 GiB) |

FastTree uses most of the memory, not Roary. Its memory depends mainly on the **length of the core gene alignment** (`core_gene_alignment.aln`), and less on the number of genomes:

```
memory ≈ 4 KB × alignment length (bp)   SH-like support values (1000 resamples)
       + genomes × alignment length     sequences and tree profiles (small for conserved alignments)
       + 2 GB                           base use
```

* The core alignment can't be much longer than the coding part of the smallest genome, so the first term has a ceiling. More genomes, or more diverse ones, make the core shorter.
* With 45 GiB the core alignment can be up to about **8 Mbp**. That covers most bacteria (for example *E. coli*, *Salmonella*, *Klebsiella*, *Staphylococcus*, *Pseudomonas*). Species with large genomes, such as *Streptomyces* or myxobacteria, can go over it.
* If FastTree runs out of memory, the job is killed after `Optimize all lengths` and `core_gene_alignment.newick` is left empty. Check this file after each job.

Measured on AWS Batch with 5 closely related genomes of about 6.4 Mbp:

| Core alignment | Variable sites | Memory | Result |
|----------------|----------------|--------|--------|
| 5,342,416 bp | 22,777 (0.43%) | 16 GiB | FastTree killed, empty tree |
| 5,342,416 bp | 22,777 (0.43%) | 32 GiB | Tree built |

The 150-genome limit is based on this formula. It hasn't been tested yet with a full 150-genome job.

## Build and test

For contributors and developers.

### Build

From the root of the repository (`bioinformatic/`):

```shell
make build DOCKER_IMAGE=roary DOCKER_TAG=my_version BUILD_ARG="--build-arg DEBIAN_FRONTEND=noninteractive"
```

Or directly with Docker:

```shell
cd tools/roary
docker build --platform=linux/amd64 --build-arg DEBIAN_FRONTEND=noninteractive -t roary:my_version .
```

`DEBIAN_FRONTEND=noninteractive` stops the build from asking for a timezone.

### Reproducible builds

The image is built from `roary_env.lock.txt`, the exact list of conda packages (URL and build of each one), not from `environment.yaml`. The Miniconda installer is pinned and checked with its SHA-256, there is no `conda update`, and `roary2svg.pl` comes from the `v3.13.0` tag. So a build today and a build next year get the same packages.

Before the lock, `environment.yaml` pinned only `roary=3.13.0` and conda resolved everything else again at each build. Two builds of the same Dockerfile two weeks apart (26 Oct and 10 Nov 2026) gave different images: Python went from 3.7 to 3.13, about 70 packages changed version and the image grew by 1.7 GB. The SVG Perl module that `roary2svg.pl` needs was missing in both, so `roary2svg.pl` failed. The lock is the 26 Oct environment plus `perl-svg` 2.87, with roary 3.13.0, FastTree 2.2.0 and blast 2.16.0.

### Update the conda lock

Only when you really want newer packages:

1. Edit `environment.yaml` (the spec: roary, FastTree, perl-svg and Python).
2. Create the environment in a throwaway container and export the lock:

   ```shell
   cd tools/roary
   docker run --rm --platform linux/amd64 -v "$PWD":/w roary:my_version /bin/bash -c \
     "conda env create -q -n new_env -f /w/environment.yaml && conda list -n new_env --explicit > /w/roary_env.lock.txt"
   ```

3. Rebuild, run the smoke test and compare the results with a reference run before you push.

### Test

`make test` runs the smoke test `tools/roary/test.sh`. It checks the roary and FastTree versions, builds a tree from a tiny alignment and checks that `roary2svg.pl` loads all its Perl modules. `make build-all` runs it between build and push, so an image that fails is never pushed.

```shell
make test DOCKER_IMAGE=roary DOCKER_TAG=my_version
```

You can also call the tools by hand:

```shell
docker run --name roary --rm -ti roary:my_version /src/roary.sh -w
docker run --name roary --rm -ti roary:my_version /src/roary.sh --help
docker run --name roary2svg --rm -ti roary:my_version /src/roary2svg.sh --help
docker run --name fasttree --rm -ti roary:my_version /src/fasttree.sh --help
```

Then run the steps in [Usage](#usage) with your `my_version` tag.

### Files in this folder

| File | Content |
|------|---------|
| `Dockerfile` | Ubuntu 20.04 image with a pinned Miniconda, the `roary_env` conda environment, roary2svg and the AWS CLI |
| `roary_env.lock.txt` | Exact conda package list the image is built from |
| `environment.yaml` | Spec of the environment (roary, FastTree, perl-svg, Python), used only to regenerate the lock |
| `test.sh` | Smoke test, run by `make test` |
| `src/roary.sh` | Script, copied to `/src` in the image: activates the conda environment and calls `roary` with the given arguments |
| `src/fasttree.sh` | Same for `fasttree` |
| `src/roary2svg.sh` | Same for `roary2svg.pl` |
| `conf/roary.ini` | Configuration, copied to `/conf` in the image, such as the input and output folders |

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| Roary writes to a folder with another name | The `pangenome` folder already existed. Remove it before running Roary again |
| The `.newick` or `.svg` file has log messages or Windows line endings | Don't use `-t` (`-ti`) in `docker run` when you redirect the output to a file |
| `core_gene_alignment.newick` is empty | FastTree ran out of memory. See [Limits and memory](#limits-and-memory) |
| `Can't locate SVG.pm in @INC` from roary2svg.pl | The image was built before the conda lock, without perl-svg. Use an image built from this Dockerfile (see [Reproducible builds](#reproducible-builds)) |
| `Error: You need to provide at least 2 files to build a pan genome` | Roary needs at least 2 GFF files |
| Roary fails to parse a Bakta GFF | Run [scripts/rename_contigs.sh](../../scripts/rename_contigs.sh) first (see [Input from Bakta](#input-from-bakta)) |
| Long tree branches or chimeric core blocks with Bakta input | Gene names collide. See [Gene names from Bakta](#gene-names-from-bakta) |

## Citation

If you use this image, please cite Roary, and FastTree for the core-genome tree:

> Page, A. J., Cummins, C. A., Hunt, M., Wong, V. K., Reuter, S., Holden, M. T. G., Fookes, M., Falush, D., Keane, J. A., & Parkhill, J. (2015). Roary: rapid large-scale prokaryote pan genome analysis. *Bioinformatics*, 31(22), 3691–3693. https://doi.org/10.1093/bioinformatics/btv421

> Price, M. N., Dehal, P. S., & Arkin, A. P. (2010). FastTree 2 – approximately maximum-likelihood trees for large alignments. *PLoS ONE*, 5(3), e9490. https://doi.org/10.1371/journal.pone.0009490

## Licence and references

* Roary is distributed under its own licence: [Roary licence](https://github.com/sanger-pathogens/Roary/blob/master/GPL-LICENSE). FastTree and the other tools have their own licences. This image only packages them.
* [Roary software](https://github.com/sanger-pathogens/Roary/)
* [Source data to generate Roary input data](https://github.com/microgenomics/tutorials/blob/master/pangenome.md)
* [FastTree](http://www.microbesonline.org/fasttree/)
* [Docker run command](https://docs.docker.com/engine/reference/commandline/run/)
