#!/usr/bin/env bash
# End-to-end acceptance check for the MVP gate. Builds and runs the real
# sideload CLI against Fixtures/HelloWorld — nothing here calls into the
# SDK's internals directly, so this is as close as this repo gets to
# "a developer typed these commands".
set -euo pipefail
cd "$(dirname "$0")/.."

swift build --product sideload
SL="$PWD/.build/debug/sideload"

"$SL" build Fixtures/HelloWorld
"$SL" run Fixtures/HelloWorld --headless --screenshot /tmp/hello.png

for d in phone-6.1-island phone-6.7-island phone-4.7-se; do
    "$SL" run Fixtures/HelloWorld --headless --device "$d" --screenshot "/tmp/hello-$d.png"
done

SIDELOAD_E2E_PNG=/tmp/hello.png swift test --filter EndToEndTests

# Window smoke test. xvfb-run's own readiness wait relies on a SIGUSR1
# handshake that doesn't reach its parent inside this sandbox's nested
# container, so Xvfb is started and waited on manually instead.
Xvfb :99 -screen 0 1280x1024x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
xvfb=$!
sleep 2
export DISPLAY=:99
"$SL" run Fixtures/HelloWorld &
app=$!
sleep 3
kill -0 "$app"
kill -TERM "$app"
wait "$app" || true
kill "$xvfb" 2>/dev/null || true
unset DISPLAY

# Diagnostics point at the original file, not the generated copy. Copy
# only the Xcode project itself — not Fixtures/HelloWorld/.sideload/,
# whose module cache is tied to the original absolute path.
tmp=$(mktemp -d)
mkdir -p "$tmp/HelloWorld"
cp -r Fixtures/HelloWorld/HelloWorld.xcodeproj Fixtures/HelloWorld/HelloWorld "$tmp/HelloWorld/"
sed -i 's/Text("Hello, world!")/Text(42)/' "$tmp/HelloWorld/HelloWorld/ContentView.swift"
if "$SL" build "$tmp/HelloWorld" >"$tmp/out.txt" 2>&1; then
    echo "expected a build failure for the injected type error" >&2
    cat "$tmp/out.txt" >&2
    exit 1
fi
if ! grep -q "$tmp/HelloWorld/HelloWorld/ContentView.swift:" "$tmp/out.txt"; then
    echo "diagnostic did not name the original file path" >&2
    cat "$tmp/out.txt" >&2
    exit 1
fi
rm -rf "$tmp"

echo "E2E OK"
