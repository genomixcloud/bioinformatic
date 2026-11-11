# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Added
- Integration with external payment gateway.

## - 2026-11-11
### Published images
All images were built from this repository, passed their smoke test (`make test`) and were pushed to Docker Hub as `genomixcloud/<tool>:latest`. Pull an exact image with `docker pull genomixcloud/<tool>@<digest>`.

| Image | Main tool | Base image | Digest |
|-------|-----------|------------|--------|
| `genomixcloud/abricate:latest` | ABRicate 1.0.1 | Ubuntu 22.04 | `sha256:ed97113e6934bc934e391a7c69d5bb055c13bf16779425edc8dc9e827e972db5` |
| `genomixcloud/bakta:latest` | Bakta 1.11.4 | Ubuntu 20.04 | `sha256:290498f05271388a79a6642084c0befa207da7148a7ae6a75bd5c0d810e14be5` |
| `genomixcloud/checkm:latest` | CheckM 1.2.5 | Ubuntu 22.04 | `sha256:6d9ce256231d5f4bfa16c515b5d3d496b736aed8f89c2ba646ec7c97bc2aace2` |
| `genomixcloud/fastp:latest` | fastp 1.0.1 | Ubuntu 22.04 | `sha256:82a2918ea319c169128702a37d4fbd86cd87abaa05ab87551606a4dcc3fed527` |
| `genomixcloud/fastqc:latest` | FastQC 0.12.1 | Ubuntu 22.04 | `sha256:3d50c86c892289375f700d05ea222f993243eb97e11250e81cc26279ae3a6710` |
| `genomixcloud/fimtyper:latest` | FimTyper (commit `311023b`) | Ubuntu 20.04 | `sha256:ebd06ab2a3274f7a21b824ec9f4f561bb5b7daed18d6303e8ddd0c97bc31d65c` |
| `genomixcloud/kraken2:latest` | Kraken2 2.1.6 | Ubuntu 22.04 | `sha256:7a57eabc72b068ed0f193f583b1d23c0f3b5c12fa23fca05cf402c27a3443da6` |
| `genomixcloud/mlst:latest` | mlst 2.23.0 | Ubuntu 20.04 | `sha256:93420588cc4f2a05c33f1b1b5af8fe39bf1e5cf3754f741433f2b7c7ed9c95a6` |
| `genomixcloud/pilon:latest` | Pilon 1.24 | Ubuntu 22.04 | `sha256:bcd9712fe0dcaeaefd374862ad5784c3a3c0e8432b66e8d962e1eee0bbd92659` |
| `genomixcloud/platon:latest` | Platon 1.7 | Ubuntu 20.04 | `sha256:ea3034cbde54a8c2bc1c64fe3fcc2448b4aedbbf738ab2132b28482b6ce8c997` |
| `genomixcloud/prokka:latest` | Prokka 1.14.6 | Ubuntu 22.04 | `sha256:bbec3cd8bfd6186c35a541d5126078662c1590d633650aeb60c37007ff4d1f05` |
| `genomixcloud/quast:latest` | QUAST 5.2.0 | Ubuntu 22.04 | `sha256:fe64cc585cb9303f10fbcca71e3eb9999b83cffafe0e9b2786bc6668459a6d63` |
| `genomixcloud/roary:latest` | Roary 3.13.0 | Ubuntu 20.04 | `sha256:a3d015c51d796f951c695a2e1ebe26bb4bce191554b42ecdabc1465213804e6f` |
| `genomixcloud/spades:latest` | SPAdes 3.15.5 | Ubuntu 20.04 | `sha256:562b123c6bac90032e22df04d869bef7142ebaf0832d9152ad85f55fc022ea73` |

### Added
- `Makefile` in the root to build, test and push any tool image to Docker Hub (`make build`, `make test`, `make push`, `make build-all`).
- Smoke test `tools/<tool>/test.sh` for every tool, run by `make test` and before every push.
- Roary: exact conda lock (`roary_env.lock.txt`), pinned Miniconda installer, and the SVG Perl module that `roary2svg.pl` needs.
- `dockerhub/` folder with the Docker Hub page of each image.
- `scripts/rename_contigs.sh` to prepare Bakta GFF3 files for Roary.

### Changed
- Tool READMEs rewritten with one structure, including image contents, troubleshooting and citation.
- Base image moved from Ubuntu 18.04 to 22.04 for ABRicate, fastp, FastQC, Pilon, Prokka and QUAST, and to 20.04 for SPAdes. QUAST and SPAdes now run on Python 3. Main tool versions are unchanged; on the test data, ABRicate, mlst, QUAST and FastQC results are identical to the previous images.
- Pinned versions: CheckM 1.2.5 and its Python dependencies, FimTyper and its database to commits, any2fasta to a commit, the fastp binary checked with its SHA-256.
- `src/<tool>.sh` scripts now read their settings from `/conf/<tool>.ini` (`KEY=VALUE`), stop with a clear error if one is missing, and validate their inputs.
- Test data moved from `data/data_gff` to `data/data_gff_bakta` and `data/data_gff_prokka`.

### Fixed
- `genomixcloud/bakta:latest` on Docker Hub contained the mlst image; it now contains Bakta 1.11.4.
- Pilon: the `pilon` launcher runs directly (`bash pilon` is no longer needed).
- Bakta: `PATH` points to the conda environment, and `conf/` is copied into the image.
- Prokka: `tbl2asn` runs with a fixed date, because the bundled release refuses to run once it's more than a year old.

## - 2026-02-27
### Added
- Build distribution image with docker version > 24.0.2 
- Building platform linux/amd64

### Changed
-
- 

### Removed
- Build distribution image with docker version <= 24.0.2

