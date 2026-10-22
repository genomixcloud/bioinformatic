FROM ubuntu:18.04

ARG PilonVer=1.24
ARG BWAmen2Ver=2.2.1
ARG SamToolsVer=1.9

# no need to compile or build c/c++ in other case: apt-get install -y build-essential
# install dependencies; cleanup apt garbage
RUN apt-get update && apt-get install -y wget \
zip \
curl \
gcc \
make \
libbz2-dev \
zlib1g-dev \
libncurses5-dev \
libncursesw5-dev \
liblzma-dev \
openjdk-8-jdk \
python && \
apt-get autoclean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p  /usr/src/pilon && mkdir /usr/src/samtools-${SamToolsVer}

# install pilon
RUN wget -P /usr/src/pilon/ https://github.com/broadinstitute/pilon/releases/download/v${PilonVer}/pilon-${PilonVer}.jar && \
chmod a+x /usr/src/pilon/pilon-${PilonVer}.jar && \
echo "#!/bin/bash" >> pilon && \
echo "exec java -jar /usr/src/pilon/pilon-${PilonVer}.jar """"$""@"""" " >>  /usr/src/pilon/pilon && \
chmod a+x /usr/src/pilon/pilon

# install bwa-men2
RUN curl -L https://github.com/bwa-mem2/bwa-mem2/releases/download/v${BWAmen2Ver}/bwa-mem2-${BWAmen2Ver}_x64-linux.tar.bz2 \
 | tar jxf - && mv bwa-mem2-${BWAmen2Ver}_x64-linux /usr/src/bwa

# install samtool
RUN cd /usr/src/ && \
wget https://github.com/samtools/samtools/releases/download/${SamToolsVer}/samtools-${SamToolsVer}.tar.bz2 && \
tar -vxjf samtools-${SamToolsVer}.tar.bz2 && rm samtools-${SamToolsVer}.tar.bz2 \
&& cd samtools-${SamToolsVer} && make

# install awscli

COPY ./conf/* /conf/
COPY ./src/* /src/

# set PATH
ENV PATH="${PATH}:/usr/src/pilon/:/usr/src/bwa:/usr/src/samtools-1.9"

WORKDIR /data

CMD ["/bin/bash", "-c"]