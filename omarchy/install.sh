#!/bin/bash
# Install Shader Mix as the Omarchy screensaver.
#   ./install.sh              build, install, and make Omarchy's idle screensaver use it
#   ./install.sh --uninstall  remove it; Omarchy's terminal screensaver comes back
#
# Files:
#   ~/.local/bin/shadermix                          the renderer
#   ~/.local/share/shadermix/                       playlist.tsv, shaders/, textures/ (from ../shader-mix)
#   ~/.local/share/shadermix/bin/omarchy-launch-screensaver
#                                                   replaces Omarchy's launcher via PATH (~/.bashrc)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/../shader-mix/saver"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/shadermix"
BIN="$HOME/.local/bin"
BASHRC="$HOME/.bashrc"
MARK_BEGIN="# >>> shadermix screensaver >>>"
MARK_END="# <<< shadermix screensaver <<<"

remove_path_hook() {
  [[ -f $BASHRC ]] && sed -i "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$BASHRC"
}

if [[ ${1:-} == --uninstall ]]; then
  pkill -f '[o]rg.omarchy.screensaver' 2>/dev/null || true
  remove_path_hook
  rm -rf "$DATA" "$BIN/shadermix"
  echo "Removed. Omarchy's own screensaver is back for new idle cycles."
  exit 0
fi

for cmd in cc pkg-config jq magick; do
  command -v "$cmd" >/dev/null || { echo "error: $cmd is required" >&2; exit 1; }
done

make -C "$ROOT" >/dev/null
install -Dm755 "$ROOT/shadermix" "$BIN/shadermix"

rm -rf "$DATA.new"
mkdir -p "$DATA.new/shaders" "$DATA.new/textures" "$DATA.new/bin"
cp "$SRC"/shaders/*.glsl "$DATA.new/shaders/"
# Channel textures as PPM so the renderer needs no image library.
jq -r '.[] | .channels | to_entries[] | .value' "$SRC/shaders/manifest.json" | sort -u | while read -r tex; do
  magick "$SRC/textures/$tex" "$DATA.new/textures/${tex%.*}.ppm"
done
# Same order and defaults as the macOS saver's manifest.
jq -r '.[] | select(.enabledByDefault) |
  [.key, .title, .author, .link, .license] +
  ([range(0;4) | tostring] as $i | [$i[] as $k | (.channels[$k] // empty | sub("\\.[^.]+$"; ".ppm"))])
  | @tsv' "$SRC/shaders/manifest.json" > "$DATA.new/playlist.tsv"
install -m755 "$ROOT/bin/omarchy-launch-screensaver" "$DATA.new/bin/"
rm -rf "$DATA"
mv "$DATA.new" "$DATA"

# Omarchy's idle service runs `bash -lc omarchy-launch-screensaver`; a login shell reads
# ~/.bashrc (via ~/.bash_profile), so putting our bin first there swaps the launcher.
remove_path_hook
tmp=$(mktemp)
{
  echo "$MARK_BEGIN"
  echo "export PATH=\"$DATA/bin:\$PATH\""
  echo "$MARK_END"
  cat "$BASHRC" 2>/dev/null || true
} > "$tmp"
cat "$tmp" > "$BASHRC"
rm -f "$tmp"

echo "Installed $(wc -l < "$DATA/playlist.tsv") shaders."
echo "Preview now:   omarchy-launch-screensaver force   (or: shadermix --windowed)"
echo "Idle timing:   idle.screensaver in ~/.config/omarchy/shell.json"
