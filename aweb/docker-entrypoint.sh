#!/bin/bash
# Container entrypoint for the awebpg image.  After the PostgreSQL
# stack was removed in release 2.1 (requirement 10) this script has
# nothing to do at startup; it simply hands control to the requested
# command.  It is kept as a single layer of indirection so the image's
# run interface (CMD args are run as a shell command) is preserved.
set -e
exec "$@"
