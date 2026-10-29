internal import SideloadRender

/// The ambient state view modifiers change for their content: current
/// font, foreground color, and image scale. Not public API — real
/// SwiftUI's `Environment`/`EnvironmentValues` is much larger; the MVP
/// only needs these three.
struct _Environment {
    var font: Font = .body
    var foregroundColor: RGBA = .black
    var imageScale: Image.Scale = .medium
    var tint: RGBA = RGBA(red: 0 / 255, green: 122 / 255, blue: 255 / 255)
}

/// Shared services layout and drawing need but that don't belong in the
/// environment (they're per-process, not per-subtree).
struct _RenderServices {
    var textMeasurer: TextMeasurer
    var symbolLibrary: SymbolLibrary
}
