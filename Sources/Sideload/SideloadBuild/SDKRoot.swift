import Foundation

public enum SDKRootError: Error, CustomStringConvertible {
    case notFound(searchedFrom: String)

    public var description: String {
        switch self {
        case .notFound(let path):
            return "could not find the Sideload SDK: set SIDELOAD_SDK_ROOT, or run `sideload` from inside its checkout (searched upward from \(path))"
        }
    }
}

public enum SDKRoot {
    /// `SIDELOAD_SDK_ROOT` if set; otherwise walks up from the running
    /// executable's path to the first ancestor directory whose
    /// `Package.swift` declares `name: "sideload"`.
    public static func find(executablePath: String = CommandLine.arguments[0]) throws -> String {
        if let override = ProcessInfo.processInfo.environment["SIDELOAD_SDK_ROOT"] {
            return override
        }

        let fm = FileManager.default
        var directory = resolvedDirectory(of: executablePath, fileManager: fm)
        while true {
            let packageSwiftPath = directory + "/Package.swift"
            if let contents = fm.contents(atPath: packageSwiftPath),
               let text = String(data: contents, encoding: .utf8),
               declaresSideloadPackageName(text)
            {
                return directory
            }
            let parent = (directory as NSString).deletingLastPathComponent
            if parent == directory || parent.isEmpty { break }
            directory = parent
        }
        throw SDKRootError.notFound(searchedFrom: resolvedDirectory(of: executablePath, fileManager: fm))
    }

    private static func resolvedDirectory(of executablePath: String, fileManager fm: FileManager) -> String {
        let absolute = executablePath.hasPrefix("/") ? executablePath : fm.currentDirectoryPath + "/" + executablePath
        return (absolute as NSString).deletingLastPathComponent
    }

    static func declaresSideloadPackageName(_ packageSwiftText: String) -> Bool {
        // A simple textual check is enough: Package.swift is static
        // Swift source, not something we evaluate, and every project
        // this looks at is our own.
        packageSwiftText.range(of: #"name:\s*"sideload""#, options: .regularExpression) != nil
    }
}
