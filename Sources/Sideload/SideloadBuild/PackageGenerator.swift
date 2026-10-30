import Foundation

/// Maps an imported app's source path to where it was copied inside the
/// generated package, so diagnostics can be rewritten back to the
/// original path the developer actually sees in their editor.
public struct SourceMapEntry: Codable, Equatable {
    public var copyPath: String
    public var originalPath: String
}

public enum PackageGeneratorError: Error, CustomStringConvertible {
    case invalidTargetName(String)

    public var description: String {
        switch self {
        case .invalidTargetName(let name):
            return "could not derive a Swift identifier from app name '\(name)'"
        }
    }
}

/// Writes `<project dir>/.sideload/build/`: a generated SwiftPM package
/// that depends on the SDK by local path and builds the imported app's
/// sources as an executable target. Only files whose content actually
/// changed are rewritten, so repeated builds don't invalidate SwiftPM's
/// own incremental build state for no reason.
public enum PackageGenerator {
    public static func targetName(for appName: String) -> String {
        var result = ""
        for (i, scalar) in appName.unicodeScalars.enumerated() {
            if scalar == "_" || CharacterSet.alphanumerics.contains(scalar) {
                if i == 0, CharacterSet.decimalDigits.contains(scalar) {
                    result.append("_")
                }
                result.unicodeScalars.append(scalar)
            } else {
                result.append("_")
            }
        }
        return result.isEmpty ? "App" : result
    }

    /// `<SDK root>/Package.swift` declares `name: "sideload"`; the
    /// generated package's dependency uses that same string, lowercased,
    /// as its package identity — never a hard-coded `"sideload"` — so a
    /// locally renamed or forked SDK checkout still resolves.
    public static func packageIdentity(sdkRoot: String) -> String {
        ((sdkRoot as NSString).lastPathComponent).lowercased()
    }

    @discardableResult
    public static func generate(app: ImportedApp, projectDirectory: String, sdkRoot: String) throws -> (buildDirectory: String, targetName: String) {
        let buildDirectory = projectDirectory + "/.sideload/build"
        let targetName = self.targetName(for: app.name)
        guard !targetName.isEmpty else { throw PackageGeneratorError.invalidTargetName(app.name) }

        let fm = FileManager.default
        let sourcesDirectory = buildDirectory + "/Sources/\(targetName)"
        try fm.createDirectory(atPath: sourcesDirectory, withIntermediateDirectories: true)

        var sourceMap: [SourceMapEntry] = []
        var usedNames: Set<String> = []
        for originalPath in app.sources {
            let baseName = (originalPath as NSString).lastPathComponent
            var copyName = baseName
            var suffix = 2
            while usedNames.contains(copyName) {
                copyName = (baseName as NSString).deletingPathExtension + "_\(suffix).swift"
                suffix += 1
            }
            usedNames.insert(copyName)

            let copyPath = sourcesDirectory + "/" + copyName
            try writeIfChanged(contentsOf: originalPath, to: copyPath)
            sourceMap.append(SourceMapEntry(copyPath: copyPath, originalPath: originalPath))
        }

        let sourceMapData = try JSONEncoder().encode(sourceMap)
        try writeDataIfChanged(sourceMapData, to: buildDirectory + "/source-map.json")

        let isSwift5 = app.swiftVersion.hasPrefix("5")
        let packageSwift = renderPackageSwift(
            targetName: targetName,
            sdkRoot: sdkRoot,
            packageIdentity: packageIdentity(sdkRoot: sdkRoot),
            swiftLanguageModeV5: isSwift5
        )
        try writeIfChanged(packageSwift, to: buildDirectory + "/Package.swift")

        return (buildDirectory, targetName)
    }

    static func renderPackageSwift(targetName: String, sdkRoot: String, packageIdentity: String, swiftLanguageModeV5: Bool) -> String {
        let languageModeSetting = swiftLanguageModeV5
            ? "\n            swiftSettings: [.swiftLanguageMode(.v5)]"
            : ""
        let trailingComma = swiftLanguageModeV5 ? "," : ""
        return """
        // swift-tools-version:6.4
        import PackageDescription

        let package = Package(
            name: "\(targetName)",
            platforms: [.macOS(.v13)],
            dependencies: [
                .package(path: "\(sdkRoot)"),
            ],
            targets: [
                .executableTarget(
                    name: "\(targetName)",
                    dependencies: [
                        .product(name: "SideloadSDK", package: "\(packageIdentity)"),
                    ]\(trailingComma)\(languageModeSetting)
                ),
            ]
        )

        """
    }

    private static func writeIfChanged(_ contents: String, to path: String) throws {
        try writeDataIfChanged(Data(contents.utf8), to: path)
    }

    private static func writeIfChanged(contentsOf sourcePath: String, to destinationPath: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
        try writeDataIfChanged(data, to: destinationPath)
    }

    private static func writeDataIfChanged(_ data: Data, to path: String) throws {
        let fm = FileManager.default
        if let existing = fm.contents(atPath: path), existing == data {
            return
        }
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}
