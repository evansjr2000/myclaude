#!/bin/bash
# Helper script to run atangle/aweave in Docker
# Usage:
#   ./awebpg.sh atangle file.aweb [changefile]
#   ./awebpg.sh aweave  file.aweb [changefile]
#   ./awebpg.sh shell                       # interactive shell
#   ./awebpg.sh test                        # run the STP test harness
#   ./awebpg.sh build                       # rebuild the image

VERSION="2.0"
IMAGE_NAME="evansjr/awebpg:$VERSION"
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
        docker run --rm -v "$(pwd):/work" "$IMAGE_NAME" \
            /bin/bash -c "$CMD $*"
        ;;
    shell)
        docker run --rm -it -v "$(pwd):/work" "$IMAGE_NAME"

        ;;
    test)
        # Run the Software Test Plan harness inside the container.
        # The repo is mounted read-write at /work so the harness can
        # write its log and per-case scratch files.
        shift
        docker run --rm \
            -v "$SCRIPT_DIR:/work" \
            -w /work \
            "$IMAGE_NAME" \
            /bin/bash -c "tests/test_aweb.sh $*"
        ;;
    build)
        docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
        ;;
    *)
        echo "Usage: $0 {atangle|aweave|shell|test|build} [args...]"
        echo ""
        echo "Commands:"
        echo "  atangle file.aweb [changefile]  - Extract Ada code from AWEB file"
        echo "  aweave  file.aweb [changefile]  - Generate TeX documentation"
        echo "  shell                           - Interactive bash shell"
        echo "  test                            - Run the STP harness in-container"
        echo "  build                           - Rebuild the Docker image"
        exit 1
        ;;
esac
