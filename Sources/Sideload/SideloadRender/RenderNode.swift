/// sRGB color with components in 0...1.
public struct RGBA: Sendable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = RGBA(red: 0, green: 0, blue: 0)
    public static let white = RGBA(red: 1, green: 1, blue: 1)
}

public enum FontWeight: Double, Sendable {
    case regular = 400
    case medium = 500
    case semibold = 600
    case bold = 700
}

public struct FontSpec: Sendable, Equatable, Hashable {
    public var family: String
    public var size: Double
    public var weight: FontWeight

    public init(family: String = "Inter", size: Double, weight: FontWeight = .regular) {
        self.family = family
        self.size = size
        self.weight = weight
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(family)
        hasher.combine(size)
        hasher.combine(weight.rawValue)
    }

    public static func == (lhs: FontSpec, rhs: FontSpec) -> Bool {
        lhs.family == rhs.family && lhs.size == rhs.size && lhs.weight == rhs.weight
    }
}

public struct Point: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Size: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct SRect: Sendable, Equatable {
    public var origin: Point
    public var size: Size
    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }
}

public enum PathOp: Sendable, Equatable {
    case move(Point)
    case line(Point)
    case quad(control: Point, end: Point)
    case curve(control1: Point, control2: Point, end: Point)
    case close
}

public enum LineCap: Sendable, Equatable {
    case round
    case butt
}

public enum LineJoin: Sendable, Equatable {
    case round
    case miter
}

public struct StrokeStyle: Sendable, Equatable {
    public var width: Double
    public var cap: LineCap
    public var join: LineJoin

    public init(width: Double, cap: LineCap = .round, join: LineJoin = .round) {
        self.width = width
        self.cap = cap
        self.join = join
    }
}

/// A single shaped glyph ready to be drawn, in the coordinate space of its glyph run's origin.
public struct PositionedGlyph: Sendable, Equatable {
    public var glyphID: UInt32
    public var x: Double
    public var y: Double

    public init(glyphID: UInt32, x: Double, y: Double) {
        self.glyphID = glyphID
        self.x = x
        self.y = y
    }
}

/// The render tree: an intermediate representation between SwiftUI's layout
/// output and a concrete `RenderBackend`. A node's own coordinates are local
/// to its parent `group`'s offset.
public indirect enum RenderNode: Sendable {
    case group(offset: Point, children: [RenderNode])
    case fillRect(SRect, color: RGBA)
    case glyphRun(ShapedRun, origin: Point, color: RGBA, font: FontSpec)
    case path([PathOp], fill: RGBA?, stroke: RGBA?, style: StrokeStyle?)
}
