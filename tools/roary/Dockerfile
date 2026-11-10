FROM ubuntu:20.04

ARG DEBIAN_FRONTEND

ARG RoaryVer="3.13.0"
# Pinned Miniconda installer (base conda 26.9.4, same as the 26 Oct 2026 image)
ARG MinicondaInstaller="Miniconda3-py314_26.9.4-0-Linux-x86_64.sh"
ARG MinicondaSha256="4ecd6f5ced565b02ef2fd5992fca4244b5e695ef5bff2beffbf03c7da5686e35"

RUN apt-get update && apt-get install -y wget zip groff locales && rm -rf /var/lib/apt/lists/* && \
    apt-get autoclean && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG="en_US.utf8"
# begin installing conda
RUN wget -q https://repo.anaconda.com/miniconda/${MinicondaInstaller} && \
    echo "${MinicondaSha256}  ${MinicondaInstaller}" | sha256sum -c - && \
    bash ${MinicondaInstaller} -b && \
    rm ${MinicondaInstaller}
# adding path to call conda
ENV PATH=/root/miniconda3/bin:${PATH}
RUN conda tos accept --override-channels --channel defaults \
 && conda tos accept --override-channels --channel bioconda \
 && conda tos accept --override-channels --channel conda-forge

# No "conda update": it would make the base conda depend on the build date
RUN conda config --add channels defaults && \
    conda config --add channels bioconda && \
    conda config --add channels conda-forge

RUN mkdir /src && mkdir /data && mkdir /conf
# roary2svg.pl from the same Roary release tag (identical to master)
RUN wget -O /usr/bin/roary2svg.pl https://raw.githubusercontent.com/sanger-pathogens/Roary/v${RoaryVer}/contrib/roary2svg/roary2svg.pl
# COPY . /src
# copy & create environment from the exact lock (see environment.yaml for the spec)
COPY environment.yaml roary_env.lock.txt /conf/
RUN conda create --quiet -y -n roary_env --file /conf/roary_env.lock.txt && \
    conda clean -afy
## RUN source activate roary_env
RUN echo "source activate roary_env" > ~/.bashrc
ENV PATH="/root/miniconda3/envs/roary_env/bin:$PATH"
# install awscli
RUN wget -P /usr/src/ https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
    unzip -d /usr/src/  /usr/src/awscli-exe-linux-x86_64.zip && \
    rm /usr/src/awscli-exe-linux-x86_64.zip && \
    /usr/src/aws/install

COPY ./conf /conf
COPY /src/* /src
#####################################################
#  setting of setup_roaryplot has been removed     ##
#  the platform calls roaryplot in jupyter when    ##
#  report_tool generate the report                 ##
# RUN /src/setup_roaryplot.sh $RoaryVer            ##
#####################################################

# Warning: WorkdirRelativePath: Relative workdir "data" can have unexpected results if the base image changes (line 52)
# TODO: Test absolute Path: WORKDIR /data
WORKDIR /data

CMD ["/bin/bash", "-c"]