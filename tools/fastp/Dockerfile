FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG FAStpVer=1.0.1
# SHA-256 of the prebuilt fastp 1.0.1 binary (the same as in the 23 Oct 2026 image)
ARG FAStpSha256="c42e121f75029fd29724347f26db316e4d6c19dbab9d161713b5561c3cf82631"

LABEL dockerfile.version="2"
LABEL software="genhub/FAStp"
LABEL software.version="1.0.1"
LABEL website="https://github.com/OpenGene/fastp"
LABEL license="https://github.com/OpenGene/fastp/blob/master/LICENSE"

# fastp installer: https://github.com/OpenGene/fastp#or-download-the-latest-prebuilt-binary-for-linux-users

# install dependencies; cleanup apt garbage
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates zip && \
    apt-get autoclean && rm -rf /var/lib/apt/lists/*

# install awscli

RUN mkdir -p /usr/src/fastp /data /src /conf

# install fastp over https and check its checksum
RUN wget -q -O /usr/src/fastp/fastp https://opengene.org/fastp/fastp.${FAStpVer} && \
    echo "${FAStpSha256}  /usr/src/fastp/fastp" | sha256sum -c - && \
    chmod a+x /usr/src/fastp/fastp

COPY ./conf/* /conf/
COPY ./src/* /src/

ENV PATH="${PATH}:/usr/src/fastp/"

WORKDIR /data

CMD ["/bin/bash", "-c"]
