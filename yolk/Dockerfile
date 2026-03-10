# ----------------------------------
# Pelican Panel Dockerfile
# Environment: Source Engine (CS:GO)
# Minimum Panel Version: 1.0.0
# ----------------------------------

FROM        --platform=$TARGETOS/$TARGETARCH ubuntu:22.04

ARG         GITHUB_REPOSITORY
LABEL       org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY}" \
            org.opencontainers.image.licenses=MIT \
            org.opencontainers.image.description="CS:GO (App 4465480) + SourceMod Yolk for Pelican Panel"

ENV         DEBIAN_FRONTEND=noninteractive

RUN         dpkg --add-architecture i386 \
            && apt-get update -y \
            && apt-get install -y \
                curl wget lsof ca-certificates openssl git tar tzdata iproute2 tini zip unzip numactl \
                lib32gcc-s1 lib32stdc++6 \
                libsdl2-2.0-0 libsdl2-2.0-0:i386 \
                libncurses5:i386 \
                lib32z1 \
                libssl3:i386 \
                # SourceMod MySQL extension (dbi.mysql.ext.so) is 32-bit and needs
                # the MySQL client library to connect to databases.
                # libmysqlclient-dev provides the libmysqlclient.so compat symlink.
                libmysqlclient21:i386 \
                libmysqlclient-dev:i386 \
            && apt-get clean \
            && rm -rf /var/lib/apt/lists/*

## Setup user and working directory
RUN         useradd -m -d /home/container -s /bin/bash container
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
