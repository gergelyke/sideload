import Foundation

public enum BuildDriverError: Error, CustomStringConvertible {
    case buildFailed(exitCode: Int32)
    case binPathUnavailable

    public var description: String {
        switch self {
        case .buildFailed(let code):
            return "swift build failed with exit code \(code)"
        case .binPathUnavailable:
            return "could not determine the build output directory"
        }
    }
}

/// Runs `swift build` against a generated package and streams its
/// output, rewriting any diagnostic that names a file under
/// `Sources/<Target>/` back to the original path from `source-map.json`
/// — so a build error always points at the file the developer actually
/// has open, never the generated copy.
public enum BuildDriver {
    @discardableResult
    public static func build(packagePath: String, targetName: String, output print: (String) -> Void = { print($0) }) throws -> String {
        let sourceMap = loadSourceMap(packagePath: packagePath)

        try runSwiftBuild(arguments: ["build", "--package-path", packagePath, "--product", targetName], sourceMap: sourceMap, output: print)

        return try binaryPath(packagePath: packagePath, targetName: targetName)
    }

    public static func binaryPath(packagePath: String, targetName: String) throws -> String {
        let process = Process()
        process.executableURL = swiftExecutableURL()
        process.arguments = ["build", "--package-path", packagePath, "--show-bin-path"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else {
            throw BuildDriverError.binPathUnavailable
        }
        return text + "/" + targetName
    }

    private static func runSwiftBuild(arguments: [String], sourceMap: [SourceMapEntry], output print: (String) -> Void) throws {
        let process = Process()
        process.executableURL = swiftExecutableURL()
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        let handle = pipe.fileHandleForReading
        var pending = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            pending.append(chunk)
            while let newlineRange = pending.range(of: Data([0x0A])) {
                let lineData = pending.subdata(in: pending.startIndex..<newlineRange.lowerBound)
                pending.removeSubrange(pending.startIndex..<newlineRange.upperBound)
                if let line = String(data: lineData, encoding: .utf8) {
                    print(rewrite(line, sourceMap: sourceMap))
                }
            }
        }
        if !pending.isEmpty, let line = String(data: pending, encoding: .utf8) {
            print(rewrite(line, sourceMap: sourceMap))
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BuildDriverError.buildFailed(exitCode: process.terminationStatus)
        }
    }

    static func rewrite(_ line: String, sourceMap: [SourceMapEntry]) -> String {
        var result = line
        for entry in sourceMap where result.contains(entry.copyPath) {
            result = result.replacingOccurrences(of: entry.copyPath, with: entry.originalPath)
        }
        return result
    }

    private static func loadSourceMap(packagePath: String) -> [SourceMapEntry] {
        let path = packagePath + "/source-map.json"
        guard let data = FileManager.default.contents(atPath: path),
              let entries = try? JSONDecoder().decode([SourceMapEntry].self, from: data)
        else { return [] }
        return entries
    }

    private static func swiftExecutableURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["SIDELOAD_SWIFT_EXECUTABLE"] {
            return URL(fileURLWithPath: override)
        }
        return URL(fileURLWithPath: "/usr/bin/swift")
    }
}
