FROM ubuntu:18.04

## TODO pass by param to set only in on runtime  !!!!
## docker build --build-arg DEBIAN_FRONTEND=noninteractive .
ARG DEBIAN_FRONTEND

ARG QUAST_VER=5.2.0

# Setup a base system
RUN apt-get update && apt-get install -y zlib1g-dev \
  pkg-config \
  libfreetype6-dev \
  libpng-dev \
  wget unzip\
  g++ \
  make \
  perl \
  python \
  python-setuptools \
  python-matplotlib \
  python-simplejson \
  python-joblib \
  locales \
  default-jdk \
  python-pip && \
  locale-gen en_US.UTF-8 && \
  apt-get clean && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/*

# TODO  => ver si esta la instalacion actual o ./setup.py install_full
# install quast and make /data directory
RUN wget https://github.com/ablab/quast/releases/download/quast_${QUAST_VER}/quast-${QUAST_VER}.tar.gz && \
    tar -xzf quast-${QUAST_VER}.tar.gz && \
    rm -rf quast-${QUAST_VER}.tar.gz && \
    cd /quast-${QUAST_VER} && \
    /quast-${QUAST_VER}/setup.py install

# install awscli

COPY ./conf/* /conf/
COPY ./src/* /src/

ENV PATH="${PATH}:/quast-${QUAST_VER}/"

WORKDIR /data

CMD ["/bin/bash", "-c"]