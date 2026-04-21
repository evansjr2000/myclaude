FROM ubuntu:26.04

RUN apt-get update && apt-get install -y \
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


# Install entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Working directory for processing files
WORKDIR /work

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
