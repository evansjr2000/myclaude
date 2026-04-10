#!/bin/bash
set -e

# Locate PostgreSQL binaries (works across versions)
PG_VERSION=$(ls /usr/lib/postgresql/ | sort -V | tail -1)
PG_BINDIR="/usr/lib/postgresql/$PG_VERSION/bin"

# Initialize the data directory if it has not been set up yet
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL $PG_VERSION data directory at $PGDATA..."
    mkdir -p "$PGDATA"
    chown postgres:postgres "$PGDATA"
    su -s /bin/bash postgres -c "$PG_BINDIR/initdb -D $PGDATA"
    echo "PostgreSQL initialization complete."
fi

# Start PostgreSQL in the background
echo "Starting PostgreSQL $PG_VERSION..."
mkdir -p /var/log/postgresql
chown postgres:postgres /var/log/postgresql
su -s /bin/bash postgres -c \
    "$PG_BINDIR/pg_ctl -D $PGDATA -l /var/log/postgresql/startup.log start"

exec "$@"
