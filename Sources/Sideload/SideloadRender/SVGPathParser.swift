import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum SVGParseError: Error, Sendable, Equatable {
    case unsupportedElement(file: String, element: String)
    case malformed(file: String, reason: String)
}

/// Parses the small subset of SVG used by the vendored Lucide icon set into
/// `[PathOp]`: the `path`, `circle`, `ellipse`, `line`, `rect` (with `rx`),
/// `polyline` and `polygon` elements, and path-data commands
/// M, L, H, V, C, S, Q, T, A, Z (absolute and relative). All icons are
/// 24x24 viewBox, stroke width 2, round caps/joins, `currentColor` fill —
/// callers scale and color the result themselves.
public enum SVGPathParser {
    public static func parse(data: Data, file: String = "") throws -> [PathOp] {
        let delegate = Delegate(file: file)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        if let error = delegate.error {
            throw error
        }
        return delegate.ops
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        let file: String
        var ops: [PathOp] = []
        var error: SVGParseError?

        init(file: String) {
            self.file = file
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            guard error == nil else { return }
            do {
                switch elementName {
                case "svg", "g":
                    return
                case "path":
                    guard let d = attributeDict["d"] else { return }
                    ops.append(contentsOf: try PathDataParser.parse(d))
                case "circle":
                    let cx = number(attributeDict["cx"])
                    let cy = number(attributeDict["cy"])
                    let r = number(attributeDict["r"])
                    ops.append(contentsOf: Self.ellipseOps(cx: cx, cy: cy, rx: r, ry: r))
                case "ellipse":
                    let cx = number(attributeDict["cx"])
                    let cy = number(attributeDict["cy"])
                    let rx = number(attributeDict["rx"])
                    let ry = number(attributeDict["ry"])
                    ops.append(contentsOf: Self.ellipseOps(cx: cx, cy: cy, rx: rx, ry: ry))
                case "line":
                    let x1 = number(attributeDict["x1"])
                    let y1 = number(attributeDict["y1"])
                    let x2 = number(attributeDict["x2"])
                    let y2 = number(attributeDict["y2"])
                    ops.append(.move(Point(x: x1, y: y1)))
                    ops.append(.line(Point(x: x2, y: y2)))
                case "rect":
                    let x = number(attributeDict["x"])
                    let y = number(attributeDict["y"])
                    let width = number(attributeDict["width"])
                    let height = number(attributeDict["height"])
                    let rx = number(attributeDict["rx"])
                    ops.append(contentsOf: Self.rectOps(x: x, y: y, width: width, height: height, rx: rx))
                case "polyline", "polygon":
                    guard let pointsAttr = attributeDict["points"] else { return }
                    ops.append(contentsOf: try Self.polyOps(pointsAttr, closed: elementName == "polygon"))
                default:
                    throw SVGParseError.unsupportedElement(file: file, element: elementName)
                }
            } catch let svgError as SVGParseError {
                error = svgError
            } catch {
                self.error = .malformed(file: file, reason: "\(error)")
            }
        }

        private func number(_ string: String?) -> Double {
            guard let string, let value = Double(string) else { return 0 }
            return value
        }

        private static func ellipseOps(cx: Double, cy: Double, rx: Double, ry: Double) -> [PathOp] {
            // Two arcs of a circle/ellipse, drawn as four cubic quarter-arcs.
            let k = 0.5522847498 // 4/3 * (sqrt(2) - 1)
            return [
                .move(Point(x: cx + rx, y: cy)),
                .curve(control1: Point(x: cx + rx, y: cy + ry * k), control2: Point(x: cx + rx * k, y: cy + ry), end: Point(x: cx, y: cy + ry)),
                .curve(control1: Point(x: cx - rx * k, y: cy + ry), control2: Point(x: cx - rx, y: cy + ry * k), end: Point(x: cx - rx, y: cy)),
                .curve(control1: Point(x: cx - rx, y: cy - ry * k), control2: Point(x: cx - rx * k, y: cy - ry), end: Point(x: cx, y: cy - ry)),
                .curve(control1: Point(x: cx + rx * k, y: cy - ry), control2: Point(x: cx + rx, y: cy - ry * k), end: Point(x: cx + rx, y: cy)),
                .close,
            ]
        }

        private static func rectOps(x: Double, y: Double, width: Double, height: Double, rx: Double) -> [PathOp] {
            guard rx > 0 else {
                return [
                    .move(Point(x: x, y: y)),
                    .line(Point(x: x + width, y: y)),
                    .line(Point(x: x + width, y: y + height)),
                    .line(Point(x: x, y: y + height)),
                    .close,
                ]
            }
            let r = min(rx, width / 2, height / 2)
            let k = 0.5522847498
            return [
                .move(Point(x: x + r, y: y)),
                .line(Point(x: x + width - r, y: y)),
                .curve(control1: Point(x: x + width - r + r * k, y: y), control2: Point(x: x + width, y: y + r - r * k), end: Point(x: x + width, y: y + r)),
                .line(Point(x: x + width, y: y + height - r)),
                .curve(control1: Point(x: x + width, y: y + height - r + r * k), control2: Point(x: x + width - r + r * k, y: y + height), end: Point(x: x + width - r, y: y + height)),
                .line(Point(x: x + r, y: y + height)),
                .curve(control1: Point(x: x + r - r * k, y: y + height), control2: Point(x: x, y: y + height - r + r * k), end: Point(x: x, y: y + height - r)),
                .line(Point(x: x, y: y + r)),
                .curve(control1: Point(x: x, y: y + r - r * k), control2: Point(x: x + r - r * k, y: y), end: Point(x: x + r, y: y)),
                .close,
            ]
        }

        private static func polyOps(_ pointsAttr: String, closed: Bool) throws -> [PathOp] {
            let numbers = pointsAttr.split(whereSeparator: { $0 == "," || $0 == " " || $0.isNewline })
                .compactMap { Double($0) }
            guard numbers.count >= 2, numbers.count % 2 == 0 else {
                throw SVGParseError.malformed(file: "", reason: "malformed points attribute '\(pointsAttr)'")
            }
            var ops: [PathOp] = [.move(Point(x: numbers[0], y: numbers[1]))]
            var i = 2
            while i + 1 < numbers.count {
                ops.append(.line(Point(x: numbers[i], y: numbers[i + 1])))
                i += 2
            }
            if closed { ops.append(.close) }
            return ops
        }
    }
}

/// Tokenizes and interprets the `d` attribute of an SVG `<path>`.
enum PathDataParser {
    static func parse(_ d: String) throws -> [PathOp] {
        var scanner = Scanner(d)
        var ops: [PathOp] = []
        var current = Point(x: 0, y: 0)
        var subpathStart = Point(x: 0, y: 0)
        var lastControl: Point?
        var lastCommand: Character?

        while let command = scanner.nextCommand() {
            let isRelative = command.isLowercase
            func abs(_ p: Point) -> Point {
                isRelative ? Point(x: current.x + p.x, y: current.y + p.y) : p
            }

            switch command.lowercased().first! {
            case "m":
                let p = abs(try scanner.point())
                ops.append(.move(p))
                current = p
                subpathStart = p
                lastControl = nil
            case "l":
                let p = abs(try scanner.point())
                ops.append(.line(p))
                current = p
                lastControl = nil
            case "h":
                let x = try scanner.number()
                let p = isRelative ? Point(x: current.x + x, y: current.y) : Point(x: x, y: current.y)
                ops.append(.line(p))
                current = p
                lastControl = nil
            case "v":
                let y = try scanner.number()
                let p = isRelative ? Point(x: current.x, y: current.y + y) : Point(x: current.x, y: y)
                ops.append(.line(p))
                current = p
                lastControl = nil
            case "c":
                let c1 = abs(try scanner.point())
                let c2 = abs(try scanner.point())
                let end = abs(try scanner.point())
                ops.append(.curve(control1: c1, control2: c2, end: end))
                current = end
                lastControl = c2
            case "s":
                let c2 = abs(try scanner.point())
                let end = abs(try scanner.point())
                let c1 = reflect(lastControl, through: current, fallback: current)
                ops.append(.curve(control1: c1, control2: c2, end: end))
                current = end
                lastControl = c2
            case "q":
                let control = abs(try scanner.point())
                let end = abs(try scanner.point())
                ops.append(.quad(control: control, end: end))
                current = end
                lastControl = control
            case "t":
                let end = abs(try scanner.point())
                let control = reflect(lastControl, through: current, fallback: current)
                ops.append(.quad(control: control, end: end))
                current = end
                lastControl = control
            case "a":
                let rx = try scanner.number()
                let ry = try scanner.number()
                let rotation = try scanner.number()
                let largeArc = try scanner.flag()
                let sweep = try scanner.flag()
                let end = abs(try scanner.point())
                ops.append(contentsOf: Self.arcToCubicCurves(
                    from: current, to: end, rx: rx, ry: ry,
                    rotationDegrees: rotation, largeArc: largeArc, sweep: sweep
                ))
                current = end
                lastControl = nil
            case "z":
                ops.append(.close)
                current = subpathStart
                lastControl = nil
            default:
                throw SVGParseError.malformed(file: "", reason: "unsupported path command '\(command)'")
            }
            lastCommand = command
        }
        _ = lastCommand
        return ops
    }

    private static func reflect(_ control: Point?, through point: Point, fallback: Point) -> Point {
        guard let control else { return fallback }
        return Point(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    /// Endpoint-to-center arc parameterization (SVG 1.1 appendix F.6),
    /// followed by a split into <= 90 degree segments each approximated by
    /// one cubic Bezier (kappa = 4/3 * tan(theta/4)).
    static func arcToCubicCurves(
        from start: Point, to end: Point,
        rx: Double, ry: Double,
        rotationDegrees: Double, largeArc: Bool, sweep: Bool
    ) -> [PathOp] {
        if rx == 0 || ry == 0 || (start.x == end.x && start.y == end.y) {
            return [.line(end)]
        }
        var rx = Swift.abs(rx)
        var ry = Swift.abs(ry)
        let phi = rotationDegrees * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        let dx2 = (start.x - end.x) / 2
        let dy2 = (start.y - end.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2

        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let scale = lambda.squareRoot()
            rx *= scale
            ry *= scale
        }

        let sign: Double = (largeArc != sweep) ? 1 : -1
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let coef = den == 0 ? 0 : sign * (max(num, 0) / den).squareRoot()
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * -(ry * x1p / rx)

        let cx = cosPhi * cxp - sinPhi * cyp + (start.x + end.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (start.y + end.y) / 2

        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let dot = ux * vx + uy * vy
            let len = (ux * ux + uy * uy).squareRoot() * (vx * vx + vy * vy).squareRoot()
            var a = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }

        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var deltaTheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && deltaTheta > 0 { deltaTheta -= 2 * .pi }
        if sweep && deltaTheta < 0 { deltaTheta += 2 * .pi }

        let segmentCount = max(Int((Swift.abs(deltaTheta) / (.pi / 2)).rounded(.up)), 1)
        let segmentDelta = deltaTheta / Double(segmentCount)

        var ops: [PathOp] = []
        var theta = theta1
        for _ in 0..<segmentCount {
            let nextTheta = theta + segmentDelta
            let alpha = 4.0 / 3.0 * tan(segmentDelta / 4)

            func point(_ t: Double) -> (x: Double, y: Double, dx: Double, dy: Double) {
                let cosT = cos(t), sinT = sin(t)
                let x = cx + rx * cosT * cosPhi - ry * sinT * sinPhi
                let y = cy + rx * cosT * sinPhi + ry * sinT * cosPhi
                let dx = -rx * sinT * cosPhi - ry * cosT * sinPhi
                let dy = -rx * sinT * sinPhi + ry * cosT * cosPhi
                return (x, y, dx, dy)
            }

            let p1 = point(theta)
            let p2 = point(nextTheta)
            let c1 = Point(x: p1.x + alpha * p1.dx, y: p1.y + alpha * p1.dy)
            let c2 = Point(x: p2.x - alpha * p2.dx, y: p2.y - alpha * p2.dy)
            ops.append(.curve(control1: c1, control2: c2, end: Point(x: p2.x, y: p2.y)))
            theta = nextTheta
        }
        return ops
    }

    private struct Scanner {
        private let characters: [Character]
        private var index = 0

        init(_ string: String) {
            self.characters = Array(string)
        }

        mutating func nextCommand() -> Character? {
            skipSeparators()
            guard index < characters.count else { return nil }
            let c = characters[index]
            if c.isLetter {
                index += 1
                return c
            }
            // No command letter: SVG allows implicit repetition of the
            // previous command's letter before a following number, which
            // callers handle by re-scanning; not needed by our icon set.
            return nil
        }

        mutating func point() throws -> Point {
            Point(x: try number(), y: try number())
        }

        mutating func number() throws -> Double {
            skipSeparators()
            let start = index
            if index < characters.count, characters[index] == "-" || characters[index] == "+" {
                index += 1
            }
            var sawDigitOrDot = false
            var sawDot = false
            while index < characters.count {
                let c = characters[index]
                if c.isNumber {
                    sawDigitOrDot = true
                    index += 1
                } else if c == ".", !sawDot {
                    sawDot = true
                    sawDigitOrDot = true
                    index += 1
                } else {
                    break
                }
            }
            if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                index += 1
                if index < characters.count, characters[index] == "-" || characters[index] == "+" {
                    index += 1
                }
                while index < characters.count, characters[index].isNumber {
                    index += 1
                }
            }
            guard sawDigitOrDot, let value = Double(String(characters[start..<index])) else {
                throw SVGParseError.malformed(file: "", reason: "expected number at offset \(start)")
            }
            return value
        }

        mutating func flag() throws -> Bool {
            skipSeparators()
            guard index < characters.count, characters[index] == "0" || characters[index] == "1" else {
                throw SVGParseError.malformed(file: "", reason: "expected flag (0 or 1) at offset \(index)")
            }
            let value = characters[index] == "1"
            index += 1
            return value
        }

        private mutating func skipSeparators() {
            while index < characters.count, characters[index] == " " || characters[index] == "," || characters[index].isNewline || characters[index] == "\t" {
                index += 1
            }
        }
    }
}
