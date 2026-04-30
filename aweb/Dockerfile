FROM ubuntu:26.04

LABEL org.opencontainers.image.title="awebpg" \
      org.opencontainers.image.description="AWEB literate-programming toolchain (atangle/aweave) with Ada 95 keyword support and -v/--version flag" \
      org.opencontainers.image.version="2.1" \
      org.opencontainers.image.source="https://github.com/evansjr/aweb" \
      aweb.atangle.version="2.1" \
      aweb.aweave.version="2.1"

RUN apt-get update && apt-get install -y \
    gnat \
    make \
    file \
    emacs \
    && rm -rf /var/lib/apt/lists/*

# Copy source and build atangle
WORKDIR /opt/aweb/atangle
COPY atangle/*.adb atangle/*.ads ./
RUN gnatmake atangle.adb -o atangle

# Copy source and build aweave
WORKDIR /opt/aweb/aweave
COPY aweave/*.adb aweave/*.ads ./
RUN gnatmake aweave.adb -o aweave

# Install binaries to /usr/local/bin
RUN cp /opt/aweb/atangle/atangle /opt/aweb/aweave/aweave /usr/local/bin/

# Install entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Working directory for processing files
WORKDIR /work

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]

