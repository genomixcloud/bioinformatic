FROM ubuntu:jammy
# CheckM and its Python dependencies are pinned to the versions of the
# 23 Oct 2026 image, so every build installs the same versions.
ARG CHECKM_VER="1.2.5"
ARG NUMPY_VER="2.2.6"
ARG MATPLOTLIB_VER="3.10.9"
ARG PYSAM_VER="0.24.1"
ARG SCIPY_VER="1.15.3"
ARG PPLACER_VER="v1.1.alpha19"
LABEL license="https://github.com/Ecogenomics/CheckM/blob/master/LICENSE"

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    zip \
    unzip \
    python3-pip \
    hmmer \
    prodigal &&\
    apt-get autoclean && rm -rf /var/lib/apt/lists/*

RUN mkdir /data && mkdir /src && mkdir /conf

# install checkm and its dependencies
RUN pip install --no-cache-dir \
      numpy==${NUMPY_VER} \
      matplotlib==${MATPLOTLIB_VER} \
      pysam==${PYSAM_VER} \
      scipy==${SCIPY_VER} \
      checkm-genome==${CHECKM_VER} && \
    wget -q https://github.com/matsen/pplacer/releases/download/${PPLACER_VER}/pplacer-linux-${PPLACER_VER}.zip && \
    unzip pplacer-linux-${PPLACER_VER}.zip && rm pplacer-linux-${PPLACER_VER}.zip

ENV PATH=$PATH:/pplacer-Linux-${PPLACER_VER} \
    LC_ALL=C

COPY ./conf/* /conf/
COPY ./src/* /src/

WORKDIR /data

# download database and inform CheckM of where the files have been placed
RUN wget -q https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz &&\
    mkdir checkm_db && tar -C /data/checkm_db -xf checkm_data_2015_01_16.tar.gz &&\
    rm checkm_data_2015_01_16.tar.gz && checkm data setRoot checkm_db

CMD ["/bin/bash", "-c"]
