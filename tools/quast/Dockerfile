FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

ARG QUAST_VER=5.2.0

# Setup a base system: Python 3.10 and the QUAST Python dependencies from Ubuntu
# python-is-python3 provides the "python" command that quast.py calls
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  zlib1g-dev \
  pkg-config \
  libfreetype6-dev \
  libpng-dev \
  wget unzip \
  g++ \
  make \
  perl \
  python3 \
  python-is-python3 \
  python3-setuptools \
  python3-matplotlib \
  python3-simplejson \
  python3-joblib \
  locales \
  default-jre-headless && \
  locale-gen en_US.UTF-8 && \
  apt-get clean && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/*

# install quast and make /data directory
RUN wget -q https://github.com/ablab/quast/releases/download/quast_${QUAST_VER}/quast-${QUAST_VER}.tar.gz && \
    tar -xzf quast-${QUAST_VER}.tar.gz && \
    rm -rf quast-${QUAST_VER}.tar.gz && \
    cd /quast-${QUAST_VER} && \
    python3 setup.py install

# install awscli

COPY ./conf/* /conf/
COPY ./src/* /src/

ENV PATH="${PATH}:/quast-${QUAST_VER}/"

WORKDIR /data

CMD ["/bin/bash", "-c"]
