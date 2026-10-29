# 小红书 MasterYeeeee（chayepei）笔记里的 shader 候选

2026-10-28 只读浏览 14 篇最新笔记。所有笔记都是视频、正文只有话题标签；作品出处印在视频片头。
多数是对 OpenProcessing 上 SamuelYAN（@samuelyan）作品的解析，代码公开，许可 CC BY-NC-SA。

GPU：M4 Pro，1920×1080，GLSL → SPIR-V → Metal（fast math），15 帧中位数。
OpenProcessing 的 p5.js 片元着色器转成 Shadertoy mainImage（`glsl/`），并按 p5 在 Retina 屏的 pixelDensity 2 换算坐标
（细胞那个按 1，与作者视频一致）。转换校验：同尺寸同时间与浏览器 WebGL 渲染原代码对比，7 个逐像素一致，
Dissolved dreams 因逐像素哈希噪点平均差 6/255（统计上一致）。

| 笔记 | 原作 | 作者 | 链接 | 许可 | 非空行数 | 1080p GPU | 描述 |
|---|---|---|---|---|---|---|---|
| 在对数螺线里盛放的液态虹彩 | Shader_240422-4 | SamuelYAN | https://openprocessing.org/sketch/2247937 | CC BY-NC-SA | 70 | 0.19 ms | 螺旋中心向外甩出的液态金属虹彩 |
| 光在细胞膜内起舞 | untitled 2026_0203_3 | SamuelYAN | https://openprocessing.org/sketch/2862539 | CC BY-NC-SA | 130 | 5.41 ms | 黑底上一个流动变色的细胞膜团块 |
| 当十六颗微尘在代码里彼此吸引 | 2026_0131 | SamuelYAN | https://openprocessing.org/sketch/2860882 | CC BY-NC-SA | 81 | 1.12 ms | 灰底上相互吸引融合的发光轮廓（元球） |
| （同上一组的另一版） | GENUARY 2026_0131 | SamuelYAN | https://openprocessing.org/sketch/2860834 | CC BY-NC-SA | 81 | 2.22 ms | 同一算法的彩色版 |
| 隐秘的一线 | GENUARY 2026_0120 | SamuelYAN | https://openprocessing.org/sketch/2851315 | CC BY-NC-SA | 134 | 3.53 ms | 绿灰底上的柔光球体与折射 |
| 溶解的梦 | Dissolved dreams（基于 Shader_240425-4） | @clustahgmailcom / SamuelYAN | https://openprocessing.org/sketch/2560753 | CC BY-NC-SA | 119 | 0.97 ms | 高饱和噪点色带，类似胶片溶解 |
| “四维之谜”——阿诺罗德罗曼分析法 | Yet Another 4D Apollonian | mrange | https://www.shadertoy.com/view/N3VXz1 | CC0 | 33 | 11.97 ms | 四维阿波罗尼分形的光线步进，星云般绚丽 |
| 如何写一段流光溢彩的着色器 | Shader_251111 | SamuelYAN | https://openprocessing.org/sketch/2788072 | CC BY-NC-SA | 90 | 32.61 ms | 12 盏体积聚光在流场烟尘里 |
| 着色器编程模拟细胞 | Shader_260501 | SamuelYAN | https://openprocessing.org/sketch/2930471 | CC BY-NC-SA | 76 | 112.06 ms | 显微镜下的细胞群（多阶 Voronoi） |

不是 shader 或没有公开源码的笔记：

| 笔记 | 出处 | 情况 |
|---|---|---|
| 天体仪的呼吸 | SamuelYAN, openprocessing.org/sketch/1611804 | p5.js 3D 线条绘制，不是片元着色器 |
| 几何构成：包豪斯流形… | @ngsm, openprocessing.org/sketch/2384491 | p5.js 2D 绘制，不是片元着色器 |
| 你的阳光玫瑰在转圈圈 | Ricky Retouch（艺术家作品） | 作者按效果反推实现，无公开源码 |
| 时间的十二种形状 | Benoit Böhnke 的装置 12:12（CreativeApplications 展览） | 实体装置，无源码 |
| 超燃！Fable5.5 制作四千年艺术史动画 | AI 动画 | 不是 shader |
| 2014～2024 作品 Showreel | 博主本人作品集 | 无源码 |

文件：`src/`（OpenProcessing API / Shadertoy 原始数据）、`glsl/`（转换后的 mainImage）、`metal/`、`thumbs/`、
`multi/`（t=5/20/45 秒各一张）、`reference/`（浏览器 WebGL 参照）、`frames/`（视频片头截帧）、`overview.jpg`。
