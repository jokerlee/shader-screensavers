// Shared by the ColorfulInfinity, BalatroSwirl and ShaderMix screen savers (compiled into each
// bundle): the bottom-left code overlay — a large title, an author/link/licence line and a code
// excerpt — rasterised once into a mipmapped coverage mask and drawn on the GPU. The ink is always
// light; its dark outline and halo follow a low-resolution, time-smoothed copy of the picture
// (faint over dark areas, strong over bright ones), so the text never turns into a mid grey.

import Cocoa
import Metal

struct CodeCredits {
    let title: String
    let author: String
    let link: String
    let license: String
}

/// Overlay text rasterised once into an R8 coverage mask (mipmapped: the halo samples blurred levels).
struct CodeTextMask {
    let texture: MTLTexture
    let size: CGSize      // pixels
    let topPad: CGFloat   // pixels between the texture's top edge and the top of the title

    /// Title (2.7x the code size, bold), author/link/licence line, blank line, excerpt.
    static func text(_ c: CodeCredits, excerpt: String, size: CGFloat) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.lineHeightMultiple = 1.08
        let titlePara = NSMutableParagraphStyle()
        titlePara.paragraphSpacing = size * 0.15
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: c.title + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: size * 2.7, weight: .bold), .kern: -size * 0.03,
            .foregroundColor: NSColor.white, .paragraphStyle: titlePara]))
        s.append(NSAttributedString(string: "by \(c.author) · \(c.link) · \(c.license)\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: size * 0.95, weight: .medium),
            .foregroundColor: NSColor(white: 1, alpha: 0.75), .paragraphStyle: para]))
        s.append(NSAttributedString(string: excerpt.trimmingCharacters(in: .whitespacesAndNewlines), attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular),
            .foregroundColor: NSColor.white, .paragraphStyle: para]))
        return s
    }

    static func measure(_ str: NSAttributedString) -> CGSize {
        str.boundingRect(with: NSSize(width: 100_000, height: 100_000), options: [.usesLineFragmentOrigin]).size
    }

    static func make(_ c: CodeCredits, excerpt: String, size: CGFloat, scale: CGFloat,
                     device: MTLDevice, queue: MTLCommandQueue) -> CodeTextMask? {
        let str = text(c, excerpt: excerpt, size: size)
        let box = measure(str)
        let pad = size * 0.8   // room for the halo
        let w = Int(ceil((box.width + pad * 2) * scale)), h = Int(ceil((box.height + pad * 2) * scale))
        guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                                space: CGColorSpaceCreateDeviceGray(),
                                                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        str.draw(with: NSRect(x: pad, y: pad, width: box.width + 1, height: box.height + 1), options: [.usesLineFragmentOrigin])
        NSGraphicsContext.restoreGraphicsState()
        guard let data = ctx.data else { return nil }

        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: w, height: h, mipmapped: true)
        td.usage = .shaderRead
        guard let tex = device.makeTexture(descriptor: td) else { return nil }
        // bitmap memory is top row first, like a Metal texture
        tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: data, bytesPerRow: ctx.bytesPerRow)
        if let cb = queue.makeCommandBuffer(), let blit = cb.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: tex)
            blit.endEncoding()
            cb.commit()
        }
        return CodeTextMask(texture: tex, size: CGSize(width: w, height: h), topPad: pad * scale)
    }
}

/// One layout for every excerpt a screen may show: a common font size and a fixed text area tall
/// enough for the longest excerpt, anchored bottom-left, with the title at its top. Neither the
/// title nor the first code line moves when the excerpt changes.
struct CodeTextLayout {
    let viewSize: CGSize
    let size: CGFloat     // code font size, points
    let areaTop: CGFloat  // pixels from the top of the view
    let left: CGFloat     // pixels

    static func compute(_ entries: [(CodeCredits, String)], viewSize: CGSize, scale: CGFloat,
                        codeScale: CGFloat, isPreview: Bool) -> CodeTextLayout {
        let ptsW = viewSize.width / scale, ptsH = viewSize.height / scale
        let margin = ptsH * 0.035
        // code ~1/80 of the screen height (14pt on a 1117pt MacBook); everything shrinks together
        // if the widest or tallest excerpt does not fit 66% x 40% of the screen
        let base = max(isPreview ? 1 : 9, min(26, ptsH * 0.0125 * codeScale))
        let boxes = entries.map { CodeTextMask.measure(CodeTextMask.text($0.0, excerpt: $0.1, size: base)) }
        let maxW = boxes.map(\.width).max() ?? 1, maxH = boxes.map(\.height).max() ?? 1
        let fit = min(1, ptsW * 0.66 / maxW, ptsH * 0.4 / maxH)
        let size = fit < 1 ? max(isPreview ? 1 : 7, (base * fit * 0.98).rounded(.down)) : base
        let areaH = maxH * size / base
        return CodeTextLayout(viewSize: viewSize, size: size,
                              areaTop: (ptsH - margin - areaH) * scale, left: margin * scale)
    }

    /// Placement of a mask in view pixels (x, y from the top-left, width, height).
    func rect(for mask: CodeTextMask?) -> SIMD4<Float> {
        guard let mask else { return SIMD4(0, 0, 1, 1) }
        return SIMD4(Float(left - mask.topPad), Float(areaTop - mask.topPad),
                     Float(mask.size.width), Float(mask.size.height))
    }
}

/// Metal source for the text shading; included by every composite shader that draws the overlay.
let codeTextMSL = """
// col: picture colour at this pixel; pixel: view pixel; bg: smoothed backdrop colour here;
// rect: mask placement (x, y from the top-left, w, h); alpha: fade; halo: outline strength.
static float3 shadeCodeText(float3 col, float2 pixel, float3 bg, float4 rect, float alpha, float halo,
                            texture2d<float> text, sampler s)
{
    if (alpha <= 0.0) return col;
    float2 tuv = (pixel - rect.xy) / rect.zw;
    if (any(tuv < 0.0) || any(tuv > 1.0)) return col;
    float glyph = text.sample(s, tuv, level(0.0)).r;
    float edge = saturate(text.sample(s, tuv, level(1.0)).r * 3.0);   // tight outline
    float glow = saturate(text.sample(s, tuv, level(2.5)).r * 4.0);   // soft halo

    float lum = dot(min(bg, 1.0), float3(0.2126, 0.7152, 0.0722));
    float bright = smoothstep(0.15, 0.65, lum);
    float3 comp = 1.0 - min(bg, 1.0);                           // complementary tone of the area
    comp /= max(max(comp.r, comp.g), max(comp.b, 1e-3));
    float3 ink = mix(float3(1.0), comp, 0.12 * (1.0 - bright));  // slight tint on dark areas only
    float shade = max(edge * mix(0.35, 0.9, bright), glow * mix(0.3, 0.75, bright)) * halo;

    col = mix(col, col * 0.08, shade * alpha);
    return mix(col, ink, glyph * alpha);
}
"""

/// For the single-shader savers: takes the frame rendered into an offscreen `scene` texture,
/// keeps the smoothed backdrop, and draws scene + code text into the (native resolution) drawable.
final class SceneCompositor {
    private struct U {
        var viewSize: SIMD2<Float>
        var textAlpha: Float
        var halo: Float
        var textRect: SIMD4<Float>
    }

    private let backdropPipeline: MTLRenderPipelineState
    private let compositePipeline: MTLRenderPipelineState
    private let linear: MTLSamplerState
    private let nearest: MTLSamplerState
    private let blank: MTLTexture
    private var backdrop: MTLTexture?
    private var fresh = true

    init(device: MTLDevice) throws {
        let lib = try device.makeLibrary(source: Self.source, options: nil)
        let v = lib.makeFunction(name: "sc_vmain")!
        let bd = MTLRenderPipelineDescriptor()
        bd.vertexFunction = v
        bd.fragmentFunction = lib.makeFunction(name: "sc_backdrop")
        bd.colorAttachments[0].pixelFormat = .rgba16Float
        // exponential moving average with the blend colour's alpha as the factor
        bd.colorAttachments[0].isBlendingEnabled = true
        bd.colorAttachments[0].sourceRGBBlendFactor = .blendAlpha
        bd.colorAttachments[0].destinationRGBBlendFactor = .oneMinusBlendAlpha
        bd.colorAttachments[0].sourceAlphaBlendFactor = .one
        bd.colorAttachments[0].destinationAlphaBlendFactor = .zero
        backdropPipeline = try device.makeRenderPipelineState(descriptor: bd)
        let cd = MTLRenderPipelineDescriptor()
        cd.vertexFunction = v
        cd.fragmentFunction = lib.makeFunction(name: "sc_composite")
        cd.colorAttachments[0].pixelFormat = .bgra8Unorm
        compositePipeline = try device.makeRenderPipelineState(descriptor: cd)
        let sd = MTLSamplerDescriptor()
        sd.sAddressMode = .clampToEdge; sd.tAddressMode = .clampToEdge
        sd.minFilter = .linear; sd.magFilter = .linear; sd.mipFilter = .linear
        linear = device.makeSamplerState(descriptor: sd)!
        sd.minFilter = .nearest; sd.magFilter = .nearest
        nearest = device.makeSamplerState(descriptor: sd)!
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 1, height: 1, mipmapped: false)
        blank = device.makeTexture(descriptor: td)!
        blank.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: [UInt8(0)], bytesPerRow: 1)
    }

    /// `pixelated`: upscale the scene with nearest filtering (crisp blocks) instead of linear.
    func encode(scene: MTLTexture, cmd: MTLCommandBuffer, into rpd: MTLRenderPassDescriptor, viewSize: CGSize,
                mask: CodeTextMask?, layout: CodeTextLayout?, textAlpha: Float, halo: Float, pixelated: Bool) {
        let bw = max(1, scene.width / 16), bh = max(1, scene.height / 16)
        if backdrop?.width != bw || backdrop?.height != bh {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: bw, height: bh, mipmapped: false)
            td.usage = [.renderTarget, .shaderRead]
            td.storageMode = .private
            backdrop = scene.device.makeTexture(descriptor: td)
            fresh = true
        }
        guard let backdrop else { return }
        var u = U(viewSize: SIMD2(Float(bw), Float(bh)), textAlpha: mask == nil ? 0 : textAlpha, halo: halo,
                  textRect: layout?.rect(for: mask) ?? SIMD4(0, 0, 1, 1))
        if u.textAlpha > 0 {
            let bp = MTLRenderPassDescriptor()
            bp.colorAttachments[0].texture = backdrop
            bp.colorAttachments[0].loadAction = fresh ? .clear : .load
            bp.colorAttachments[0].storeAction = .store
            if let e = cmd.makeRenderCommandEncoder(descriptor: bp) {
                e.setRenderPipelineState(backdropPipeline)
                e.setBlendColor(red: 0, green: 0, blue: 0, alpha: fresh ? 1 : 0.12)
                e.setFragmentTexture(scene, index: 0)
                e.setFragmentSamplerState(linear, index: 0)
                e.setFragmentBytes(&u, length: MemoryLayout<U>.stride, index: 0)
                e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                e.endEncoding()
            }
            fresh = false
        }
        rpd.colorAttachments[0].loadAction = .dontCare
        guard let e = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }
        u.viewSize = SIMD2(Float(viewSize.width), Float(viewSize.height))
        e.setRenderPipelineState(compositePipeline)
        e.setFragmentTexture(scene, index: 0)
        e.setFragmentTexture(backdrop, index: 1)
        e.setFragmentTexture(mask?.texture ?? blank, index: 2)
        e.setFragmentSamplerState(pixelated ? nearest : linear, index: 0)
        e.setFragmentSamplerState(linear, index: 1)
        e.setFragmentBytes(&u, length: MemoryLayout<U>.stride, index: 0)
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        e.endEncoding()
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct VOut { float4 pos [[position]]; };
    vertex VOut sc_vmain(uint vid [[vertex_id]])
    {
        float2 p = float2((vid << 1) & 2, vid & 2);
        VOut o;
        o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
        return o;
    }
    struct U { float2 viewSize; float textAlpha; float halo; float4 textRect; };
    \(codeTextMSL)
    // low-resolution copy of the scene: 4x4 taps per texel
    fragment float4 sc_backdrop(VOut in [[stage_in]], texture2d<float> scene [[texture(0)]],
                                sampler s [[sampler(0)]], constant U &u [[buffer(0)]])
    {
        float3 sum = 0.0;
        for (int j = 0; j < 4; j++)
            for (int i = 0; i < 4; i++)
                sum += scene.sample(s, (in.pos.xy + (float2(i, j) + 0.5) / 4.0 - 0.5) / u.viewSize).rgb;
        return float4(sum / 16.0, 1.0);
    }
    fragment float4 sc_composite(VOut in [[stage_in]], texture2d<float> scene [[texture(0)]],
                                 texture2d<float> backdrop [[texture(1)]], texture2d<float> text [[texture(2)]],
                                 sampler s [[sampler(0)]], sampler ls [[sampler(1)]], constant U &u [[buffer(0)]])
    {
        float2 uv = in.pos.xy / u.viewSize;
        float3 col = scene.sample(s, uv).rgb;
        col = shadeCodeText(col, in.pos.xy, backdrop.sample(ls, uv).rgb, u.textRect, u.textAlpha, u.halo, text, ls);
        return float4(col, 1.0);
    }
    """
}
