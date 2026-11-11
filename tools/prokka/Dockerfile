FROM ubuntu:22.04

ARG PROKKA_VER="1.14.6"
ARG BEDTOOLS_VER="2.29.0"
ARG BARRNAP_VER="0.9"
# BLAST+ stays at 2.9.0, the version of the previous image, so results don't change
ARG BLAST_VER="2.9.0"

# so that apt/tzdata doesn't ask for user input for a timezone
ARG DEBIAN_FRONTEND=noninteractive

# install dependencies
RUN apt-get update && apt-get -y --no-install-recommends install \
 ca-certificates \
 bzip2 \
 gzip \
 wget \
 perl \
 less \
 libdatetime-perl \
 libxml-simple-perl \
 libdigest-md5-perl \
 default-jre-headless \
 bioperl \
 libbio-searchio-hmmer-perl \
 hmmer \
 zlib1g-dev \
 python3 \
 python-is-python3 \
 liblzma-dev \
 libbz2-dev \
 xz-utils \
 curl \
 g++ \
 cpanminus \
 faketime \
 make && \
 apt-get autoclean && rm -rf /var/lib/apt/lists/*

# tbl2asn needs libidn.so.11, which Ubuntu 22.04 no longer packages (it has libidn12):
# install the Ubuntu 20.04 package, checked with its SHA-256
ARG LIBIDN11_DEB="libidn11_1.33-2.2ubuntu2_amd64.deb"
ARG LIBIDN11_SHA256="15dbad793f52b7a271f7d2c9d3566a9c98a7ba5ae315b52414006fc8c6a910f9"
RUN wget -q http://archive.ubuntu.com/ubuntu/pool/main/libi/libidn/${LIBIDN11_DEB} && \
    echo "${LIBIDN11_SHA256}  ${LIBIDN11_DEB}" | sha256sum -c - && \
    dpkg -i ${LIBIDN11_DEB} && rm ${LIBIDN11_DEB}

# install bedtools 2.29.0 since >=2.27.0 is required for barrnap
# dependencies required for bedtools: zlib1g-dev python liblzma-dev libbz2-dev xz-utils curl g++
RUN wget https://github.com/arq5x/bedtools2/releases/download/v${BEDTOOLS_VER}/bedtools-${BEDTOOLS_VER}.tar.gz && \
  tar -zxf bedtools-${BEDTOOLS_VER}.tar.gz && \
  rm bedtools-${BEDTOOLS_VER}.tar.gz && \
  cd bedtools2 && \
  make

# add bedtools to PATH for barrnap test
ENV PATH="$PATH:/bedtools2/bin"

# install barrnap
RUN wget https://github.com/tseemann/barrnap/archive/${BARRNAP_VER}.tar.gz && \
    tar -zxf ${BARRNAP_VER}.tar.gz && \
    rm ${BARRNAP_VER}.tar.gz && \
    cd barrnap-${BARRNAP_VER} && \
    make test

# download prokka and make /data
RUN wget https://github.com/tseemann/prokka/archive/v${PROKKA_VER}.tar.gz && \
    tar -xzf v${PROKKA_VER}.tar.gz && \
    rm -rf v${PROKKA_VER}.tar.gz && \
    mkdir /data

# tbl2asn 25.6 stops working once it is more than a year old, so Prokka fails at its
# last step (GenBank files). /usr/bin/tbl2asn runs the real binary with a fixed date
# (faketime), the same workaround as the bioconda package tbl2asn-forever.
ARG TBL2ASN_DATE="2019-01-01"
RUN wget https://anaconda.org/bioconda/tbl2asn/25.6/download/linux-64/tbl2asn-25.6-3.tar.bz2 && \
tar -jxvf tbl2asn-25.6-3.tar.bz2 bin/tbl2asn && \
mv bin/tbl2asn /usr/bin/real-tbl2asn && \
printf '#!/bin/bash\nexec faketime "%s" /usr/bin/real-tbl2asn "$@"\n' "${TBL2ASN_DATE}" > /usr/bin/tbl2asn && \
chmod +x /usr/bin/tbl2asn && \
rm tbl2asn-25.6-3.tar.bz2

# install blast binaries directly from NCBI FTP
RUN wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/${BLAST_VER}/ncbi-blast-${BLAST_VER}+-x64-linux.tar.gz && \
  tar -xzf ncbi-blast-${BLAST_VER}+-x64-linux.tar.gz && \
  rm ncbi-blast-${BLAST_VER}+-x64-linux.tar.gz

ENV PATH="${PATH}:/ncbi-blast-${BLAST_VER}+/bin/:\
/prokka-${PROKKA_VER}/bin:\
/prokka-${PROKKA_VER}/binaries/common:\
/prokka-${PROKKA_VER}/binaries/linux:\
/barrnap-${BARRNAP_VER}/bin"\
 LC_ALL=C

# install awscli

# index dbs and list what dbs were setup; set working dir to /data
RUN prokka --setupdb && prokka --listdb

COPY ./conf/* /conf/
COPY ./src/* /src/

WORKDIR /data

# Define default command
CMD ["/bin/bash", "-c"]