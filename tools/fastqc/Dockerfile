FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG FASTqcVer="0.12.1"
# install dependencies; cleanup apt garbage
RUN apt-get update && apt-get install -y --no-install-recommends \
 ca-certificates \
 zip \
 unzip \
 wget \
 perl \
 default-jre-headless && \
 apt-get autoclean && rm -rf /var/lib/apt/lists/*

# install awscli

# install fastqc; make /data
RUN wget -q https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${FASTqcVer}.zip && \
    unzip -q fastqc_v${FASTqcVer}.zip && \
    rm fastqc_v${FASTqcVer}.zip && \
    chmod +x FastQC/fastqc && \
    mkdir /data && mkdir /src && mkdir /conf

COPY ./conf/* /conf/
COPY ./src/* /src/

ENV PATH="${PATH}:/FastQC/"

WORKDIR /data

CMD ["/bin/bash", "-c"]
