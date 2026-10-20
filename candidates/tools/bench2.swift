// GPU timing + thumbnail for a SPIRV-Cross generated Shadertoy fragment (entry main0).
// usage: bench2 <shader.metal> <w> <h> <frames> <png-out> <thumbW> <thumbH> <time>
import Foundation
import Metal
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
let src = try! String(contentsOfFile: a[1], encoding: .utf8)
let w = Int(a[2])!, h = Int(a[3])!, frames = Int(a[4])!
let png = a[5], tw = Int(a[6])!, th = Int(a[7])!, snapT = Float(a[8])!

let dev = MTLCreateSystemDefaultDevice()!
let vsrc = """
#include <metal_stdlib>
using namespace metal;
struct VO { float4 pos [[position]]; };
vertex VO vmain(uint vid [[vertex_id]]) { float2 p = float2((vid << 1) & 2, vid & 2); VO o; o.pos = float4(p * 2.0 - 1.0, 0, 1); return o; }
"""
let vlib = try! dev.makeLibrary(source: vsrc, options: nil)
let opts = MTLCompileOptions()
opts.mathMode = .fast
let flib: MTLLibrary
do { flib = try dev.makeLibrary(source: src, options: opts) } catch { print("COMPILE_FAIL \(error)".prefix(300)); exit(1) }
let pd = MTLRenderPipelineDescriptor()
pd.vertexFunction = vlib.makeFunction(name: "vmain")
pd.fragmentFunction = flib.makeFunction(name: "main0")
pd.colorAttachments[0].pixelFormat = .bgra8Unorm
let pso = try! dev.makeRenderPipelineState(descriptor: pd)
let q = dev.makeCommandQueue()!

// 256x256 RGBA noise for shaders that read iChannelN
let N = 256
var noise = [UInt8](repeating: 0, count: N * N * 4)
var rng = SystemRandomNumberGenerator()
for i in 0..<noise.count { noise[i] = UInt8.random(in: 0...255, using: &rng) }
let ntd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: N, height: N, mipmapped: true)
let ntex = dev.makeTexture(descriptor: ntd)!
ntex.replace(region: MTLRegionMake2D(0, 0, N, N), mipmapLevel: 0, withBytes: noise, bytesPerRow: N * 4)
do { let cb = q.makeCommandBuffer()!; let b = cb.makeBlitCommandEncoder()!; b.generateMipmaps(for: ntex); b.endEncoding(); cb.commit(); cb.waitUntilCompleted() }
let sd = MTLSamplerDescriptor()
sd.sAddressMode = .repeat; sd.tAddressMode = .repeat
sd.minFilter = .linear; sd.magFilter = .linear; sd.mipFilter = .linear
let samp = dev.makeSamplerState(descriptor: sd)!

func target(_ tw: Int, _ th: Int) -> MTLTexture {
    let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: tw, height: th, mipmapped: false)
    td.usage = [.renderTarget, .shaderRead]; td.storageMode = .shared
    return dev.makeTexture(descriptor: td)!
}
let big = target(w, h), small = target(tw, th)

func render(_ tex: MTLTexture, _ t: Float) -> Double {
    var u = [Float](repeating: 0, count: 48) // 192 bytes, std140 layout of the ST block
    u[0] = Float(tex.width); u[1] = Float(tex.height); u[2] = 1; u[3] = t
    u[8] = 2026; u[9] = 9; u[10] = 20; u[11] = 36000
    u[12] = 1.0 / 30
    u.withUnsafeMutableBytes { $0.storeBytes(of: Int32(t * 30), toByteOffset: 52, as: Int32.self) }
    u[14] = 30; u[15] = 44100
    for c in 0..<4 { u[16 + c * 4] = Float(N); u[17 + c * 4] = Float(N); u[18 + c * 4] = 1 }
    let rpd = MTLRenderPassDescriptor()
    rpd.colorAttachments[0].texture = tex
    rpd.colorAttachments[0].loadAction = .dontCare
    rpd.colorAttachments[0].storeAction = .store
    let cb = q.makeCommandBuffer()!
    let e = cb.makeRenderCommandEncoder(descriptor: rpd)!
    e.setRenderPipelineState(pso)
    e.setFragmentBytes(u, length: u.count * 4, index: 0)
    for i in 0..<4 { e.setFragmentTexture(ntex, index: i); e.setFragmentSamplerState(samp, index: i) }
    e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    e.endEncoding()
    cb.commit(); cb.waitUntilCompleted()
    return (cb.gpuEndTime - cb.gpuStartTime) * 1000
}

_ = render(big, 1); _ = render(big, 1.5)
var ts: [Double] = []
for i in 0..<frames { ts.append(render(big, 2 + Float(i) / 30)) }
ts.sort()
print(String(format: "%.2f", ts[ts.count / 2]))

_ = render(small, snapT)
var bytes = [UInt8](repeating: 0, count: tw * th * 4)
small.getBytes(&bytes, bytesPerRow: tw * 4, from: MTLRegionMake2D(0, 0, tw, th), mipmapLevel: 0)
let ctx = CGContext(data: &bytes, width: tw, height: th, bitsPerComponent: 8, bytesPerRow: tw * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: png) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, ctx.makeImage()!, nil); CGImageDestinationFinalize(d)
