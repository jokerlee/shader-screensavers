#!/bin/bash
# Build ShaderMix.saver (universal: arm64 + x86_64) and install it into ~/Library/Screen Savers.
#   ./build.sh               build and install
#   ./build.sh --no-install  only build (into build/)
# Needs only the Command Line Tools (xcode-select --install): the Metal shaders are compiled by
# the GPU driver when the screen saver loads, so no offline Metal compiler is involved.
# The Shadertoy GLSL in shaders/ is translated to Metal with glslangValidator + spirv-cross
# (brew install glslang spirv-cross) when they are installed; otherwise the pre-translated
# files in generated/ are used. Refresh those with: python3 tools/gen_metal.py generated
set -euo pipefail
INSTALL=1
[ "${1:-}" = "--no-install" ] && INSTALL=0
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build/ShaderMix.saver"
RES="$OUT/Contents/Resources/shaders"
rm -rf "$HERE/build"
mkdir -p "$OUT/Contents/MacOS" "$RES"
cp "$HERE/Info.plist" "$OUT/Contents/Info.plist"
if command -v glslangValidator >/dev/null && command -v spirv-cross >/dev/null; then
  python3 "$HERE/tools/gen_metal.py" "$RES"
else
  echo "glslang/spirv-cross not found: using pre-translated shaders from generated/"
  cp "$HERE/generated/"*.metal "$RES/"
fi
cp "$HERE/shaders/manifest.json" "$HERE/shaders/"*.excerpt.glsl "$HERE/textures/"* "$RES/"
for arch in arm64 x86_64; do
  xcrun -sdk macosx swiftc -O -module-name ShaderMix \
    -target "$arch-apple-macos13.0" \
    -emit-library -Xlinker -bundle \
    -framework ScreenSaver -framework Metal -framework MetalKit -framework Cocoa -framework QuartzCore \
    -o "$HERE/build/ShaderMix-$arch" "$HERE/ShaderMixView.swift" "$HERE/../../common/CodeText.swift"
done
lipo -create "$HERE/build/ShaderMix-arm64" "$HERE/build/ShaderMix-x86_64" -output "$OUT/Contents/MacOS/ShaderMix"
codesign --force --sign - "$OUT"
[ "$INSTALL" = 1 ] || { echo "Built: $OUT"; exit 0; }
mkdir -p "$HOME/Library/Screen Savers"
rm -rf "$HOME/Library/Screen Savers/ShaderMix.saver"
cp -R "$OUT" "$HOME/Library/Screen Savers/"
echo "Installed: $HOME/Library/Screen Savers/ShaderMix.saver"
