FROM ubuntu:20.04

ARG PLATON_VER="1.7"
RUN apt-get update && apt-get install -y wget zip && \
    apt-get autoclean && rm -rf /var/lib/apt/lists/*

# ENV LANG en_US.utf8
# begin installing conda
RUN wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
RUN bash Miniconda3-latest-Linux-x86_64.sh -b
# adding path to call conda
ENV PATH=/root/miniconda3/bin:${PATH}

# RUN conda update -y conda
RUN conda config --add channels defaults && \
    conda config --add channels bioconda && \
    conda config --add channels conda-forge

RUN conda tos accept --override-channels --channel defaults \
 && conda tos accept --override-channels --channel bioconda \
 && conda tos accept --override-channels --channel conda-forge

RUN conda install -y platon=${PLATON_VER}

# install awscli

COPY ./conf/* /conf/
COPY ./src/* /src/

WORKDIR /data

CMD ["/bin/bash", "-c"]


