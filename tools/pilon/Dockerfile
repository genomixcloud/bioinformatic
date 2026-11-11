FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG PilonVer=1.24
ARG BWAmen2Ver=2.2.1
ARG SamToolsVer=1.9

# build dependencies for samtools, and Java 8 for Pilon; cleanup apt garbage
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    bzip2 \
    zip \
    curl \
    gcc \
    make \
    libc6-dev \
    libbz2-dev \
    zlib1g-dev \
    libncurses5-dev \
    libncursesw5-dev \
    liblzma-dev \
    openjdk-8-jre-headless && \
    apt-get autoclean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/src/pilon /data /src /conf

# install pilon and its launcher: /usr/src/pilon/pilon runs the JAR with the given arguments
RUN wget -q -P /usr/src/pilon/ https://github.com/broadinstitute/pilon/releases/download/v${PilonVer}/pilon-${PilonVer}.jar && \
    printf '#!/bin/bash\nexec java -jar /usr/src/pilon/pilon-%s.jar "$@"\n' "${PilonVer}" > /usr/src/pilon/pilon && \
    chmod a+x /usr/src/pilon/pilon

# install bwa-mem2
RUN curl -sL https://github.com/bwa-mem2/bwa-mem2/releases/download/v${BWAmen2Ver}/bwa-mem2-${BWAmen2Ver}_x64-linux.tar.bz2 \
    | tar jxf - && mv bwa-mem2-${BWAmen2Ver}_x64-linux /usr/src/bwa

# install samtools
RUN cd /usr/src/ && \
    wget -q https://github.com/samtools/samtools/releases/download/${SamToolsVer}/samtools-${SamToolsVer}.tar.bz2 && \
    tar -xjf samtools-${SamToolsVer}.tar.bz2 && rm samtools-${SamToolsVer}.tar.bz2 && \
    cd samtools-${SamToolsVer} && make

# install awscli

COPY ./conf/* /conf/
COPY ./src/* /src/

# set PATH
ENV PATH="${PATH}:/usr/src/pilon:/usr/src/bwa:/usr/src/samtools-${SamToolsVer}"

WORKDIR /data

CMD ["/bin/bash", "-c"]
