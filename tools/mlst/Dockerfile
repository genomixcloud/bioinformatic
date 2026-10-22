FROM ubuntu:20.04

# we're using ubuntu:20.04 instead of 18.04 because ncbi-blast+
# ubuntu 18.04 ncbi-blast+ 2.6.0 BUT must be 2.9.0+ => ubuntu:20.04

ARG MlstVer="2.23.0"
ARG ANY2fastaVer="0.4.2"

# install dependencies via apt; cleanup apt garbage
# blast from ubuntu:focal is v2.9.0 (as of 2022-05-09)
# ca-certificates verify authenticity and trustworthiness in our connections
RUN apt-get update && apt-get install -y --no-install-recommends \
 wget \
 ca-certificates \
 libmoo-perl \
 liblist-moreutils-perl \
 libjson-perl \
 gzip \
 file \
 unzip \
 ncbi-blast+ && \
 apt-get autoclean && rm -rf /var/lib/apt/lists/*

# get any2fasta; move binary to /usr/local/bin which is already in $PATH
RUN wget https://github.com/tseemann/any2fasta/archive/refs/tags/v${ANY2fastaVer}.tar.gz && \
 tar xzf v${ANY2fastaVer}.tar.gz && \
 rm v${ANY2fastaVer}.tar.gz && \
 chmod +x any2fasta-${ANY2fastaVer}/any2fasta && \
 mv -v any2fasta-${ANY2fastaVer}/any2fasta /usr/local/bin

# get mlst
RUN wget https://github.com/tseemann/mlst/archive/v${MlstVer}.tar.gz && \
 tar -xzf v${MlstVer}.tar.gz && \
 rm v${MlstVer}.tar.gz

# install awscli

COPY ./conf/* /conf/
COPY ./src/* /src/

# set PATH and perl local settings
ENV PATH="${PATH}:/mlst-${MlstVer}/bin"

WORKDIR /data

CMD ["/bin/bash", "-c"]