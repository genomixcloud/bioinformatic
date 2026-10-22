#!/bin/bash

###############################
# update_blast-ver.sh version #
# default value 2.14.0        #
###############################
blast_version="${1:-2.14.0}"

## for LATEST version @see: https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/
cd /usr/local/fimtyper/
wget -m ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-$blast_version+-x64-linux.tar.gz
cd ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST
tar -xf ncbi-blast-$blast_version+-x64-linux.tar.gz -C /usr/local/fimtyper/
rm -rf /usr/local/fimtyper/ftp.ncbi.nlm.nih.gov?