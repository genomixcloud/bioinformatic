#!/bin/bash
sudo apt-get update
sudo apt-get install -y zip
sudo apt-get install -y groff locales
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b
# check prefix => PREFIX=/home/ubuntu/miniconda3
export PATH=$HOME/bin:/home/ubuntu/miniconda3/bin:$PATH
conda update -y conda
LANG=en_US.utf8

conda tos accept --override-channels --channel defaults \
&& conda tos accept --override-channels --channel bioconda \
&& conda tos accept --override-channels --channel conda-forge

conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
# configure environment
conda env create --quiet -f environment.yaml
source activate bakta_env