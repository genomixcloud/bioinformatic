#!/bin/bash
set -e

# Version variable (same as ARG)
K2pVer="2.1.6"

echo "Updating packages..."
apt-get update

echo "Upgrading perl..."
apt-get upgrade -y perl

echo "Installing dependencies..."
apt-get install -y \
    zlib1g-dev \
    make \
    wget \
    zip \
    python3 \
    g++ \
    rsync \
    ncbi-blast+

echo "Cleaning apt cache..."
rm -rf /var/lib/apt/lists/*
apt-get autoclean

echo "Downloading Kraken2 v${K2pVer}..."
wget https://github.com/DerrickWood/kraken2/archive/v${K2pVer}.tar.gz

echo "Extracting Kraken2..."
tar -xzf v${K2pVer}.tar.gz
rm -f v${K2pVer}.tar.gz

echo "Installing Kraken2..."
cd kraken2-${K2pVer}
sudo ./install_kraken2.sh /home/ubuntu/kraken2_install_dir
# ./install_kraken2.sh .

echo "Installation complete."
echo "Kraken2 installed in ${KRAKEN_PATH}"