// ShaderMix: a screen saver that plays a set of Shadertoy shaders in random order with
// transitions, showing a short excerpt of each one's source. Shaders are compiled to Metal at
// build time (tools/gen_metal.py); see README.md for the list, credits and licenses.
// Personal use only.
//
// Frame structure: the current (and, during a transition, the next) shader renders into an
// offscreen target capped at maxRenderPixels; a tiny pass keeps a time-smoothed, low-resolution
// copy of the picture; the final pass upscales the shader output to the native drawable, applies
// the transition and draws the code text from a pre-rendered mask, coloured against that copy
// (dark text with a light halo on bright areas, light text with a dark halo on dark areas).
//
// Tunables (Info.plist dict "ShaderMixDefaults", change with ./configure.sh):
//   shaders            comma-separated keys from manifest.json to play
//   segmentSeconds     time each shader plays before the next transition (20)
//   transitionSeconds  transition length (2)
//   transitions        comma-separated subset of fade,dissolve,radial,clock (one picked at random)
//   startTimeJitter    each segment starts its shader at a random iTime in [0, jitter) seconds
//   framesPerSecond / renderScale / maxRenderPixels   30 / 1 px per point / 1920*1080 per screen
//   showCode / codeOpacity / codeHalo / codeScale     code overlay
//   logStats           NSLog GPU time and fps every 10 s and per transition

import Cocoa
import Metal
import MetalKit
import QuartzCore
import ScreenSaver

// MARK: - Settings

private struct Settings {
    var shaders: [String]
    var segmentSeconds: Double
    var transitionSeconds: Double
    var transitions: [Int32]
    var startTimeJitter: Double
    var framesPerSecond: Int
    var renderScale: CGFloat
    var maxRenderPixels: CGFloat
    var showCode: Bool
    var codeOpacity: Float
    var codeHalo: Float
    var codeScale: CGFloat
    var logStats: Bool

    static let transitionNames = ["fade", "dissolve", "radial", "clock"]

    static func load(bundle: Bundle) -> Settings {
        let id = bundle.bundleIdentifier ?? "local.forest.screensaver.shadermix"
        let d: UserDefaults = ScreenSaverDefaults(forModuleWithName: id) ?? .standard
        if let base = bundle.object(forInfoDictionaryKey: "ShaderMixDefaults") as? [String: Any] {
            d.register(defaults: base)
        }
        func num(_ k: String, _ def: Double) -> Double { (d.object(forKey: k) as? NSNumber)?.doubleValue ?? def }
        func flag(_ k: String, _ def: Bool) -> Bool { (d.object(forKey: k) as? NSNumber)?.boolValue ?? def }
        func list(_ k: String, _ def: String) -> [String] {
            (d.string(forKey: k) ?? def).split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        }
        var transitions = list("transitions", "fade,dissolve,radial,clock").compactMap { name -> Int32? in
            guard let i = transitionNames.firstIndex(of: name) else {
                NSLog("ShaderMix: unknown transition %@ ignored", name)
                return nil
            }
            return Int32(i)
        }
        if transitions.isEmpty { transitions = [0] }
        return Settings(
            shaders: list("shaders", "flowingwires,starship,fractalpyramid,simplicity,singularity,ether,colorfulinfinity,balatroswirl"),
            segmentSeconds: max(num("segmentSeconds", 20), 3),
            transitionSeconds: min(max(num("transitionSeconds", 2), 0.1), 20),
            transitions: transitions,
            startTimeJitter: max(num("startTimeJitter", 30), 0),
            framesPerSecond: Int(min(max(num("framesPerSecond", 30), 1), 120)),
            renderScale: CGFloat(min(max(num("renderScale", 1), 0.1), 4)),
            maxRenderPixels: CGFloat(max(num("maxRenderPixels", 1920 * 1080), 64 * 64)),
            showCode: flag("showCode", true),
            codeOpacity: Float(min(max(num("codeOpacity", 0.9), 0), 1)),
            codeHalo: Float(min(max(num("codeHalo", 0.85), 0), 1)),
            codeScale: CGFloat(min(max(num("codeScale", 1), 0.3), 3)),
            logStats: flag("logStats", false))
    }
}

// MARK: - Shader catalogue (shared by all screens in the process)

private struct ShaderInfo: Decodable {
    let key: String
    let title: String
    let author: String
    let license: String
    let link: String
    let channels: [String: String]
}

private final class ShaderProgram {
    let info: ShaderInfo
    let excerpt: String
    var pipeline: MTLRenderPipelineState?
    var textures: [MTLTexture] = []
    init(info: ShaderInfo, excerpt: String) { self.info = info; self.excerpt = excerpt }
    var credits: CodeCredits { CodeCredits(title: info.title, author: info.author, link: info.link, license: info.license) }
}

/// Compiles shaders asynchronously once per process; every screen's view reads from here.
private final class Catalogue {
    static var shared: Catalogue?

    let device: MTLDevice
    let programs: [String: ShaderProgram]
    let compositePipeline: MTLRenderPipelineState
    let backdropPipeline: MTLRenderPipelineState
    let vertexFunction: MTLFunction
    let fallbackTexture: MTLTexture
    let channelSampler: MTLSamplerState
    let linearSampler: MTLSamplerState

    static func get(device: MTLDevice, bundle: Bundle, keys: [String]) -> Catalogue? {
        if let c = shared, c.device === device { return c }
        do {
            let c = try Catalogue(device: device, bundle: bundle, keys: keys)
            shared = c
            return c
        } catch {
            NSLog("ShaderMix: setup failed: \(error)")
            return nil
        }
    }

    private init(device: MTLDevice, bundle: Bundle, keys: [String]) throws {
        self.device = device
        guard let res = bundle.resourceURL?.appendingPathComponent("shaders") else {
            throw NSError(domain: "ShaderMix", code: 1, userInfo: [NSLocalizedDescriptionKey: "no resources"])
        }
        let infos = try JSONDecoder().decode([ShaderInfo].self,
                                             from: Data(contentsOf: res.appendingPathComponent("manifest.json")))
        let lib = try device.makeLibrary(source: compositeSource, options: nil)
        vertexFunction = lib.makeFunction(name: "mix_vmain")!
        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction = vertexFunction
        pd.fragmentFunction = lib.makeFunction(name: "mix_composite")
        pd.colorAttachments[0].pixelFormat = .bgra8Unorm
        compositePipeline = try device.makeRenderPipelineState(descriptor: pd)
        // The backdrop is blended into its previous contents with a constant factor
        // (exponential moving average), which smooths the text colour over time.
        let bd = MTLRenderPipelineDescriptor()
        bd.vertexFunction = vertexFunction
        bd.fragmentFunction = lib.makeFunction(name: "mix_backdrop")
        bd.colorAttachments[0].pixelFormat = .rgba16Float
        bd.colorAttachments[0].isBlendingEnabled = true
        bd.colorAttachments[0].sourceRGBBlendFactor = .blendAlpha
        bd.colorAttachments[0].destinationRGBBlendFactor = .oneMinusBlendAlpha
        bd.colorAttachments[0].sourceAlphaBlendFactor = .one
        bd.colorAttachments[0].destinationAlphaBlendFactor = .zero
        backdropPipeline = try device.makeRenderPipelineState(descriptor: bd)

        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        fallbackTexture = device.makeTexture(descriptor: td)!
        fallbackTexture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: [UInt8](repeating: 0, count: 4), bytesPerRow: 4)
        let sd = MTLSamplerDescriptor()
        sd.sAddressMode = .repeat; sd.tAddressMode = .repeat
        sd.minFilter = .linear; sd.magFilter = .linear; sd.mipFilter = .linear
        channelSampler = device.makeSamplerState(descriptor: sd)!
        sd.sAddressMode = .clampToEdge; sd.tAddressMode = .clampToEdge
        linearSampler = device.makeSamplerState(descriptor: sd)!

        var programs: [String: ShaderProgram] = [:]
        let loader = MTKTextureLoader(device: device)
        for info in infos where keys.contains(info.key) {
            let excerpt: String
            do {
                excerpt = try String(contentsOf: res.appendingPathComponent("\(info.key).excerpt.glsl"), encoding: .utf8)
            } catch {
                NSLog("ShaderMix: missing code excerpt for %@: %@", info.key, "\(error)")
                excerpt = ""
            }
            let p = ShaderProgram(info: info, excerpt: excerpt)
            // Shadertoy textures: vertically flipped, linear (non-sRGB), mipmapped, repeat.
            for ch in info.channels.keys.sorted() {
                do {
                    let tex = try loader.newTexture(URL: res.appendingPathComponent(info.channels[ch]!), options: [
                        .origin: MTKTextureLoader.Origin.bottomLeft, .SRGB: false, .generateMipmaps: true,
                        .textureStorageMode: MTLStorageMode.private.rawValue])
                    p.textures.append(tex)
                } catch {
                    NSLog("ShaderMix: texture %@ for %@ failed: %@", info.channels[ch]!, info.key, "\(error)")
                }
            }
            programs[info.key] = p
        }
        for k in keys where programs[k] == nil { NSLog("ShaderMix: unknown shader key %@ ignored", k) }
        self.programs = programs
        for p in programs.values { compile(p, url: res.appendingPathComponent("\(p.info.key).metal")) }
    }

    private func compile(_ p: ShaderProgram, url: URL) {
        let source: String
        do { source = try String(contentsOf: url, encoding: .utf8) } catch {
            NSLog("ShaderMix: cannot read %@: %@", url.lastPathComponent, "\(error)")
            return
        }
        let opts = MTLCompileOptions()
        if #available(macOS 15.0, *) { opts.mathMode = .fast } else { opts.fastMathEnabled = true }
        let vf = vertexFunction
        device.makeLibrary(source: source, options: opts) { [device] lib, error in
            guard let lib, let frag = lib.makeFunction(name: "main0") else {
                NSLog("ShaderMix: %@ failed to compile: %@", p.info.key, "\(String(describing: error))")
                return
            }
            let pd = MTLRenderPipelineDescriptor()
            pd.vertexFunction = vf
            pd.fragmentFunction = frag
            pd.colorAttachments[0].pixelFormat = .bgra8Unorm
            device.makeRenderPipelineState(descriptor: pd) { pso, error in
                guard let pso else {
                    NSLog("ShaderMix: %@ pipeline failed: %@", p.info.key, "\(String(describing: error))")
                    return
                }
                DispatchQueue.main.async { p.pipeline = pso }
            }
        }
    }
}

// also used by tools/transition_demo
let compositeSource = """
#include <metal_stdlib>
using namespace metal;

struct VOut { float4 pos [[position]]; };

vertex VOut mix_vmain(uint vid [[vertex_id]])
{
    float2 p = float2((vid << 1) & 2, vid & 2);
    VOut o;
    o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return o;
}

struct MixU {
    float2 viewSize;   // pixels of the pass being drawn
    float progress;    // 0 = only A, >0 transition towards B
    int mode;          // 0 fade, 1 dissolve, 2 radial, 3 clock
    float seed;
    float textAlpha;   // code overlay fade (0 = hidden)
    float halo;        // halo strength
    float blend;       // backdrop smoothing factor
    float4 textRect;   // x, y (top-left origin), width, height in view pixels
};

static float hash(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
static float vnoise(float2 p)
{
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + float2(1, 0)), u.x), mix(hash(i + float2(0, 1)), hash(i + 1.0), u.x), u.y);
}

\(codeTextMSL)

// progress-driven soft threshold: 0 = all A, 1 = all B, edge width w
static float sweep(float field, float p, float w) { return smoothstep(field - w, field + w, p * (1.0 + 2.0 * w) - w); }

// weight of B at uv (0..1, top-left origin); glow marks the moving seam
static float transitionWeight(float2 uv, constant MixU &u, thread float &glow)
{
    glow = 0.0;
    float p = u.progress;
    if (p <= 0.0) return 0.0;
    float aspect = u.viewSize.x / u.viewSize.y;
    float2 c = (uv - 0.5) * float2(aspect, 1.0);
    float m;
    if (u.mode == 1) {          // noise dissolve with a glowing seam
        float2 q = c * 5.0 + u.seed * 17.0;
        float n = 0.55 * vnoise(q) + 0.3 * vnoise(q * 2.1) + 0.15 * vnoise(q * 4.3);
        m = sweep(n, p, 0.06);
        glow = m * (1.0 - m) * 4.0;
    } else if (u.mode == 2) {   // circle opening from the centre
        float maxR = length(float2(aspect, 1.0)) * 0.5;
        m = sweep(length(c) / maxR, p, 0.08);
        glow = m * (1.0 - m) * 2.0;
    } else if (u.mode == 3) {   // clock wipe starting at 12 o'clock
        float ang = fract(atan2(c.x, c.y) / 6.2831853 + 1.0);
        m = sweep(ang, p, 0.04);
        glow = m * (1.0 - m) * 2.0;
    } else {                    // cross fade
        m = smoothstep(0.0, 1.0, p);
    }
    return m;
}

static float3 scene(float2 uv, texture2d<float> a, texture2d<float> b, sampler s, constant MixU &u)
{
    float3 ca = a.sample(s, uv).rgb;
    if (u.progress <= 0.0) return ca;
    float glow;
    float m = transitionWeight(uv, u, glow);
    float3 cb = b.sample(s, uv).rgb;
    return mix(ca, cb, m) + glow * 0.35 * (cb + 0.15);
}

// Low-resolution, time-smoothed copy of the picture: 4x4 taps per texel, blended into the
// previous contents with blend colour alpha = u.blend.
fragment float4 mix_backdrop(VOut in [[stage_in]],
                             texture2d<float> a [[texture(0)]], texture2d<float> b [[texture(1)]],
                             sampler s [[sampler(0)]], constant MixU &u [[buffer(0)]])
{
    float3 sum = 0.0;
    for (int j = 0; j < 4; j++)
        for (int i = 0; i < 4; i++) {
            float2 uv = (in.pos.xy + (float2(i, j) + 0.5) / 4.0 - 0.5) / u.viewSize;
            sum += scene(uv, a, b, s, u);
        }
    return float4(sum / 16.0, 1.0);
}

fragment float4 mix_composite(VOut in [[stage_in]],
                              texture2d<float> a [[texture(0)]], texture2d<float> b [[texture(1)]],
                              texture2d<float> backdrop [[texture(2)]], texture2d<float> text [[texture(3)]],
                              sampler s [[sampler(0)]], constant MixU &u [[buffer(0)]])
{
    float2 uv = in.pos.xy / u.viewSize;
    float3 col = scene(uv, a, b, s, u);
    col = shadeCodeText(col, in.pos.xy, backdrop.sample(s, uv).rgb, u.textRect, u.textAlpha, u.halo, text, s);
    return float4(col, 1.0);
}
"""

// MARK: - View

@objc(ShaderMixView)
final class ShaderMixView: ScreenSaverView, MTKViewDelegate {
    private struct Playing {
        let program: ShaderProgram
        let start: CFTimeInterval   // wall time the segment started
        let timeOffset: Double      // iTime at segment start
        var mask: CodeTextMask?
    }

    private struct MixUniforms {
        var viewSize: SIMD2<Float>
        var progress: Float
        var mode: Int32
        var seed: Float
        var textAlpha: Float
        var halo: Float
        var blend: Float
        var textRect: SIMD4<Float>
    }

    private let settings: Settings
    private var catalogue: Catalogue?
    private var mtkView: MTKView?
    private var queue: MTLCommandQueue?
    private var targets: [MTLTexture] = []
    private var backdrop: MTLTexture?
    private var backdropFresh = false
    private var current: Playing?
    private var next: Playing?
    private var firstShown: CFTimeInterval = 0
    private var transitionStart: CFTimeInterval = 0
    private var transitionMode: Int32 = 0
    private var transitionSeed: Float = 0
    private var stopObserver: NSObjectProtocol?

    // logStats accumulators (GPU times arrive on a Metal completion thread)
    private let statsLock = NSLock()
    private var statFrames = 0, statGPU: Double = 0, statGPUMax: Double = 0
    private var statSince = CACurrentMediaTime()
    private var transFrames = 0, transGPU: Double = 0, transGPUMax: Double = 0

    override init?(frame: NSRect, isPreview: Bool) {
        settings = Settings.load(bundle: Bundle(for: ShaderMixView.self))
        super.init(frame: frame, isPreview: isPreview)
        setUp()
    }

    required init?(coder: NSCoder) {
        settings = Settings.load(bundle: Bundle(for: ShaderMixView.self))
        super.init(coder: coder)
        setUp()
    }

    deinit {
        if let o = stopObserver { DistributedNotificationCenter.default().removeObserver(o) }
    }

    private func setUp() {
        animationTimeInterval = 1.0 / Double(settings.framesPerSecond)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        guard let device = MTLCreateSystemDefaultDevice() else {
            NSLog("ShaderMix: no Metal device")
            return
        }
        catalogue = Catalogue.get(device: device, bundle: Bundle(for: ShaderMixView.self), keys: settings.shaders)
        queue = device.makeCommandQueue()

        // The drawable is native resolution (for sharp text); shaders render at a capped size.
        let v = MTKView(frame: bounds, device: device)
        v.autoresizingMask = [.width, .height]
        v.colorPixelFormat = .bgra8Unorm
        v.framebufferOnly = true
        v.preferredFramesPerSecond = settings.framesPerSecond
        v.isPaused = true
        v.enableSetNeedsDisplay = false
        v.delegate = self
        addSubview(v)
        mtkView = v

        // macOS 14+ keeps legacyScreenSaver alive after dismissal; stop rendering when told.
        stopObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.willstop"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.mtkView?.isPaused = true
        }
    }

    override func startAnimation() {
        super.startAnimation()
        mtkView?.isPaused = false
    }

    override func stopAnimation() {
        super.stopAnimation()
        mtkView?.isPaused = true
    }

    // MTKView drives drawing; nothing to do in the ScreenSaverView tick.
    override func animateOneFrame() {}

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // text masks are laid out for the old size; rebuild them
        if let c = catalogue, let queue {
            let cur = current?.program, nxt = next?.program
            current?.mask = makeMask(cur, viewSize: size, device: c.device, queue: queue)
            next?.mask = makeMask(nxt, viewSize: size, device: c.device, queue: queue)
        }
    }

    // MARK: Playlist

    private func readyPrograms() -> [ShaderProgram] {
        guard let c = catalogue else { return [] }
        return settings.shaders.compactMap { c.programs[$0] }.filter { $0.pipeline != nil }
    }

    private var textLayout: CodeTextLayout?

    /// One layout for all enabled shaders on this screen (see CodeTextLayout).
    private func layout(viewSize: CGSize) -> CodeTextLayout? {
        if let l = textLayout, l.viewSize == viewSize { return l }
        guard let c = catalogue, viewSize.width > 0 else { return nil }
        let entries = settings.shaders.compactMap { c.programs[$0] }.map { ($0.credits, $0.excerpt) }
        let l = CodeTextLayout.compute(entries, viewSize: viewSize, scale: backingScale(viewSize),
                                       codeScale: settings.codeScale, isPreview: isPreview)
        textLayout = l
        return l
    }

    private func backingScale(_ viewSize: CGSize) -> CGFloat {
        window?.backingScaleFactor ?? (bounds.width > 0 ? viewSize.width / bounds.width : 2)
    }

    private func makeMask(_ p: ShaderProgram?, viewSize: CGSize, device: MTLDevice, queue: MTLCommandQueue) -> CodeTextMask? {
        guard settings.showCode, let p, let l = layout(viewSize: viewSize) else { return nil }
        return CodeTextMask.make(p.credits, excerpt: p.excerpt, size: l.size, scale: backingScale(viewSize),
                                 device: device, queue: queue)
    }

    private func play(_ p: ShaderProgram, at now: CFTimeInterval, viewSize: CGSize,
                      device: MTLDevice, queue: MTLCommandQueue) -> Playing {
        Playing(program: p, start: now, timeOffset: Double.random(in: 0...settings.startTimeJitter),
                mask: makeMask(p, viewSize: viewSize, device: device, queue: queue))
    }

    private func advance(now: CFTimeInterval, viewSize: CGSize, device: MTLDevice, queue: MTLCommandQueue) {
        let ready = readyPrograms()
        guard let cur = current else {
            if let first = ready.randomElement() {
                current = play(first, at: now, viewSize: viewSize, device: device, queue: queue)
                firstShown = now
            }
            return
        }
        if let n = next {
            if now - transitionStart >= settings.transitionSeconds {
                current = Playing(program: n.program, start: transitionStart, timeOffset: n.timeOffset, mask: n.mask)
                next = nil
                targets.swapAt(0, 1)
                logTransition(from: cur.program.info.key, to: n.program.info.key)
            }
            return
        }
        guard now - cur.start >= settings.segmentSeconds else { return }
        let candidates = ready.filter { $0 !== cur.program }
        guard let pick = candidates.randomElement() else { return }
        next = play(pick, at: now, viewSize: viewSize, device: device, queue: queue)
        transitionStart = now
        transitionMode = settings.transitions.randomElement() ?? 0
        transitionSeed = Float.random(in: 0..<1)
    }

    // MARK: Rendering

    private func sceneSize(for view: MTKView) -> (Int, Int) {
        var w = bounds.width * settings.renderScale, h = bounds.height * settings.renderScale
        let px = w * h
        if px > settings.maxRenderPixels {
            let r = (settings.maxRenderPixels / px).squareRoot()
            w *= r; h *= r
        }
        return (max(1, Int(w.rounded())), max(1, Int(h.rounded())))
    }

    private func ensureTargets(_ w: Int, _ h: Int, device: MTLDevice) {
        if targets.count == 2, targets[0].width == w, targets[0].height == h { return }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        td.usage = [.renderTarget, .shaderRead]
        td.storageMode = .private
        targets = (0..<2).compactMap { _ in device.makeTexture(descriptor: td) }
        // backdrop: one texel per 16x16 scene pixels
        let bd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                                                          width: max(1, w / 16), height: max(1, h / 16), mipmapped: false)
        bd.usage = [.renderTarget, .shaderRead]
        bd.storageMode = .private
        backdrop = device.makeTexture(descriptor: bd)
        backdropFresh = true
    }

    private func encode(_ playing: Playing, into tex: MTLTexture, now: CFTimeInterval,
                        cmd: MTLCommandBuffer, catalogue c: Catalogue) {
        guard let pso = playing.program.pipeline else { return }
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = tex
        rpd.colorAttachments[0].loadAction = .dontCare
        rpd.colorAttachments[0].storeAction = .store
        guard let e = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }
        let t = Float(now - playing.start + playing.timeOffset)
        // std140 layout of the ST uniform block declared in tools/gen_metal.py (192 bytes)
        var u = [Float](repeating: 0, count: 48)
        u[0] = Float(tex.width); u[1] = Float(tex.height); u[2] = 1; u[3] = t
        let date = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        u[8] = Float(date.year ?? 0); u[9] = Float((date.month ?? 1) - 1); u[10] = Float(date.day ?? 1)
        u[11] = Float((date.hour ?? 0) * 3600 + (date.minute ?? 0) * 60 + (date.second ?? 0))
        u[12] = 1 / Float(settings.framesPerSecond)
        u.withUnsafeMutableBytes { $0.storeBytes(of: Int32(t * Float(settings.framesPerSecond)), toByteOffset: 52, as: Int32.self) }
        u[14] = Float(settings.framesPerSecond); u[15] = 44100
        for i in 0..<4 {
            let tx = i < playing.program.textures.count ? playing.program.textures[i] : c.fallbackTexture
            u[16 + i * 4] = Float(tx.width); u[17 + i * 4] = Float(tx.height); u[18 + i * 4] = 1
            e.setFragmentTexture(tx, index: i)
            e.setFragmentSamplerState(c.channelSampler, index: i)
        }
        e.setRenderPipelineState(pso)
        e.setFragmentBytes(u, length: u.count * 4, index: 0)
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        e.endEncoding()
    }

    /// Text fade: in over the whole transition time at start-up; during a transition the old
    /// text fades out in the first half and the new text fades in during the second half.
    private func textState(now: CFTimeInterval) -> (CodeTextMask?, Float) {
        let T = settings.transitionSeconds
        if let n = next {
            let p = Float((now - transitionStart) / T)
            return p < 0.5 ? (current?.mask, max(0, 1 - 2 * p)) : (n.mask, min(1, 2 * p - 1))
        }
        return (current?.mask, Float(min(1, (now - firstShown) / T)))
    }

    func draw(in view: MTKView) {
        guard let c = catalogue, let queue else { return }
        let now = CACurrentMediaTime()
        advance(now: now, viewSize: view.drawableSize, device: c.device, queue: queue)
        let (sw, sh) = sceneSize(for: view)
        ensureTargets(sw, sh, device: c.device)
        guard targets.count == 2, let backdrop,
              let rpd = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cmd = queue.makeCommandBuffer() else { return }

        var progress: Float = 0
        if let cur = current { encode(cur, into: targets[0], now: now, cmd: cmd, catalogue: c) }
        if let n = next {
            encode(n, into: targets[1], now: now, cmd: cmd, catalogue: c)
            progress = Float(min(max((now - transitionStart) / settings.transitionSeconds, 0.0001), 1))
        }
        let (mask, textFade) = textState(now: now)
        let viewSize = view.drawableSize
        let lay = layout(viewSize: viewSize)
        var mu = MixUniforms(
            viewSize: SIMD2(Float(backdrop.width), Float(backdrop.height)),
            progress: progress, mode: transitionMode, seed: transitionSeed,
            textAlpha: mask == nil ? 0 : textFade * settings.codeOpacity,
            halo: settings.codeHalo,
            blend: backdropFresh ? 1 : 0.12,
            textRect: lay?.rect(for: mask) ?? SIMD4(0, 0, 1, 1))

        if current != nil {
            // low-resolution, time-smoothed copy of the picture for the text colour
            let bp = MTLRenderPassDescriptor()
            bp.colorAttachments[0].texture = backdrop
            bp.colorAttachments[0].loadAction = backdropFresh ? .clear : .load
            bp.colorAttachments[0].storeAction = .store
            if let e = cmd.makeRenderCommandEncoder(descriptor: bp) {
                e.setRenderPipelineState(c.backdropPipeline)
                e.setBlendColor(red: 0, green: 0, blue: 0, alpha: mu.blend)
                e.setFragmentTexture(targets[0], index: 0)
                e.setFragmentTexture(targets[1], index: 1)
                e.setFragmentSamplerState(c.linearSampler, index: 0)
                e.setFragmentBytes(&mu, length: MemoryLayout<MixUniforms>.stride, index: 0)
                e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                e.endEncoding()
            }
            backdropFresh = false
        }

        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        guard let e = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }
        if current != nil {
            mu.viewSize = SIMD2(Float(viewSize.width), Float(viewSize.height))
            e.setRenderPipelineState(c.compositePipeline)
            e.setFragmentTexture(targets[0], index: 0)
            e.setFragmentTexture(targets[1], index: 1)
            e.setFragmentTexture(backdrop, index: 2)
            e.setFragmentTexture(mask?.texture ?? c.fallbackTexture, index: 3)
            e.setFragmentSamplerState(c.linearSampler, index: 0)
            e.setFragmentBytes(&mu, length: MemoryLayout<MixUniforms>.stride, index: 0)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        e.endEncoding()
        if settings.logStats {
            let inTransition = next != nil
            let key = current?.program.info.key ?? "-"
            let scene = CGSize(width: sw, height: sh)
            cmd.addCompletedHandler { [weak self] cb in
                self?.recordFrame(cb.gpuEndTime - cb.gpuStartTime, transition: inTransition, size: scene, key: key)
            }
        }
        cmd.present(drawable)
        cmd.commit()
    }

    // MARK: Stats

    private func recordFrame(_ gpu: Double, transition: Bool, size: CGSize, key: String) {
        statsLock.lock(); defer { statsLock.unlock() }
        statFrames += 1; statGPU += gpu; statGPUMax = max(statGPUMax, gpu)
        if transition { transFrames += 1; transGPU += gpu; transGPUMax = max(transGPUMax, gpu) }
        let now = CACurrentMediaTime()
        guard now - statSince >= 10 else { return }
        NSLog("ShaderMix: scene %dx%d px @ %.1f fps, GPU avg %.2f max %.2f ms (now: %@)",
              Int(size.width), Int(size.height), Double(statFrames) / (now - statSince),
              statGPU / Double(statFrames) * 1000, statGPUMax * 1000, key)
        statFrames = 0; statGPU = 0; statGPUMax = 0; statSince = now
    }

    private func logTransition(from: String, to: String) {
        guard settings.logStats else { return }
        statsLock.lock(); defer { statsLock.unlock() }
        guard transFrames > 0 else { return }
        NSLog("ShaderMix: transition %@ -> %@ (%@): %d frames, GPU avg %.2f max %.2f ms",
              from, to, Settings.transitionNames[Int(transitionMode)], transFrames,
              transGPU / Double(transFrames) * 1000, transGPUMax * 1000)
        transFrames = 0; transGPU = 0; transGPUMax = 0
    }
}
