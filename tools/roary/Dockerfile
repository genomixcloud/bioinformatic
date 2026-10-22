FROM ubuntu:20.04

ARG DEBIAN_FRONTEND

ARG RoaryVer="3.13.0"

RUN apt-get update && apt-get install -y wget zip groff locales && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8
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

RUN mkdir /src && mkdir /data && mkdir /conf
RUN wget -O /usr/bin/roary2svg.pl https://raw.githubusercontent.com/sanger-pathogens/Roary/master/contrib/roary2svg/roary2svg.pl
# COPY . /src
# copy & create environment
COPY environment.yaml /conf/environment.yaml
RUN conda env create --quiet -f ./conf/environment.yaml
## RUN source activate roary_env
RUN echo "source activate roary_env" > ~/.bashrc
ENV PATH /opt/conda/envs/roary_env/bin:$PATH
# install awscli

COPY ./conf /conf
COPY /src/* /src

WORKDIR data

CMD ["/bin/bash", "-c"]