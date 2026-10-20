#!/bin/bash
# One-step install of the Shader Mix screen saver. No Xcode needed for the default install.
#   ./install.sh               download the latest release (prebuilt universal bundle) and install it,
#                              then open Screen Saver settings; needs gh logged in with access
#   ./install.sh --zip <path>  install a ShaderMix.zip you already have (e.g. from package.sh)
#   ./install.sh --build       build from source instead (needs only: xcode-select --install)
#   ./install.sh --no-open     do not open System Settings afterwards (combinable with --build)
#   ./install.sh --uninstall   move the installed screen saver to the Trash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SAVERS="$HOME/Library/Screen Savers"
DEST="$SAVERS/ShaderMix.saver"
REPO="jokerlee/shader-screensavers"
BUILD=0
ZIP=""
OPEN_SETTINGS=1

fail() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  arg="$1"; shift
  case "$arg" in
    --build) BUILD=1 ;;
    --no-open) OPEN_SETTINGS=0 ;;
    --zip) [ $# -gt 0 ] || fail "--zip needs a path"; ZIP="$1"; shift ;;
    --uninstall)
      if [ -d "$DEST" ]; then
        mv "$DEST" "$HOME/.Trash/ShaderMix-$(date +%Y%m%d-%H%M%S).saver"
        killall legacyScreenSaver 2>/dev/null || true
        echo "Moved $DEST to the Trash."
      else
        echo "Shader Mix is not installed."
      fi
      exit 0 ;;
    *) fail "unknown option $arg (use --zip <path>, --build, --no-open or --uninstall)" ;;
  esac
done

major=$(sw_vers -productVersion | cut -d. -f1)
[ "$major" -ge 13 ] || fail "macOS 13 or later is required (this is $(sw_vers -productVersion))."

# keep the previous install (one backup, replaced on each install)
backup_existing() {
  if [ -d "$DEST" ]; then
    rm -rf "$SAVERS/ShaderMix.saver.backup"
    cp -R "$DEST" "$SAVERS/ShaderMix.saver.backup"
    echo "Previous version backed up to: $SAVERS/ShaderMix.saver.backup"
  fi
}

if [ "$BUILD" = 1 ]; then
  # Only the Swift compiler and the macOS SDK are needed; the Metal shaders are compiled by the
  # GPU driver at load time, and glslang/spirv-cross are optional (pre-translated copies ship).
  xcrun -sdk macosx --find swiftc >/dev/null 2>&1 \
    || fail "Swift compiler not found. Install the Command Line Tools: xcode-select --install"
  command -v python3 >/dev/null || fail "python3 not found. Install the Command Line Tools: xcode-select --install"
  backup_existing
  "$ROOT/shader-mix/saver/build.sh"
else
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  if [ -z "$ZIP" ]; then
    command -v gh >/dev/null || fail "the GitHub CLI (gh) is needed to download the release: brew install gh
  (or install from a zip with --zip <path>, or build from source with --build)"
    echo "Downloading the latest release from $REPO ..."
    gh release download -R "$REPO" -p ShaderMix.zip -D "$TMP" || fail "could not download the release.
  $REPO is private: log in with an account that can see it (gh auth login / gh auth switch),
  or install from a zip with --zip <path>, or build from source with --build."
    ZIP="$TMP/ShaderMix.zip"
  fi
  [ -f "$ZIP" ] || fail "$ZIP not found"
  ditto -x -k "$ZIP" "$TMP/unpacked"
  [ -d "$TMP/unpacked/ShaderMix.saver" ] || fail "ShaderMix.saver not found in $ZIP"
  backup_existing
  mkdir -p "$SAVERS"
  rm -rf "$DEST"
  cp -R "$TMP/unpacked/ShaderMix.saver" "$DEST"
  echo "Installed: $DEST"
fi

xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
# the screen saver host keeps old bundles loaded; restart it so the new version is used
killall legacyScreenSaver 2>/dev/null || true

echo
echo "Done. In System Settings > Screen Saver, choose \"Shader Mix\" (under Other)."
if [ "$OPEN_SETTINGS" = 1 ]; then
  open "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension" 2>/dev/null \
    || open -b com.apple.systempreferences
fi
