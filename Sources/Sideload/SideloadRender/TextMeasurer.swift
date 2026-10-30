/// The result of shaping one run of text in one font: positioned glyphs plus
/// the metrics needed to lay it out without re-shaping.
public struct ShapedRun: Sendable, Equatable {
    public var glyphs: [PositionedGlyph]
    public var advanceWidth: Double
    public var ascent: Double
    public var descent: Double

    public init(glyphs: [PositionedGlyph], advanceWidth: Double, ascent: Double, descent: Double) {
        self.glyphs = glyphs
        self.advanceWidth = advanceWidth
        self.ascent = ascent
        self.descent = descent
    }
}

/// Shapes a single line of text in a given font. Implementations may cache
/// runs by (string, font).
@MainActor
public protocol TextMeasurer {
    func shape(_ text: String, font: FontSpec) -> ShapedRun
}
