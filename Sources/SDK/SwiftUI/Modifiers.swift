import Foundation
internal import SideloadRender

public enum Edge: Sendable {
    case top, leading, bottom, trailing

    public struct Set: Sendable, OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let top = Set(rawValue: 1 << 0)
        public static let leading = Set(rawValue: 1 << 1)
        public static let bottom = Set(rawValue: 1 << 2)
        public static let trailing = Set(rawValue: 1 << 3)
        public static let horizontal: Set = [.leading, .trailing]
        public static let vertical: Set = [.top, .bottom]
        public static let all: Set = [.top, .leading, .bottom, .trailing]
    }
}

extension View {
    public func padding() -> some View {
        _PaddingView(content: self, edges: .all, amount: 16)
    }

    public func padding(_ length: Double) -> some View {
        _PaddingView(content: self, edges: .all, amount: length)
    }

    public func padding(_ edges: Edge.Set, _ length: Double? = nil) -> some View {
        _PaddingView(content: self, edges: edges, amount: length ?? 16)
    }

    public func imageScale(_ scale: Image.Scale) -> some View {
        _EnvironmentModifier(content: self) { environment in
            environment.imageScale = scale
        }
    }

    public func foregroundStyle(_ style: some ShapeStyle) -> some View {
        _EnvironmentModifier(content: self) { environment in
            environment.foregroundColor = _resolveShapeStyle(style, environment: environment)
        }
    }

    public func font(_ font: Font) -> some View {
        _EnvironmentModifier(content: self) { environment in
            environment.font = font
        }
    }
}

struct _PaddingView<Content: View>: View, _ResolvableView {
    let content: Content
    let edges: Edge.Set
    let amount: Double

    public var body: Never { fatalError() }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        let child = _resolveLayout(content, environment: environment, services: services)
        return PaddingLayoutNode(child: child, edges: edges, amount: amount)
    }
}

struct PaddingLayoutNode: LayoutNode {
    let child: LayoutNode
    let edges: Edge.Set
    let amount: Double

    private var leading: Double { edges.contains(.leading) ? amount : 0 }
    private var trailing: Double { edges.contains(.trailing) ? amount : 0 }
    private var top: Double { edges.contains(.top) ? amount : 0 }
    private var bottom: Double { edges.contains(.bottom) ? amount : 0 }

    func sizeThatFits(_ proposal: ProposedSize) -> CGSize {
        let innerProposal = ProposedSize(
            width: proposal.width.map { max($0 - leading - trailing, 0) },
            height: proposal.height.map { max($0 - top - bottom, 0) }
        )
        let innerSize = child.sizeThatFits(innerProposal)
        return CGSize(width: innerSize.width + leading + trailing, height: innerSize.height + top + bottom)
    }

    func place(in rect: CGRect) -> RenderNode {
        let innerRect = CGRect(
            x: rect.minX + leading,
            y: rect.minY + top,
            width: max(rect.width - leading - trailing, 0),
            height: max(rect.height - top - bottom, 0)
        )
        return child.place(in: innerRect)
    }
}

struct _EnvironmentModifier<Content: View>: View, _ResolvableView {
    let content: Content
    let modify: (inout _Environment) -> Void

    public var body: Never { fatalError() }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        var modified = environment
        modify(&modified)
        return _resolveLayout(content, environment: modified, services: services)
    }
}
