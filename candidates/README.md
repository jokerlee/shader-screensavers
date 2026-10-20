# Shadertoy 屏保候选（2026-10-20 实测）

源码：src/<ID>.json（Shadertoy 原始 JSON）；缩略图：thumbs/（未入库，可用 tools/bench2.swift 重新生成）；总览：overview.jpg（按 GPU 耗时排序）。
GPU 耗时：本机 M4 Pro，1920×1080，经 glslang + SPIRV-Cross 转 Metal（fast math），15 帧中位数。用到 texture 的 shader 用随机噪声贴图代替原贴图，画面可能与原作不同。

| 名称 | 作者 | ID | 非空行数 | pass | 输入 | GPU ms | 许可 |
|---|---|---|---|---|---|---|---|
| Creation by Silexars | Danguafer | [XsXXDn](https://www.shadertoy.com/view/XsXXDn) | 19 | image | 无 | 0.12 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Cyber Fuji 2020 | kaiware007 | [Wt33Wf](https://www.shadertoy.com/view/Wt33Wf) | 137 | image | 无 | 0.17 | Shader License: CC BY 3.0 |
| Shader Art Coding Introduction | kishimisu | [mtyGWy](https://www.shadertoy.com/view/mtyGWy) | 30 | image | 无 | 0.17 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Tileable Water Caustic | Dave_Hoskins | [MdlXz8](https://www.shadertoy.com/view/MdlXz8) | 42 | image | 无 | 0.23 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Simplicity | JoshP | [lslGWr](https://www.shadertoy.com/view/lslGWr) | 25 | image | 无 | 0.58 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Singularity [381] | Xor | [3csSWB](https://www.shadertoy.com/view/3csSWB) | 61 | image | 无 | 0.79 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Ether | nimitz | [MsjSW3](https://www.shadertoy.com/view/MsjSW3) | 25 | image | 无 | 0.86 | License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unpo |
| Mandelbrot - smooth | iq | [4df3Rn](https://www.shadertoy.com/view/4df3Rn) | 72 | image | 无 | 1.03 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Flowing Wires [471 chars] | kishimisu | [DsBczR](https://www.shadertoy.com/view/DsBczR) | 22 | image | 无 | ~1.1 (浏览器估算) | This work is licensed under a Creative Commons Attribution-NonCommerci |
| Warping - procedural 2 | iq | [lsl3RH](https://www.shadertoy.com/view/lsl3RH) | 98 | image | 无 | 1.19 | Copyright Inigo Quilez, 2013 - https://iquilezles.org |
| Cosmic [256 Chars] | Xor | [msjXRK](https://www.shadertoy.com/view/msjXRK) | 48 | image | 无 | 2.09 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Fractal Land | Kali | [XsBXWt](https://www.shadertoy.com/view/XsBXWt) | 185 | image+sound | texture,music | 2.57 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Starship [320] | Xor | [l3cfW4](https://www.shadertoy.com/view/l3cfW4) | 91 | image | texture | 2.65 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| 2D Clouds | drift | [4tdSWr](https://www.shadertoy.com/view/4tdSWr) | 94 | image | 无 | 2.80 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Star Nest | Kali | [XlfGRj](https://www.shadertoy.com/view/XlfGRj) | 55 | image | 无 | 2.85 | License: MIT |
| fractal pyramid | bradjamesgrant | [tsXBzS](https://www.shadertoy.com/view/tsXBzS) | 57 | image | 无 | 4.54 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Enter The Matrix [399 chars] | kishimisu | [cl3XRX](https://www.shadertoy.com/view/cl3XRX) | 46 | image | texture | 5.16 | This work is licensed under a Creative Commons Attribution-NonCommerci |
| Accretion [312] | Xor | [WcKXDV](https://www.shadertoy.com/view/WcKXDV) | 32 | image | 无 | 5.42 | 未声明（Shadertoy 默认 CC BY-NC-SA 3.0） |
| Seascape | TDM | [Ms2SD1](https://www.shadertoy.com/view/Ms2SD1) | 179 | image | 无 | 5.54 | License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unpo |
| Plasma Globe | nimitz | [XsjXRm](https://www.shadertoy.com/view/XsjXRm) | 172 | image | texture | 8.32 | License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unpo |
| Auroras | nimitz | [XtGGRt](https://www.shadertoy.com/view/XtGGRt) | 138 | image | 无 | 8.34 | License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unpo |
| Flame | XT95 | [MdX3zr](https://www.shadertoy.com/view/MdX3zr) | 55 | image | 无 | 21.40 | License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unpo |
| Protean clouds | nimitz | [3l23Rh](https://www.shadertoy.com/view/3l23Rh) | 121 | image | 无 | 50.20 | License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unpo |
