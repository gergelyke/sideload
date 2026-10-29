import Foundation

/// A symbol's vector artwork plus the stroke it was drawn with — every
/// Lucide icon is a 24x24 viewBox, 2pt stroke, round caps/joins.
public struct Symbol: Sendable {
    public var ops: [PathOp]
    public var strokeStyle: StrokeStyle
    public var viewBoxSize: Double
    public var isPlaceholder: Bool
}

public enum SymbolLibraryError: Error, Sendable {
    case mapLoadFailed(String)
}

/// Maps SF Symbol names to the vendored Lucide icon set via
/// `Resources/Symbols/sf-map.json`, parsing each icon's SVG on first use.
public final class SymbolLibrary {
    private let resourcesDirectory: String
    private let nameMap: [String: String]
    private var cache: [String: Symbol] = [:]
    private var warnedNames: Set<String> = []

    public init(resourcesDirectory: String) throws {
        self.resourcesDirectory = resourcesDirectory
        let mapPath = resourcesDirectory + "/Symbols/sf-map.json"
        guard let data = FileManager.default.contents(atPath: mapPath) else {
            throw SymbolLibraryError.mapLoadFailed("could not read \(mapPath)")
        }
        guard let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            throw SymbolLibraryError.mapLoadFailed("could not decode \(mapPath)")
        }
        self.nameMap = map
    }

    /// Returns the symbol for an SF Symbol name, or a labelled placeholder
    /// box when the name isn't mapped yet (logged once per name).
    public func symbol(named sfName: String) -> Symbol {
        if let cached = cache[sfName] { return cached }

        guard let lucideName = nameMap[sfName] else {
            warnUnmapped(sfName)
            let placeholder = Self.placeholderSymbol()
            cache[sfName] = placeholder
            return placeholder
        }

        let path = resourcesDirectory + "/Symbols/lucide/\(lucideName).svg"
        guard let data = FileManager.default.contents(atPath: path),
              let ops = try? SVGPathParser.parse(data: data, file: path)
        else {
            warnUnmapped(sfName)
            let placeholder = Self.placeholderSymbol()
            cache[sfName] = placeholder
            return placeholder
        }

        let symbol = Symbol(ops: ops, strokeStyle: StrokeStyle(width: 2, cap: .round, join: .round), viewBoxSize: 24, isPlaceholder: false)
        cache[sfName] = symbol
        return symbol
    }

    private func warnUnmapped(_ name: String) {
        guard !warnedNames.contains(name) else { return }
        warnedNames.insert(name)
        FileHandle.standardError.write(Data("sideload: no symbol mapped for \"\(name)\"; drawing a placeholder\n".utf8))
    }

    private static func placeholderSymbol() -> Symbol {
        let ops: [PathOp] = [
            .move(Point(x: 1, y: 1)),
            .line(Point(x: 23, y: 1)),
            .line(Point(x: 23, y: 23)),
            .line(Point(x: 1, y: 23)),
            .close,
        ]
        return Symbol(ops: ops, strokeStyle: StrokeStyle(width: 2, cap: .round, join: .round), viewBoxSize: 24, isPlaceholder: true)
    }
}
