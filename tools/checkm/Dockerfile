FROM ubuntu:jammy
# FROM ubuntu:20.04
ARG CHECKM_VER="1.2.4"
ARG PPLACER_VER="v1.1.alpha19"
LABEL license="https://github.com/Ecogenomics/CheckM/blob/master/LICENSE"

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    zip \
    unzip \
    python3-pip \
    hmmer \
    prodigal &&\
    apt-get autoclean && rm -rf /var/lib/apt/lists/*

RUN mkdir /data && mkdir /src && mkdir /conf

# install checkm and its dependencies
RUN pip install --no-cache-dir numpy matplotlib pysam checkm-genome &&\
    wget https://github.com/matsen/pplacer/releases/download/${PPLACER_VER}/pplacer-linux-${PPLACER_VER}.zip && \
    unzip pplacer-linux-${PPLACER_VER}.zip && rm pplacer-linux-${PPLACER_VER}.zip

ENV PATH=$PATH:/pplacer-Linux-${PPLACER_VER} \
    LC_ALL=C

COPY ./conf/* /conf/
COPY ./src/* /src/

WORKDIR /data

# download database and inform CheckM of where the files have been placed
RUN wget https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz &&\
    mkdir checkm_db && tar -C /data/checkm_db -xvf checkm_data_2015_01_16.tar.gz &&\
    rm checkm_data_2015_01_16.tar.gz && checkm data setRoot checkm_db
RUN checkm data setRoot checkm_db

CMD ["/bin/bash", "-c"]