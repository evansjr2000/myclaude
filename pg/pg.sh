#!/bin/bash
# Launch the Postgres container in the background on localhost:5432.
# Usage:
#   ./pg.sh start     # build if needed, then run detached
#   ./pg.sh stop      # stop and remove the container
#   ./pg.sh logs      # tail server logs
#   ./pg.sh psql      # open a psql shell against the running container
#   ./pg.sh build     # (re)build the image
#   ./pg.sh status    # show container status

set -e

IMAGE_NAME="evansjr/pg"
CONTAINER_NAME="pg"
HOST_PORT="${HOST_PORT:-5432}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/pgdata"

build_image() {
    echo "Building $IMAGE_NAME..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
}

ensure_image() {
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        build_image
    fi
}

case "${1:-start}" in
    start)
        ensure_image
        mkdir -p "$DATA_DIR"
        if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
            echo "Container '$CONTAINER_NAME' already exists; starting it."
            docker start "$CONTAINER_NAME" >/dev/null
        else
            docker run -d \
                --name "$CONTAINER_NAME" \
                -p "$HOST_PORT:5432" \
                -v "$DATA_DIR:/var/lib/postgresql/data" \
                "$IMAGE_NAME" >/dev/null
        fi
        echo "Postgres running on localhost:$HOST_PORT (data: $DATA_DIR)"
        ;;
    stop)
        if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
            docker rm -f "$CONTAINER_NAME" >/dev/null
            echo "Stopped and removed container '$CONTAINER_NAME'."
        else
            echo "No container named '$CONTAINER_NAME'."
        fi
        ;;
    logs)
        docker logs -f "$CONTAINER_NAME"
        ;;
    psql)
        shift
        docker exec -it "$CONTAINER_NAME" psql -U postgres "$@"
        ;;
    build)
        build_image
        ;;
    status)
        docker ps -a --filter "name=^${CONTAINER_NAME}$"
        ;;
    *)
        echo "Usage: $0 {start|stop|logs|psql|build|status}" >&2
        exit 1
        ;;
esac
