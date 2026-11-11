FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG SPAdesVer=3.15.5
# install dependencies; cleanup apt garbage
# Ubuntu 20.04, Python 3.8: the prebuilt SPAdes 3.15.5 binaries crash (segfault) on Ubuntu 22.04.
# python-is-python3 provides the "python" command that spades.py calls
RUN apt-get update && apt-get install -y --no-install-recommends \
 python3 python-is-python3 \
 wget ca-certificates zip && \
 apt-get autoclean && rm -rf /var/lib/apt/lists/*

# install awscli

# install SPAdes binary; make /data
RUN wget -q https://github.com/ablab/spades/releases/download/v${SPAdesVer}/SPAdes-${SPAdesVer}-Linux.tar.gz && \
  tar -xzf SPAdes-${SPAdesVer}-Linux.tar.gz && \
  rm -r SPAdes-${SPAdesVer}-Linux.tar.gz && \
  mkdir /data

COPY ./conf/ /conf/
COPY ./src/ /src/

ENV PATH="${PATH}:/SPAdes-${SPAdesVer}-Linux/bin"

WORKDIR /data

CMD ["/bin/bash", "-c"]
