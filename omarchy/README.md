# Shader Mix · Omarchy 版

和 macOS 版同一套播放逻辑，跑在 [Omarchy](https://omarchy.org)（Arch + Hyprland）上，替换 Omarchy 自带的终端文字屏保。

- 同样的 8 个 shader（直接用 `../shader-mix/saver/shaders/` 里的 GLSL 和 `manifest.json`），每段 20 秒、随机不连续重复，每个显示器各自随机。
- 同样的四种转场（fade / dissolve / radial / clock，约 2 秒）和左下角代码叠加（标题、作者/链接/许可、核心代码，描边随画面亮度自适应并在时间上平滑）。转场 shader 和文字着色是从 `ShaderMixView.swift`、`common/CodeText.swift` 逐行移植的。
- shader 渲染分辨率按每屏 1 像素/点、最多 1920×1080，30fps；文字按原生分辨率合成。
- 实现：一个 C 程序 `shadermix`（SDL3 + OpenGL ES 3.0 + FreeType），Wayland 原生全屏窗口。

## 安装

```bash
sudo pacman -S --needed sdl3 freetype2 jq imagemagick   # Omarchy 默认基本都已装好
./install.sh
```

`install.sh` 会：

1. 编译 `shadermix` 装到 `~/.local/bin/`。
2. 把 shader、Starship 用的纹理（转成 PPM）和播放列表放到 `~/.local/share/shadermix/`。
3. 在 `~/.bashrc` 顶部加一段带标记的 PATH，让 `~/.local/share/shadermix/bin/omarchy-launch-screensaver` 优先于系统自带的同名脚本。Omarchy 的 idle 服务是用 `bash -lc omarchy-launch-screensaver` 启动屏保的，所以空闲超时、菜单里的 Screensaver、`omarchy-launch-screensaver force` 都会走 Shader Mix。

卸载：`./install.sh --uninstall`（删掉上面这些文件和 `~/.bashrc` 里那段，恢复 Omarchy 自带屏保）。

## 和 Omarchy 的衔接

- 窗口的 app id 是 `org.omarchy.screensaver`，所以 Omarchy 自带的窗口规则（全屏、浮动）和 idle 服务的锁屏计时照常生效：屏保开着到 `idle.lock` 时间就锁屏，提前被关掉就取消锁屏。
- 按任意键、点鼠标、滚轮或移动鼠标就退出；任何一个屏的屏保退出时所有屏一起关。焦点被锁屏等其他窗口拿走时也会退出，不在锁屏后面空跑 GPU。
- 尊重 Omarchy 的 `screensaver-off` 开关（`force` 参数照样能强制启动）。
- 空闲多久启动：`~/.config/omarchy/shell.json` 里的 `idle.screensaver`（秒）。

## 预览与参数

```bash
omarchy-launch-screensaver force     # 立即全屏启动，和空闲触发完全一样
shadermix --windowed                 # 普通窗口，Esc 退出
shadermix --windowed --shaders ether,singularity --segment 8 --stats
```

| 参数 | 默认 | 说明 |
|---|---|---|
| `--shaders a,b,…` | 全部 8 个 | 只播这些 key |
| `--segment SEC` | 20 | 每个 shader 播多久 |
| `--transition SEC` | 2 | 转场时长 |
| `--transitions LIST` | `fade,dissolve,radial,clock` | 随机从中选 |
| `--jitter SEC` | 30 | 每段从 [0, SEC) 里随机一个 iTime 开始 |
| `--fps N` | 30 | 帧率上限 |
| `--max-pixels N` | 2073600 | 每屏 shader 渲染像素上限（1920×1080） |
| `--no-code` / `--code-scale X` | 显示 / 1 | 代码叠加开关和字号倍数 |
| `--stats` | 关 | 每 10 秒打印渲染尺寸和实际帧率 |

想让空闲屏保也用自定义参数，改 `~/.local/share/shadermix/bin/omarchy-launch-screensaver` 里调用 `shadermix` 的那行。

离线渲染一帧（不弹窗口，用来对比或截图）：

```bash
shadermix --shaders ether --jitter 0 --no-code --shot out.ppm --at 12 --size 480x270
```

## 移植说明

- Shadertoy 的 GLSL 原样包一层 `#version 300 es` 头（`iResolution`、`iTime`、`iChannel0..3` 等）后直接在 GL ES 上编译，不经过 Metal 版用的 SPIR-V 转换。
- Starship 和 Singularity 依赖局部变量默认为 0（WebGL 和 Metal 都这样），Mesa 默认不保证，所以程序启动时设置了 Mesa 的 `glsl_zero_init=true`。
- 和 `../shader-mix/reference/` 里浏览器渲染的原作在 iTime 12 和 27 秒对比，6 个有参考图的 shader 全部吻合（PSNR 55–80 dB）。
- 在 Intel Arc（Meteor Lake）笔记本上实测：3072×1920 屏，shader 按 1536×960 渲染，稳定 30fps，CPU 约 2%。
