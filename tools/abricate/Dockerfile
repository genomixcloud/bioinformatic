FROM ubuntu:22.04
# For easy upgrade later. ARG varibles only persist during docker image build time
ARG DEBIAN_FRONTEND=noninteractive
ARG ABRIcateVer="1.0.1"
# any2fasta has no tag for its current version (0.9.0): pin the commit in the 23 Oct 2026 image
ARG ANY2FASTA_COMMIT="70ba375452568dc005102aadd95064ec8b8dbdc1"

# install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  bioperl \
  ca-certificates \
  gzip \
  unzip \
  liblist-moreutils-perl \
  libjson-perl \
  libtext-csv-perl \
  libfile-slurp-perl \
  liblwp-protocol-https-perl \
  libwww-perl \
  libpath-tiny-perl \
  ncbi-blast+ \
  wget && \
  apt-get autoclean && rm -rf /var/lib/apt/lists/*

# install awscli

# get any2fasta
RUN cd /usr/local/bin && \
  wget -q https://raw.githubusercontent.com/tseemann/any2fasta/${ANY2FASTA_COMMIT}/any2fasta && \
  chmod +x any2fasta

# download abricate
RUN wget -q https://github.com/tseemann/abricate/archive/v${ABRIcateVer}.tar.gz && \
    tar -zxf v${ABRIcateVer}.tar.gz && \
    rm -rf v${ABRIcateVer}.tar.gz && \
    mkdir /data && mkdir /src && mkdir /conf

# set $PATH
ENV PATH="${PATH}:/abricate-${ABRIcateVer}/bin"

# index the databases bundled with this ABRicate release (no download)
RUN abricate --setupdb

COPY ./conf/* /conf/
COPY ./src/* /src/

WORKDIR /data

CMD ["/bin/bash", "-c"]
