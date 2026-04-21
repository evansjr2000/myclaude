#!/bin/bash
set -e

# Locate the PostgreSQL binaries for whichever major version is installed.
PG_VERSION=$(ls /usr/lib/postgresql/ | sort -V | tail -1)
PG_BINDIR="/usr/lib/postgresql/$PG_VERSION/bin"

mkdir -p "$PGDATA"
chown -R postgres:postgres "$PGDATA"

# First-run initialisation. The PG_VERSION file is created by initdb, so its
# absence means the mounted volume is empty and needs a fresh cluster.
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Initialising PostgreSQL $PG_VERSION cluster at $PGDATA..."
    su -s /bin/bash postgres -c "$PG_BINDIR/initdb -D $PGDATA --auth=trust --encoding=UTF8"

    # Accept TCP connections from outside the container (trust auth is fine
    # for a local-dev container; tighten for anything exposed to a network).
    echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
    echo "host all all 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf"
    echo "host all all ::/0      trust" >> "$PGDATA/pg_hba.conf"
    echo "PostgreSQL initialisation complete."
fi

# When asked to run the server, hand control to postgres as PID 1 so the
# container stays alive for `docker run -d` and shuts down cleanly on SIGTERM.
if [ "$1" = "postgres" ]; then
    shift
    exec su -s /bin/bash postgres -c "exec $PG_BINDIR/postgres -D $PGDATA $*"
fi

exec "$@"
