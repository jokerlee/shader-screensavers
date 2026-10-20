#!/bin/bash
# Change a default in Info.plist (ShaderMixDefaults), rebuild, install, and restart the
# screen saver host so the next activation picks it up.
#   ./configure.sh                          # show current values and available shaders
#   ./configure.sh segmentSeconds 60
#   ./configure.sh shaders flowingwires,singularity,colorfulinfinity
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PB=/usr/libexec/PlistBuddy
if [ $# -eq 0 ]; then
  "$PB" -c "Print :ShaderMixDefaults" "$HERE/Info.plist"
  echo "available shaders:"; python3 -c "import json;[print('  '+m['key'].ljust(18)+m['title']+' — '+m['author']) for m in json.load(open('$HERE/shaders/manifest.json'))]"
  echo "available transitions: fade,dissolve,radial,clock"
  exit 0
fi
[ $# -eq 2 ] || { echo "usage: $0 [<key> <value>]" >&2; exit 2; }
"$PB" -c "Set :ShaderMixDefaults:$1 $2" "$HERE/Info.plist"
"$HERE/build.sh"
killall legacyScreenSaver 2>/dev/null || true
