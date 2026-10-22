FROM ubuntu:18.04

ARG FAStpVer=1.0.1

LABEL dockerfile.version="1"
LABEL software="genhub/FAStp"
LABEL software.version="1.0.1"
LABEL website="https://github.com/OpenGene/fastp"
LABEL license="https://github.com/OpenGene/fastp/blob/master/LICENSE"

# fastp installer: https://github.com/OpenGene/fastp#or-download-the-latest-prebuilt-binary-for-linux-users

# no need to compile or build c/c++ in other case: apt-get install -y build-essential
# install dependencies; cleanup apt garbage
RUN apt-get update && apt-get install -y python \
    wget zip && \
    apt-get autoclean && rm -rf /var/lib/apt/lists/*

# install awscli

RUN mkdir -p  /usr/src/fastp

# install fastp
RUN wget -P /usr/src/fastp/ http://opengene.org/fastp/fastp.${FAStpVer} && \
    mv /usr/src/fastp/fastp.${FAStpVer} /usr/src/fastp/fastp && \
    chmod a+x /usr/src/fastp/fastp

COPY ./conf/* /conf/
COPY ./src/* /src/

ENV PATH="${PATH}:/usr/src/fastp/"

WORKDIR /data

CMD ["/bin/bash", "-c"]