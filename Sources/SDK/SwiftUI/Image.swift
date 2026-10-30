import Foundation
internal import SideloadRender

public struct Image: View, _ResolvableView {
    public enum Scale: Sendable, Equatable {
        case small, medium, large

        /// Recorded in Docs/known-differences.md.
        var multiplier: Double {
            switch self {
            case .small: return 0.8
            case .medium: return 1.0
            case .large: return 1.3
            }
        }
    }

    let systemName: String

    public init(systemName: String) {
        self.systemName = systemName
    }

    public var body: Never { fatalError() }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        ImageLayoutNode(
            systemName: systemName,
            side: environment.font.pointSize * environment.imageScale.multiplier,
            color: environment.foregroundColor,
            symbolLibrary: services.symbolLibrary
        )
    }
}

struct ImageLayoutNode: LayoutNode {
    let systemName: String
    let side: Double
    let color: RGBA
    let symbolLibrary: SymbolLibrary

    func sizeThatFits(_ proposal: ProposedSize) -> CGSize {
        CGSize(width: side, height: side)
    }

    func place(in rect: CGRect) -> RenderNode {
        let symbol = symbolLibrary.symbol(named: systemName)
        let scaleFactor = symbol.viewBoxSize > 0 ? side / symbol.viewBoxSize : 1
        let scaledOps = symbol.ops.map { _scale($0, by: scaleFactor) }
        let strokeStyle = StrokeStyle(
            width: symbol.strokeStyle.width * scaleFactor,
            cap: symbol.strokeStyle.cap,
            join: symbol.strokeStyle.join
        )
        return .group(offset: Point(x: Double(rect.minX), y: Double(rect.minY)), children: [
            .path(scaledOps, fill: nil, stroke: color, style: strokeStyle),
        ])
    }
}

private func _scale(_ op: PathOp, by factor: Double) -> PathOp {
    func scalePoint(_ p: Point) -> Point { Point(x: p.x * factor, y: p.y * factor) }
    switch op {
    case .move(let p): return .move(scalePoint(p))
    case .line(let p): return .line(scalePoint(p))
    case .quad(let control, let end): return .quad(control: scalePoint(control), end: scalePoint(end))
    case .curve(let c1, let c2, let end): return .curve(control1: scalePoint(c1), control2: scalePoint(c2), end: scalePoint(end))
    case .close: return .close
    }
}
