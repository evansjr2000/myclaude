#!/bin/bash
# Helper script to run atangle/aweave in Docker
# Usage:
#   ./aweb.sh atangle file.aweb [changefile]
#   ./aweb.sh aweave file.aweb [changefile]
#   ./aweb.sh shell              # interactive shell

IMAGE_NAME="evansjr/aweb"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build image if it doesn't exist
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Building $IMAGE_NAME image..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

case "$1" in
    atangle|aweave)
        CMD="$1"
        shift
        docker run --rm -v "$(pwd):/work" "$IMAGE_NAME" -c "$CMD $*"
        ;;
    shell)
        docker run --rm -it -v "$(pwd):/work" "$IMAGE_NAME"
        ;;
    build)
        docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
        ;;
    *)
        echo "Usage: $0 {atangle|aweave|shell|build} [args...]"
        echo ""
        echo "Commands:"
        echo "  atangle file.aweb [changefile]  - Extract Ada code from AWEB file"
        echo "  aweave file.aweb [changefile]   - Generate TeX documentation"
        echo "  shell                           - Interactive bash shell"
        echo "  build                           - Rebuild the Docker image"
        exit 1
        ;;
esac
