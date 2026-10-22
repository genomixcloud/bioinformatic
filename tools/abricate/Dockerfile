FROM ubuntu:18.04
# For easy upgrade later. ARG varibles only persist during docker image build time
ARG ABRIcateVer="1.0.1"

# install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  bioperl \
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
  wget https://raw.githubusercontent.com/tseemann/any2fasta/master/any2fasta && \
  chmod +x any2fasta

# download abricate
RUN wget https://github.com/tseemann/abricate/archive/v${ABRIcateVer}.tar.gz && \
    tar -zxvf v${ABRIcateVer}.tar.gz && \
    rm -rf v${ABRIcateVer}.tar.gz && \
    mkdir /data && mkdir /src && mkdir /conf

# set $PATH
ENV PATH="${PATH}:/abricate-${ABRIcateVer}/bin"

RUN abricate --setupdb

COPY ./conf/* /conf/
COPY ./src/* /src/

WORKDIR /data

CMD ["/bin/bash", "-c"]