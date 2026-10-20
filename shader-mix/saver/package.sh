#!/bin/bash
# Build the universal bundle and package it as dist/ShaderMix.zip (the prebuilt install used by
# ../../install.sh and attached to GitHub releases).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$HERE/../../dist"
"$HERE/build.sh" --no-install
mkdir -p "$DIST"
rm -f "$DIST/ShaderMix.zip"
ditto -c -k --keepParent "$HERE/build/ShaderMix.saver" "$DIST/ShaderMix.zip"
echo "Packaged: $(cd "$DIST" && pwd)/ShaderMix.zip"
