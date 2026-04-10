FROM ubuntu:26.04

RUN apt-get update && apt-get install -y \
    gnat \
    make \
    file \
    emacs \
    postgresql \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# PostgreSQL environment and persistence
ENV PGDATA=/var/lib/postgresql/data
EXPOSE 5432
VOLUME ["/var/lib/postgresql/data"]

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
