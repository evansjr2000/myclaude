FROM ubuntu:26.04

RUN apt-get update && apt-get install -y \
    gnat \
    make \
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

# Working directory for processing files
WORKDIR /work

ENTRYPOINT ["/bin/bash"]
