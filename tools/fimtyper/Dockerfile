FROM ubuntu:20.04

# FimTyper has no releases: pin the commits of the code and of the database.
# These are the commits in the 23 Oct 2026 image.
ARG FIMTYPER_COMMIT="311023be5c2caf8ad0673b15169ee02af5c46954"
ARG FIMTYPER_DB_COMMIT="820782c9dd7334cd707b161d9ab8ef541a0a68c2"

LABEL software="genomixcloud/FimTyper"
LABEL software.version="0.0.1-a.0"
LABEL website="https://bitbucket.org/genomicepidemiology/fimtyper/"
LABEL license="https://bitbucket.org/genomicepidemiology/fimtyper/src/master/README.md#license"

RUN apt-get update && apt-get install -y build-essential git

RUN apt-get update && apt-get install -y --no-install-recommends \
 wget \
 gzip \
 libjson-perl \
 perl \
 curl \
 file \
 unzip \
 ncbi-blast+ && \
 apt-get autoclean && rm -rf /var/lib/apt/lists/*

# install awscli

# installing fimtyper and its database at the pinned commits
RUN cd /usr/local && \
    git clone https://bitbucket.org/genomicepidemiology/fimtyper.git && \
    git -C /usr/local/fimtyper checkout --quiet ${FIMTYPER_COMMIT} && \
    cd /usr/local/fimtyper && \
    git clone https://bitbucket.org/genomicepidemiology/fimtyper_db.git && \
    git -C /usr/local/fimtyper/fimtyper_db checkout --quiet ${FIMTYPER_DB_COMMIT}

COPY ./src/* /usr/local/fimtyper

RUN /usr/local/fimtyper/tmp_brew.sh

ENV PATH="${PATH}:/usr/local/fimtyper"

# create /data directory and set as working directory
WORKDIR /data

CMD ["/bin/bash", "-c"]
