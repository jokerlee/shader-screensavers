#!/bin/bash
# Build and install ShaderMix.saver into ~/Library/Screen Savers.
# Needs glslangValidator and spirv-cross (brew install glslang spirv-cross) to translate the
# Shadertoy GLSL in shaders/ to Metal.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build/ShaderMix.saver"
RES="$OUT/Contents/Resources/shaders"
for t in glslangValidator spirv-cross; do
  command -v $t >/dev/null || { echo "missing $t: brew install glslang spirv-cross" >&2; exit 1; }
done
rm -rf "$HERE/build"
mkdir -p "$OUT/Contents/MacOS" "$RES"
cp "$HERE/Info.plist" "$OUT/Contents/Info.plist"
python3 "$HERE/tools/gen_metal.py" "$RES"
cp "$HERE/shaders/manifest.json" "$HERE/shaders/"*.excerpt.glsl "$HERE/textures/"* "$RES/"
xcrun -sdk macosx swiftc -O -module-name ShaderMix \
  -target arm64-apple-macos13.0 \
  -emit-library -Xlinker -bundle \
  -framework ScreenSaver -framework Metal -framework MetalKit -framework Cocoa -framework QuartzCore \
  -o "$OUT/Contents/MacOS/ShaderMix" "$HERE/ShaderMixView.swift" "$HERE/../../common/CodeText.swift"
codesign --force --sign - "$OUT"
mkdir -p "$HOME/Library/Screen Savers"
rm -rf "$HOME/Library/Screen Savers/ShaderMix.saver"
cp -R "$OUT" "$HOME/Library/Screen Savers/"
echo "Installed: $HOME/Library/Screen Savers/ShaderMix.saver"
