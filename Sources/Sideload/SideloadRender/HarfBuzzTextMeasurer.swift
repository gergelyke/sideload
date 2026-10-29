import CFreeType
import CHarfBuzz

/// Shapes text with HarfBuzz against FreeType faces from a `FontLibrary`,
/// caching shaped runs by (string, font).
@MainActor
public final class HarfBuzzTextMeasurer: TextMeasurer {
    private let fontLibrary: FontLibrary
    private var cache: [CacheKey: ShapedRun] = [:]

    private struct CacheKey: Hashable {
        let text: String
        let font: FontSpec
    }

    public init(fontLibrary: FontLibrary) {
        self.fontLibrary = fontLibrary
    }

    public func shape(_ text: String, font: FontSpec) -> ShapedRun {
        let key = CacheKey(text: text, font: font)
        if let cached = cache[key] { return cached }
        let run = Self.shapeUncached(text, font: font, fontLibrary: fontLibrary)
        cache[key] = run
        return run
    }

    private static func shapeUncached(_ text: String, font: FontSpec, fontLibrary: FontLibrary) -> ShapedRun {
        guard let ftFace = try? fontLibrary.face(weight: font.weight, sizeInPoints: font.size) else {
            return ShapedRun(glyphs: [], advanceWidth: 0, ascent: font.size * 0.8, descent: font.size * 0.2)
        }
        guard let hbFont = hb_ft_font_create_referenced(ftFace) else {
            return ShapedRun(glyphs: [], advanceWidth: 0, ascent: 0, descent: 0)
        }
        defer { hb_font_destroy(hbFont) }

        guard let buffer = hb_buffer_create() else {
            return ShapedRun(glyphs: [], advanceWidth: 0, ascent: 0, descent: 0)
        }
        defer { hb_buffer_destroy(buffer) }

        let utf8Length = Int32(text.utf8.count)
        hb_buffer_add_utf8(buffer, text, utf8Length, 0, utf8Length)
        hb_buffer_guess_segment_properties(buffer)
        hb_shape(hbFont, buffer, nil, 0)

        var glyphCount: UInt32 = 0
        let infos = hb_buffer_get_glyph_infos(buffer, &glyphCount)
        var posCount: UInt32 = 0
        let positions = hb_buffer_get_glyph_positions(buffer, &posCount)

        var glyphs: [PositionedGlyph] = []
        var penX: Double = 0
        var penY: Double = 0
        if let infos, let positions {
            for i in 0..<Int(glyphCount) {
                let info = infos[i]
                let pos = positions[i]
                let x = penX + Double(pos.x_offset) / 64.0
                let y = penY - Double(pos.y_offset) / 64.0
                glyphs.append(PositionedGlyph(glyphID: info.codepoint, x: x, y: y))
                penX += Double(pos.x_advance) / 64.0
                penY += Double(pos.y_advance) / 64.0
            }
        }

        let metrics = ftFace.pointee.size.pointee.metrics
        let ascent = Double(metrics.ascender) / 64.0
        let descent = -Double(metrics.descender) / 64.0

        return ShapedRun(glyphs: glyphs, advanceWidth: penX, ascent: ascent, descent: descent)
    }
}
