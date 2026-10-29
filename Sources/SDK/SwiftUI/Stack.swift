import Foundation
internal import SideloadRender

public struct HorizontalAlignment: Sendable, Equatable {
    public static let leading = HorizontalAlignment()
    public static let center = HorizontalAlignment()
    public static let trailing = HorizontalAlignment()
}

public struct VerticalAlignment: Sendable, Equatable {
    public static let top = VerticalAlignment()
    public static let center = VerticalAlignment()
    public static let bottom = VerticalAlignment()
}

enum _StackAxis {
    case horizontal
    case vertical
}

public struct VStack<Content: View>: View, _ResolvableView {
    let alignment: HorizontalAlignment
    let spacing: Double?
    let content: Content

    public init(alignment: HorizontalAlignment = .center, spacing: Double? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError() }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        let children = _flattenChildren(content)
        let nodes = children.map { _resolveLayout($0, environment: environment, services: services) }
        return StackLayoutNode(axis: .vertical, spacing: spacing ?? 8, children: nodes)
    }
}

public struct HStack<Content: View>: View, _ResolvableView {
    let alignment: VerticalAlignment
    let spacing: Double?
    let content: Content

    public init(alignment: VerticalAlignment = .center, spacing: Double? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError() }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        let children = _flattenChildren(content)
        let nodes = children.map { _resolveLayout($0, environment: environment, services: services) }
        return StackLayoutNode(axis: .horizontal, spacing: spacing ?? 8, children: nodes)
    }
}

/// Recorded in Docs/known-differences.md: always centers children on the
/// cross axis, ignoring `alignment` — leading/trailing/top/bottom
/// alignment is a post-MVP improvement.
struct StackLayoutNode: LayoutNode {
    let axis: _StackAxis
    let spacing: Double
    let children: [LayoutNode]

    func sizeThatFits(_ proposal: ProposedSize) -> CGSize {
        let sizes = children.map { $0.sizeThatFits(proposal) }
        let gap = spacing * Double(max(children.count - 1, 0))
        switch axis {
        case .vertical:
            let width = sizes.map(\.width).max() ?? 0
            let height = sizes.map(\.height).reduce(0, +) + gap
            return CGSize(width: width, height: height)
        case .horizontal:
            let height = sizes.map(\.height).max() ?? 0
            let width = sizes.map(\.width).reduce(0, +) + gap
            return CGSize(width: width, height: height)
        }
    }

    func place(in rect: CGRect) -> RenderNode {
        let proposal = ProposedSize(width: rect.width, height: rect.height)
        let sizes = children.map { $0.sizeThatFits(proposal) }
        var nodes: [RenderNode] = []
        var offset: Double = 0

        switch axis {
        case .vertical:
            let maxWidth = sizes.map(\.width).max() ?? 0
            for (child, size) in zip(children, sizes) {
                let x = (maxWidth - size.width) / 2
                let childRect = CGRect(x: x, y: offset, width: size.width, height: size.height)
                nodes.append(child.place(in: childRect))
                offset += size.height + spacing
            }
        case .horizontal:
            let maxHeight = sizes.map(\.height).max() ?? 0
            for (child, size) in zip(children, sizes) {
                let y = (maxHeight - size.height) / 2
                let childRect = CGRect(x: offset, y: y, width: size.width, height: size.height)
                nodes.append(child.place(in: childRect))
                offset += size.width + spacing
            }
        }

        return .group(offset: Point(x: Double(rect.minX), y: Double(rect.minY)), children: nodes)
    }
}
