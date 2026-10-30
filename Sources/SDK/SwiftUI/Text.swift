import Foundation
internal import SideloadRender

public struct LocalizedStringKey: Sendable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, Equatable {
    let value: String

    public init(stringLiteral value: String) {
        self.value = value
    }

    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        var result = ""
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) {
            result += literal
        }
        public mutating func appendInterpolation<T>(_ value: T) {
            result += "\(value)"
        }
    }

    public init(stringInterpolation: StringInterpolation) {
        self.value = stringInterpolation.result
    }
}

public struct Text: View, _ResolvableView, Equatable {
    let storage: String

    public init(_ key: LocalizedStringKey) {
        self.storage = key.value
    }

    @_disfavoredOverload
    public init<S: StringProtocol>(_ content: S) {
        self.storage = String(content)
    }

    public init(verbatim content: String) {
        self.storage = content
    }

    public var body: Never { fatalError() }

    func _makeLayoutNode(environment: _Environment, services: _RenderServices) -> LayoutNode {
        TextLayoutNode(
            string: storage,
            font: FontSpec(size: environment.font.pointSize),
            color: environment.foregroundColor,
            measurer: services.textMeasurer
        )
    }
}

struct TextLayoutNode: LayoutNode {
    let string: String
    let font: FontSpec
    let color: RGBA
    let measurer: TextMeasurer

    func sizeThatFits(_ proposal: ProposedSize) -> CGSize {
        let run = measurer.shape(string, font: font)
        return CGSize(width: run.advanceWidth, height: run.ascent + run.descent)
    }

    func place(in rect: CGRect) -> RenderNode {
        let run = measurer.shape(string, font: font)
        let baseline = Point(x: Double(rect.minX), y: Double(rect.minY) + run.ascent)
        return .glyphRun(run, origin: baseline, color: color, font: font)
    }
}
