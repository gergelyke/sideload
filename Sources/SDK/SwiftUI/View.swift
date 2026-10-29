@_exported import Foundation
internal import SideloadRender

/// A piece of your app's UI. Every view must have a `body` made of other
/// views, bottoming out in a primitive this SDK implements directly
/// (`Text`, `Image`, `VStack`, `HStack`, ...).
@MainActor @preconcurrency
public protocol View {
    associatedtype Body: View

    @ViewBuilder var body: Body { get }
}

extension Never: View, Scene {
    public typealias Body = Never
    public var body: Never { return fatalError("Never has no body") }
}

/// A view this SDK can lay out and draw directly, without resolving a
/// `.body`. Implemented only by internal types; conforming types declare
/// `Body = Never` since their `body` is never called.
protocol _ResolvableView {
    @MainActor func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode
}

/// A view whose building-block result flattens into its parent's sibling
/// list instead of becoming one more child (an empty `ViewBuilder` block,
/// or several statements collected into one `TupleView`).
protocol _ChildrenProviding {
    @MainActor var _children: [any View] { get }
}

/// Resolves any view to a `LayoutNode`: primitives answer directly,
/// everything else is unwrapped through `.body` until a primitive is
/// reached. `_openBody` relies on Swift opening the `any View` existential
/// to call the generic overload for its dynamic type.
@MainActor
func _resolveLayout(_ view: any View, environment: _Environment, services: _RenderServices) -> LayoutNode {
    if let resolvable = view as? _ResolvableView {
        return resolvable._makeLayoutNode(environment: environment, services: services)
    }
    let body = _openBody(view)
    return _resolveLayout(body, environment: environment, services: services)
}

@MainActor
func _openBody<V: View>(_ v: V) -> any View {
    v.body
}

@MainActor
func _flattenChildren(_ view: any View) -> [any View] {
    if let providing = view as? _ChildrenProviding {
        return providing._children
    }
    return [view]
}

public struct EmptyView: View, _ResolvableView, _ChildrenProviding {
    public init() {}
    public var body: Never { fatalError() }

    var _children: [any View] { [] }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        EmptyLayoutNode()
    }
}

struct EmptyLayoutNode: LayoutNode {
    func sizeThatFits(_ proposal: ProposedSize) -> CGSize { .zero }
    func place(in rect: CGRect) -> RenderNode { .group(offset: Point(x: 0, y: 0), children: []) }
}

public struct TupleView<each Content: View>: View, _ResolvableView, _ChildrenProviding {
    public var value: (repeat each Content)

    public init(_ value: repeat each Content) {
        self.value = (repeat each value)
    }

    public var body: Never { fatalError() }

    var _children: [any View] {
        var result: [any View] = []
        repeat result.append(each value)
        return result
    }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        // A bare TupleView (not inside a container that flattens it) lays
        // its children out as a vertical stack with no spacing — this
        // only happens if a TupleView escapes to the top level, which the
        // MVP's own views never do.
        let nodes = _children.map { _resolveLayout($0, environment: environment, services: services) }
        return StackLayoutNode(axis: .vertical, spacing: 0, children: nodes)
    }
}

public struct _ConditionalContent<TrueContent: View, FalseContent: View>: View, _ResolvableView {
    enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }
    let storage: Storage

    public var body: Never { fatalError() }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        switch storage {
        case .trueContent(let content):
            return _resolveLayout(content, environment: environment, services: services)
        case .falseContent(let content):
            return _resolveLayout(content, environment: environment, services: services)
        }
    }
}

extension Optional: View, _ResolvableView, _ChildrenProviding where Wrapped: View {
    public var body: Never { fatalError() }

    var _children: [any View] {
        switch self {
        case .some(let view): return [view]
        case .none: return []
        }
    }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        switch self {
        case .some(let view): return _resolveLayout(view, environment: environment, services: services)
        case .none: return EmptyLayoutNode()
        }
    }
}

@resultBuilder
@MainActor
public struct ViewBuilder {
    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildBlock<Content: View>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<repeat each Content> {
        TupleView(repeat each content)
    }

    public static func buildIf<Content: View>(_ content: Content?) -> Content? {
        content
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .trueContent(first))
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .falseContent(second))
    }
}
