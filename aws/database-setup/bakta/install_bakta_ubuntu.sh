#!/bin/bash
# Installs Miniconda and the bakta_env conda environment (Bakta 1.11.4) on an
# Ubuntu x86_64 machine, for example an AWS EC2 instance.
# Usage: ./install_bakta_ubuntu.sh   (environment.yaml must be in the same folder)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONDA_DIR="${CONDA_DIR:-$HOME/miniconda3}"
INSTALLER="Miniconda3-latest-Linux-x86_64.sh"

[ -f "$SCRIPT_DIR/environment.yaml" ] || { echo "ERROR: environment.yaml not found next to this script" >&2; exit 1; }

echo "== Installing system packages"
sudo apt-get update
sudo apt-get install -y wget zip groff locales
sudo locale-gen en_US.UTF-8
export LANG=en_US.UTF-8

echo "== Installing Miniconda in $CONDA_DIR"
if [ -x "$CONDA_DIR/bin/conda" ]; then
  echo "Miniconda is already installed, skipping"
else
  wget -q "https://repo.anaconda.com/miniconda/$INSTALLER" -O "/tmp/$INSTALLER"
  bash "/tmp/$INSTALLER" -b -p "$CONDA_DIR"
  rm "/tmp/$INSTALLER"
fi
export PATH="$CONDA_DIR/bin:$PATH"

echo "== Accepting the conda channel terms of service"
# must come before any conda command that uses the defaults channel
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
conda tos accept --override-channels --channel conda-forge
conda tos accept --override-channels --channel bioconda

echo "== Updating conda and adding the channels"
conda update -y -n base conda
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge

echo "== Creating the bakta_env environment"
if conda env list | grep -qE '^bakta_env[[:space:]]'; then
  echo "bakta_env already exists, skipping (remove it with: conda env remove -n bakta_env)"
else
  conda env create --quiet -f "$SCRIPT_DIR/environment.yaml"
fi

"$CONDA_DIR/envs/bakta_env/bin/bakta" --version

cat <<EOF

Bakta is installed. To use it in this and every new SSH session, run:

  export PATH="$CONDA_DIR/bin:\$PATH"
  source activate bakta_env

EOF
