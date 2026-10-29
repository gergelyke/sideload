#!/usr/bin/env bash
# Usage: Tools/hello.sh            build + test + screenshot, all in Docker
#        Tools/hello.sh --window   open the hello-world app on this desktop
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--window" ]]; then
    command -v swift >/dev/null || { echo "Install Swift from swift.org, or omit --window"; exit 1; }
    swift build --product sideload
    exec .build/debug/sideload run Fixtures/HelloWorld
fi

docker image inspect sideload-dev >/dev/null 2>&1 \
    || docker build -t sideload-dev -f Tools/docker/Dockerfile .

docker run --rm -v "$PWD":/work -w /work \
    --user "$(id -u):$(id -g)" -e HOME=/tmp \
    sideload-dev \
    bash -c 'swift build && swift test && Tools/e2e.sh && cp /tmp/hello.png /work/hello.png'

echo "Screenshot: $PWD/hello.png"
