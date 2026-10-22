FROM ubuntu:20.04

ARG DEBIAN_FRONTEND

LABEL website="https://github.com/oschwengers/bakta"
LABEL license="https://github.com/oschwengers/bakta/blob/main/LICENSE"

# tag ubuntu:18.04 @see Locales
RUN apt-get update && apt-get install -y wget zip groff locales && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG="en_US.utf8"
# begin installing conda
RUN wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
RUN bash Miniconda3-latest-Linux-x86_64.sh -b
# adding path to call conda
ENV PATH=/root/miniconda3/bin:${PATH}

RUN conda tos accept --override-channels --channel defaults \
 && conda tos accept --override-channels --channel bioconda \
 && conda tos accept --override-channels --channel conda-forge

RUN conda update -y conda
RUN conda config --add channels defaults && \
    conda config --add channels bioconda && \
    conda config --add channels conda-forge

# copy & create environment
RUN mkdir /src
COPY environment.yaml /src/environment.yaml
RUN conda env create --quiet -f /src/environment.yaml

## RUN source activate bakta_env
RUN echo "source activate bakta_env" > ~/.bashrc
ENV PATH /opt/conda/envs/bakta_env/bin:$PATH
COPY ./src/* /src/
WORKDIR /data
CMD ["/bin/bash", "-c"]