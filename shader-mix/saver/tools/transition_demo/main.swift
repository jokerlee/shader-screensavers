// Renders a transition between two shaders with Shader Mix's own composite shader (code overlay
// off) into PNG frames, for the README animations.
// usage: transition_demo <saver dir> <keyA> <keyB> <mode 0 fade|1 dissolve|2 radial|3 clock> <width> <height> <out dir>
// Timeline at 15 fps: 0.5 s of A, 2 s transition, 0.5 s of B.
import Foundation
import Metal
import MetalKit

let a = CommandLine.arguments
let dir = URL(fileURLWithPath: a[1])
let (keyA, keyB, mode) = (a[2], a[3], Int32(a[4])!)
let (W, H) = (Int(a[5])!, Int(a[6])!)
let out = URL(fileURLWithPath: a[7])

let dev = MTLCreateSystemDefaultDevice()!
let q = dev.makeCommandQueue()!
let mixLib = try! dev.makeLibrary(source: compositeSource, options: nil)
let vfn = mixLib.makeFunction(name: "mix_vmain")!

func pipeline(_ frag: MTLFunction) -> MTLRenderPipelineState {
    let pd = MTLRenderPipelineDescriptor()
    pd.vertexFunction = vfn
    pd.fragmentFunction = frag
    pd.colorAttachments[0].pixelFormat = .bgra8Unorm
    return try! dev.makeRenderPipelineState(descriptor: pd)
}

let manifest = try! JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("shaders/manifest.json"))) as! [[String: Any]]
let loader = MTKTextureLoader(device: dev)
func shader(_ key: String) -> (MTLRenderPipelineState, [MTLTexture]) {
    let src = try! String(contentsOf: dir.appendingPathComponent("generated/\(key).metal"), encoding: .utf8)
    let opts = MTLCompileOptions()
    opts.mathMode = .fast
    let lib = try! dev.makeLibrary(source: src, options: opts)
    let channels = (manifest.first { $0["key"] as? String == key }?["channels"] as? [String: String]) ?? [:]
    let tex = channels.keys.sorted().map {
        try! loader.newTexture(URL: dir.appendingPathComponent("textures/\(channels[$0]!)"), options: [
            .origin: MTKTextureLoader.Origin.bottomLeft, .SRGB: false, .generateMipmaps: true,
            .textureStorageMode: MTLStorageMode.private.rawValue])
    }
    return (pipeline(lib.makeFunction(name: "main0")!), tex)
}
let (pa, ta) = shader(keyA), (pb, tb) = shader(keyB)
let composite = pipeline(mixLib.makeFunction(name: "mix_composite")!)

func texture(_ w: Int, _ h: Int, _ fmt: MTLPixelFormat = .bgra8Unorm, shared: Bool = false) -> MTLTexture {
    let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: fmt, width: w, height: h, mipmapped: false)
    td.usage = [.renderTarget, .shaderRead]
    td.storageMode = shared ? .shared : .private
    return dev.makeTexture(descriptor: td)!
}
let A = texture(W, H), B = texture(W, H), outTex = texture(W, H, shared: true)
let blank = texture(1, 1, .r8Unorm), backdrop = texture(1, 1, .rgba16Float)
let sd = MTLSamplerDescriptor()
sd.sAddressMode = .repeat; sd.tAddressMode = .repeat
sd.minFilter = .linear; sd.magFilter = .linear; sd.mipFilter = .linear
let sampler = dev.makeSamplerState(descriptor: sd)!

func draw(_ pso: MTLRenderPipelineState, _ tex: [MTLTexture], into target: MTLTexture, time: Float, cmd: MTLCommandBuffer) {
    let rpd = MTLRenderPassDescriptor()
    rpd.colorAttachments[0].texture = target
    rpd.colorAttachments[0].loadAction = .dontCare
    rpd.colorAttachments[0].storeAction = .store
    let e = cmd.makeRenderCommandEncoder(descriptor: rpd)!
    var u = [Float](repeating: 0, count: 48)   // std140 ST block, see tools/gen_metal.py
    u[0] = Float(W); u[1] = Float(H); u[2] = 1; u[3] = time; u[12] = 1 / 15; u[14] = 15
    for i in 0..<4 {
        let t = i < tex.count ? tex[i] : blank
        u[16 + i * 4] = Float(t.width); u[17 + i * 4] = Float(t.height); u[18 + i * 4] = 1
        e.setFragmentTexture(t, index: i)
        e.setFragmentSamplerState(sampler, index: i)
    }
    e.setRenderPipelineState(pso)
    e.setFragmentBytes(u, length: u.count * 4, index: 0)
    e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    e.endEncoding()
}

struct MixU { var viewSize: SIMD2<Float>; var progress: Float; var mode: Int32; var seed: Float
              var textAlpha: Float; var halo: Float; var blend: Float; var textRect: SIMD4<Float> }

try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let fps = 15, frames = 45
for i in 0..<frames {
    let t = Float(i) / Float(fps)
    let p = min(max((t - 0.5) / 2, 0), 1)
    let cmd = q.makeCommandBuffer()!
    draw(pa, ta, into: A, time: 12 + t, cmd: cmd)
    draw(pb, tb, into: B, time: 12 + t, cmd: cmd)
    let rpd = MTLRenderPassDescriptor()
    rpd.colorAttachments[0].texture = outTex
    rpd.colorAttachments[0].loadAction = .dontCare
    rpd.colorAttachments[0].storeAction = .store
    let e = cmd.makeRenderCommandEncoder(descriptor: rpd)!
    var mu = MixU(viewSize: SIMD2(Float(W), Float(H)), progress: p, mode: mode, seed: 0.37,
                  textAlpha: 0, halo: 0, blend: 1, textRect: SIMD4(0, 0, 1, 1))
    e.setRenderPipelineState(composite)
    e.setFragmentTexture(A, index: 0); e.setFragmentTexture(B, index: 1)
    e.setFragmentTexture(backdrop, index: 2); e.setFragmentTexture(blank, index: 3)
    e.setFragmentSamplerState(sampler, index: 0)
    e.setFragmentBytes(&mu, length: MemoryLayout<MixU>.stride, index: 0)
    e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    e.endEncoding()
    cmd.commit(); cmd.waitUntilCompleted()
    var px = [UInt8](repeating: 0, count: W * H * 4)
    outTex.getBytes(&px, bytesPerRow: W * 4, from: MTLRegionMake2D(0, 0, W, H), mipmapLevel: 0)
    let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    let d = CGImageDestinationCreateWithURL(out.appendingPathComponent(String(format: "f%03d.png", i)) as CFURL,
                                            "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(d)
}
print("wrote \(frames) frames to \(out.path)")
