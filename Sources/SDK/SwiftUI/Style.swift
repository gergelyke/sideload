import Foundation
internal import SideloadRender

public protocol ShapeStyle {}

public struct TintShapeStyle: ShapeStyle, Sendable {
    public init() {}
}

extension ShapeStyle where Self == TintShapeStyle {
    public static var tint: TintShapeStyle { TintShapeStyle() }
}

public struct Color: View, ShapeStyle, _ResolvableView, Sendable {
    let rgba: RGBA

    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.rgba = RGBA(red: red, green: green, blue: blue, alpha: opacity)
    }

    init(rgba: RGBA) {
        self.rgba = rgba
    }

    public static let primary = Color(rgba: .black)
    public static let blue = Color(rgba: RGBA(red: 0, green: 122.0 / 255.0, blue: 1))
    public static let red = Color(rgba: RGBA(red: 1, green: 0, blue: 0))
    public static let accentColor = Color(rgba: RGBA(red: 0, green: 122.0 / 255.0, blue: 1))

    public var body: Never { fatalError() }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        ColorLayoutNode(rgba: rgba)
    }
}

struct ColorLayoutNode: LayoutNode {
    let rgba: RGBA

    func sizeThatFits(_ proposal: ProposedSize) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func place(in rect: CGRect) -> RenderNode {
        .group(offset: Point(x: Double(rect.minX), y: Double(rect.minY)), children: [
            .fillRect(SRect(x: 0, y: 0, width: rect.width, height: rect.height), color: rgba),
        ])
    }
}

/// A named text style, resolved to a point size. Real SwiftUI's `Font` is
/// much larger (custom families, weights, Dynamic Type scaling); the MVP
/// only needs the three styles the fixture app uses.
public struct Font: Sendable, Equatable {
    enum Style: Sendable {
        case body, title, largeTitle
    }

    let style: Style

    public static let body = Font(style: .body)
    public static let title = Font(style: .title)
    public static let largeTitle = Font(style: .largeTitle)

    /// Recorded in Docs/known-differences.md.
    var pointSize: Double {
        switch style {
        case .body: return 17
        case .title: return 28
        case .largeTitle: return 34
        }
    }
}

func _resolveShapeStyle(_ style: any ShapeStyle, environment: _Environment) -> RGBA {
    if let color = style as? Color {
        return color.rgba
    }
    if style is TintShapeStyle {
        return environment.tint
    }
    return .black
}
