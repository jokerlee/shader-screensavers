# Shader Mix screen saver

Plays Shadertoy shaders in random order with transitions and shows a short excerpt of each
one's code, with title, author and license. Personal use only; every shader belongs to its author.

| key | shader | author | license | default |
|---|---|---|---|---|
| `flowingwires` | [Flowing Wires](https://www.shadertoy.com/view/DsBczR) | kishimisu | CC BY-NC-SA 4.0 | on |
| `starship` | [Starship](https://www.shadertoy.com/view/l3cfW4) | Xor | CC BY-NC-SA 3.0 (Shadertoy default) | on |
| `fractalpyramid` | [fractal pyramid](https://www.shadertoy.com/view/tsXBzS) | bradjamesgrant | CC BY-NC-SA 3.0 (Shadertoy default) | on |
| `simplicity` | [Simplicity](https://www.shadertoy.com/view/lslGWr) | JoshP | CC BY-NC-SA 3.0 (Shadertoy default) | on |
| `singularity` | [Singularity](https://www.shadertoy.com/view/3csSWB) | Xor | CC BY-NC-SA 3.0 (Shadertoy default) | on |
| `ether` | [Ether](https://www.shadertoy.com/view/MsjSW3) | nimitz | CC BY-NC-SA 3.0 | on |
| `colorfulinfinity` | [Path to the colorful infinity](https://www.shadertoy.com/view/WtjyzR) | benoitM | CC BY-NC-SA 3.0 | on |
| `balatroswirl` | [Balatro Background Shaders](https://www.shadertoy.com/view/XXtBRr) | xxidbr9, original LocalThunk | personal use only | on |
| `spiraliris` | [Shader_240422-4](https://openprocessing.org/sketch/2247937) | SamuelYAN | CC BY-NC-SA | on |
| `membrane` | [untitled 2026_0203_3](https://openprocessing.org/sketch/2862539) | SamuelYAN | CC BY-NC-SA | on |
| `motes` | [2026_0131](https://openprocessing.org/sketch/2860882) | SamuelYAN | CC BY-NC-SA | on |
| `hiddenline` | [GENUARY 2026_0120](https://openprocessing.org/sketch/2851315) | SamuelYAN | CC BY-NC-SA | on |
| `apollonian4d` | [Yet Another 4D Apollonian](https://www.shadertoy.com/view/N3VXz1) | mrange | CC0 | on |

## Files

- `shaders/<key>.glsl` — Shadertoy `mainImage` source that gets compiled. Verbatim originals, except
  `flowingwires` (macro/comma-expression code rewritten as a function for SPIR-V, same math),
  `colorfulinfinity` (`o/dot(o,o)` → `o*(1./dot(o,o))`, same output, ~8x faster) and
  `balatroswirl` (the game's parameters plus a `mainImage` wrapper), and the four OpenProcessing
  p5.js shaders (`spiraliris`, `membrane`, `motes`, `hiddenline`), wrapped as `mainImage` with p5's
  pixelDensity-2 coordinates and a cover zoom so their portrait compositions fill a landscape screen.
- `shaders/<key>.excerpt.glsl` — the lines shown on screen, verbatim from the original.
- `shaders/manifest.json` — titles, credits, textures. `textures/` — Starship's iChannel0 image from Shadertoy.
- `tools/make_sources.py` — one-off: wrote the `.glsl` files and manifest from `candidates/src` (and the manifest entries for the OpenProcessing shaders, whose sources come from `candidates/xhs/glsl`).
- `tools/transition_demo/` — renders a transition offline with the real composite shader (the README animations).
- `tools/gen_metal.py` — GLSL → SPIR-V → Metal (glslang + SPIRV-Cross), run by `build.sh`; `generated/` holds its output for builds without those tools.
- `ShaderMixView.swift`, `Info.plist`, `build.sh`, `configure.sh`.

Building needs only the Command Line Tools (`xcode-select --install`). With `brew install glslang spirv-cross` the GLSL is re-translated on each build; without them the pre-translated `generated/*.metal` are used. `build.sh` makes a universal (arm64 + x86_64) bundle; `package.sh` zips it into `../../dist/ShaderMix.zip` (not versioned; attach it to a GitHub release).

## Parameters (`Info.plist` → `ShaderMixDefaults`)

| key | default | meaning |
|---|---|---|
| `shaders` | all thirteen above | comma-separated keys to play |
| `segmentSeconds` | 20 | how long each shader plays |
| `transitionSeconds` | 2 | transition length; the code text fades out in the first half and in during the second |
| `transitions` | `fade,dissolve,radial,clock` | transitions to pick from at random |
| `startTimeJitter` | 30 | each segment starts its shader at a random time in [0, 30) s |
| `framesPerSecond` | 30 | frame rate cap |
| `renderScale` / `maxRenderPixels` | 1 / 2073600 | shader resolution: pixels per point, capped at 1920×1080 per screen (the final picture and text are native resolution) |
| `showCode` | true | code overlay on/off |
| `codeOpacity` | 0.9 | text opacity |
| `codeHalo` | 0.85 | strength of the dark outline/halo around the text (it gets stronger over bright areas) |
| `codeScale` | 1.0 | text size multiplier (code ~1/80 of the screen height, title 2.7x) |
| `logStats` | false | log fps and GPU time every 10 s and per transition |

```bash
./configure.sh                                   # current values, available shaders and transitions
./configure.sh segmentSeconds 45
./configure.sh shaders flowingwires,singularity,colorfulinfinity,balatroswirl
./configure.sh transitions dissolve,radial
./configure.sh showCode false
```

## How it renders

Each screen has its own playlist. Per frame: the current shader (and the next one during a
transition) renders into an offscreen target at the capped resolution; a tiny pass keeps a
low-resolution, time-smoothed copy of the picture; the final pass at native resolution upscales the
shader output, applies the transition, and draws the text from a mask rasterised once per shader.

Text: a large title, an author/link/licence line and the code excerpt, bottom-left. All enabled
shaders share one font size and one text area sized for the longest excerpt, with the title at its
top, so the title and first code line never move between shaders. The ink is always light; its
dark outline and halo are driven by the smoothed copy of the picture, faint over dark areas and
strong over bright ones. On a transition the old text fades out in the first half, the new text in
during the second.
