# FimTyper

<!-- short: FimTyper: FimH typing of Escherichia coli genomes. Database and test genome included. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [FimTyper](https://bitbucket.org/genomicepidemiology/fimtyper/) for the FimH typing of *Escherichia coli* genomes. The FimTyper database and a test genome are included in the image. This is an **alpha** image. It runs standalone on your computer or as a job in the AWS ecosystem. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | FimTyper | Other tools in the image |
|-----|----------|--------------------------|
| `latest` | commit `311023b` (10 Mar 2022) | Ubuntu 20.04, fimtyper_db commit `820782c` (27 Jul 2023), BLAST+ 2.9.0, Perl 5.30 |
| `v.1.1` | | Earlier build, from November 2023 |

FimTyper has no releases, so the image pins the commits of the code and of the database: every build has the same alleles.

## Quick start

```shell
# 1. Pull the image and check the installation (prints the FimTyper options)
docker pull genomixcloud/fimtyper
docker run --rm genomixcloud/fimtyper perl /usr/local/fimtyper/fimtyper.pl -h

# 2. Type the test genome inside the image, writing the results to ./data_out
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/fimtyper perl /usr/local/fimtyper/fimtyper.pl \
  -d /usr/local/fimtyper/fimtyper_db \
  -i /usr/local/fimtyper/test.fsa -o /data/data_out -k 95.00 -l 0.60

# 3. Type your own genome: run from the folder that contains it
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/fimtyper perl /usr/local/fimtyper/fimtyper.pl \
  -d /usr/local/fimtyper/fimtyper_db \
  -i /data/data_file.fsa -o /data/data_out -k 95.00 -l 0.60
```

`results_tab.txt` in the output folder has the FimH type found (FimH1 for the test genome); `results.txt`, `Hit_in_genome_seq.fsa` and `Fimtype_seq.fsa` have the details and the sequences of the best hit.

| Option | Meaning |
|--------|---------|
| `-d` | Database folder |
| `-i` | Input genome in FASTA format |
| `-o` | Output folder. Without it, FimTyper writes to a folder named `Output` inside the container, which is lost when the container stops |
| `-k` | Threshold for % identity, for example `95.00` for 95% |
| `-l` | Minimum length of the overlap, for example `0.60` for 60% |

More options: [FimTyper usage](https://bitbucket.org/genomicepidemiology/fimtyper/src/master/README.md#usage).

## Requirements

* **Input:** preassembled partial or complete *E. coli* genomes in FASTA format.
* **Database:** none to download: the FimTyper database is inside the image at `/usr/local/fimtyper/fimtyper_db`.
* **Resources:** light.

## Documentation

Full documentation, options and outputs: [tools/fimtyper on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/fimtyper).

* [Running FimTyper on AWS](https://github.com/genomixcloud/bioinformatic/tree/main/tools/fimtyper#running-on-aws)
* [How to build the FimTyper image](https://github.com/genomixcloud/bioinformatic/tree/main/tools/fimtyper#build-and-test)
* [Notes about the scripts in this image](https://github.com/genomixcloud/bioinformatic/blob/main/tools/fimtyper/Note.md)

## Licence

FimTyper is distributed under the [Apache License, Version 2.0](https://bitbucket.org/genomicepidemiology/fimtyper/src/master/README.md#license). The image only packages it.

If you use FimTyper, please cite: Roer, L., et al. (2017). Development of a web tool for *Escherichia coli* subtyping based on *fimH* alleles. *Journal of Clinical Microbiology*, 55(8), 2538–2543. https://doi.org/10.1128/JCM.00737-17

## What is Genomix Cloud?

[Genomix Cloud](https://genomixcloud.com/) is a platform designed to provide researchers, biologists, geneticists, and other professionals in the field of genomics with a powerful suite of bioinformatics tools in the Cloud to analyze and interpret genomic data.
