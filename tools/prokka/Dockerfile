FROM ubuntu:18.04

ARG PROKKA_VER="1.14.6"
ARG BEDTOOLS_VER="2.29.0"
ARG BARRNAP_VER="0.9"
ARG BLAST_VER="2.9.0"

# so that apt/tzdata doesn't ask for user input for a timezone
ARG DEBIAN_FRONTEND

# install dependencies
RUN apt-get update && apt-get -y --no-install-recommends install \
 bzip2 \
 gzip \
 wget \
 perl \
 less \
 libdatetime-perl \
 libxml-simple-perl \
 libdigest-md5-perl \
 default-jre \
 bioperl \
 hmmer \
 zlib1g-dev \
 python \
 liblzma-dev \
 libbz2-dev \
 xz-utils \
 curl \
 g++ \
 cpanminus \
 make \
 libidn11 && \
 apt-get autoclean && rm -rf /var/lib/apt/lists/*

# install bedtools 2.29.0 since >=2.27.0 is required for barrnap and the apt-get package is 2.25.0
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

RUN wget https://anaconda.org/bioconda/tbl2asn/25.6/download/linux-64/tbl2asn-25.6-3.tar.bz2 && \
tar -jxvf tbl2asn-25.6-3.tar.bz2 bin/tbl2asn && \
mv bin/tbl2asn /usr/bin/real-tbl2asn && \
cp /usr/bin/real-tbl2asn /usr/bin/tbl2asn && \
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