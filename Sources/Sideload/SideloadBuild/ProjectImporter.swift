import Foundation

/// What the importer found: enough to generate a buildable SwiftPM
/// package. `sources` are absolute paths on disk.
public struct ImportedApp: Equatable {
    public var name: String
    public var displayName: String
    public var swiftVersion: String
    public var sources: [String]
    public var warnings: [String]

    public init(name: String, displayName: String, swiftVersion: String, sources: [String], warnings: [String]) {
        self.name = name
        self.displayName = displayName
        self.swiftVersion = swiftVersion
        self.sources = sources
        self.warnings = warnings
    }
}

public enum ImportError: Error, CustomStringConvertible {
    case notFound(String)
    case notAnXcodeProjectOrSwiftDirectory(String)
    case multipleXcodeProjectsFound([String])
    case noApplicationTarget([String])
    case multipleApplicationTargets([String])
    case noDebugConfiguration(String)
    case noMainTypeFound(String)
    case multipleMainTypesFound(String, [String])
    case malformedProject(String)

    public var description: String {
        switch self {
        case .notFound(let path):
            return "no such file or directory: \(path)"
        case .notAnXcodeProjectOrSwiftDirectory(let path):
            return "\(path) is not an .xcodeproj, a directory containing one, or a directory of Swift files"
        case .multipleXcodeProjectsFound(let names):
            return "multiple .xcodeproj found, expected one: \(names.joined(separator: ", "))"
        case .noApplicationTarget(let names):
            return "no target with productType com.apple.product-type.application (targets: \(names.joined(separator: ", ")))"
        case .multipleApplicationTargets(let names):
            return "multiple application targets, expected one: \(names.joined(separator: ", "))"
        case .noDebugConfiguration(let target):
            return "target \(target) has no Debug build configuration"
        case .noMainTypeFound(let dir):
            return "\(dir) has no file containing an '@main' type"
        case .multipleMainTypesFound(let dir, let files):
            return "\(dir) has more than one '@main' type, in: \(files.joined(separator: ", "))"
        case .malformedProject(let message):
            return message
        }
    }
}

public enum ProjectImporter {
    /// Accepts a path to an `.xcodeproj`, a directory containing exactly
    /// one, or a directory of Swift files with exactly one `@main` type.
    public static func importApp(at inputPath: String) throws -> ImportedApp {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: inputPath, isDirectory: &isDirectory) else {
            throw ImportError.notFound(inputPath)
        }

        if inputPath.hasSuffix(".xcodeproj") {
            return try importXcodeProject(at: inputPath)
        }

        guard isDirectory.boolValue else {
            throw ImportError.notAnXcodeProjectOrSwiftDirectory(inputPath)
        }

        let entries = try fm.contentsOfDirectory(atPath: inputPath)
        let xcodeprojEntries = entries.filter { $0.hasSuffix(".xcodeproj") }
        if xcodeprojEntries.count > 1 {
            throw ImportError.multipleXcodeProjectsFound(xcodeprojEntries)
        }
        if let only = xcodeprojEntries.first {
            return try importXcodeProject(at: inputPath + "/" + only)
        }
        return try importSwiftDirectory(at: inputPath)
    }

    static func importSwiftDirectory(at directory: String) throws -> ImportedApp {
        let fm = FileManager.default
        let entries = try fm.contentsOfDirectory(atPath: directory).filter { $0.hasSuffix(".swift") }
        var mainFiles: [String] = []
        for entry in entries {
            let path = directory + "/" + entry
            if let text = try? String(contentsOfFile: path, encoding: .utf8), text.contains("@main") {
                mainFiles.append(entry)
            }
        }
        guard !mainFiles.isEmpty else { throw ImportError.noMainTypeFound(directory) }
        guard mainFiles.count == 1 else { throw ImportError.multipleMainTypesFound(directory, mainFiles) }

        let name = (directory as NSString).lastPathComponent
        return ImportedApp(
            name: name,
            displayName: name,
            swiftVersion: "5.0",
            sources: entries.map { directory + "/" + $0 },
            warnings: []
        )
    }

    static func importXcodeProject(at xcodeprojPath: String) throws -> ImportedApp {
        let pbxprojPath = xcodeprojPath + "/project.pbxproj"
        let text = try String(contentsOfFile: pbxprojPath, encoding: .utf8)
        let project = try PBXProjectFile(text: text)
        let projectDirectory = (xcodeprojPath as NSString).deletingLastPathComponent

        guard let projectObject = project.object(project.rootObjectID) else {
            throw ImportError.malformedProject("rootObject \(project.rootObjectID) not found")
        }
        let targetIDs = project.ids(projectObject["targets"])

        var applicationTargets: [(id: String, name: String)] = []
        for id in targetIDs {
            guard let target = project.object(id) else { continue }
            if target["productType"]?.stringValue == "com.apple.product-type.application" {
                applicationTargets.append((id, target["name"]?.stringValue ?? id))
            }
        }
        guard !applicationTargets.isEmpty else {
            let names = targetIDs.compactMap { project.object($0)?["name"]?.stringValue }
            throw ImportError.noApplicationTarget(names)
        }
        guard applicationTargets.count == 1 else {
            throw ImportError.multipleApplicationTargets(applicationTargets.map(\.name))
        }

        let targetID = applicationTargets[0].id
        let targetName = applicationTargets[0].name
        guard let target = project.object(targetID) else {
            throw ImportError.malformedProject("target \(targetID) not found")
        }

        let (swiftVersion, productName, displayName) = try readBuildSettings(project: project, target: target, targetName: targetName)
        _ = productName

        var warnings: [String] = []
        var sources: [String] = []

        if let synchronizedGroupIDs = target["fileSystemSynchronizedGroups"]?.arrayValue?.compactMap(\.stringValue), !synchronizedGroupIDs.isEmpty {
            for groupID in synchronizedGroupIDs {
                try collectSynchronizedGroup(groupID, project: project, projectDirectory: projectDirectory, sources: &sources, warnings: &warnings)
            }
        } else {
            sources = try collectClassicSources(project: project, projectObject: projectObject, target: target, projectDirectory: projectDirectory, warnings: &warnings)
        }

        return ImportedApp(
            name: targetName,
            displayName: displayName,
            swiftVersion: swiftVersion,
            sources: sources,
            warnings: warnings
        )
    }

    private static func readBuildSettings(project: PBXProjectFile, target: PlistValue, targetName: String) throws -> (swiftVersion: String, productName: String, displayName: String) {
        guard let configListID = target["buildConfigurationList"]?.stringValue,
              let configList = project.object(configListID)
        else {
            throw ImportError.malformedProject("target \(targetName) has no buildConfigurationList")
        }
        let configIDs = project.ids(configList["buildConfigurations"])
        guard let debugConfigID = configIDs.first(where: { project.object($0)?["name"]?.stringValue == "Debug" }),
              let debugConfig = project.object(debugConfigID),
              let buildSettings = debugConfig["buildSettings"]?.dictionaryValue
        else {
            throw ImportError.noDebugConfiguration(targetName)
        }
        let swiftVersion = buildSettings["SWIFT_VERSION"]?.stringValue ?? "5.0"
        let productName = buildSettings["PRODUCT_NAME"]?.stringValue ?? targetName
        let displayName = buildSettings["INFOPLIST_KEY_CFBundleDisplayName"]?.stringValue ?? targetName
        return (swiftVersion, productName, displayName)
    }

    /// Walks a `PBXFileSystemSynchronizedRootGroup`'s folder on disk,
    /// honoring its `membershipExceptions`, collecting `.swift` files and
    /// warning once per ignored resource (an asset catalog or similar
    /// bundle is skipped as one unit, not file by file).
    private static func collectSynchronizedGroup(
        _ groupID: String,
        project: PBXProjectFile,
        projectDirectory: String,
        sources: inout [String],
        warnings: inout [String]
    ) throws {
        guard let group = project.object(groupID) else { return }
        let relativePath = group["path"]?.stringValue ?? ""
        let folderPath = relativePath.isEmpty ? projectDirectory : projectDirectory + "/" + relativePath

        var exceptions: Set<String> = []
        for exceptionID in project.ids(group["exceptions"]) {
            guard let exceptionSet = project.object(exceptionID) else { continue }
            for name in exceptionSet["membershipExceptions"]?.arrayValue?.compactMap(\.stringValue) ?? [] {
                exceptions.insert(name)
            }
        }

        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: folderPath).sorted() else { return }
        for entry in entries {
            if exceptions.contains(entry) { continue }
            let entryPath = folderPath + "/" + entry
            var isDirectory: ObjCBool = false
            _ = fm.fileExists(atPath: entryPath, isDirectory: &isDirectory)

            if entry.hasSuffix(".swift") {
                sources.append(entryPath)
            } else if isDirectory.boolValue, entry.contains(".") {
                // A bundle directory (.xcassets, .xcdatamodeld, ...): skip
                // the whole subtree as one ignored resource.
                warnOnce("ignored resource: \(entry)", into: &warnings)
            } else if isDirectory.boolValue {
                try collectSynchronizedSubfolder(entryPath, exceptions: exceptions, sources: &sources, warnings: &warnings)
            } else {
                warnOnce("ignored resource: \(entry)", into: &warnings)
            }
        }
    }

    private static func collectSynchronizedSubfolder(
        _ folderPath: String,
        exceptions: Set<String>,
        sources: inout [String],
        warnings: inout [String]
    ) throws {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: folderPath).sorted() else { return }
        for entry in entries {
            if exceptions.contains(entry) { continue }
            let entryPath = folderPath + "/" + entry
            var isDirectory: ObjCBool = false
            _ = fm.fileExists(atPath: entryPath, isDirectory: &isDirectory)
            if entry.hasSuffix(".swift") {
                sources.append(entryPath)
            } else if isDirectory.boolValue {
                try collectSynchronizedSubfolder(entryPath, exceptions: exceptions, sources: &sources, warnings: &warnings)
            } else {
                warnOnce("ignored resource: \(entry)", into: &warnings)
            }
        }
    }

    /// Resolves every `PBXFileReference` reachable from the project's
    /// `mainGroup` to a path relative to the project directory, then
    /// returns the `.swift` ones the target's `PBXSourcesBuildPhase`
    /// actually lists.
    private static func collectClassicSources(
        project: PBXProjectFile,
        projectObject: PlistValue,
        target: PlistValue,
        projectDirectory: String,
        warnings: inout [String]
    ) throws -> [String] {
        var resolvedPaths: [String: String] = [:]
        if let mainGroupID = projectObject["mainGroup"]?.stringValue {
            resolveGroupPaths(mainGroupID, prefix: "", project: project, into: &resolvedPaths)
        }

        guard let sourcesPhaseID = project.ids(target["buildPhases"]).first(where: { project.isa($0) == "PBXSourcesBuildPhase" }),
              let sourcesPhase = project.object(sourcesPhaseID)
        else {
            return []
        }

        var sources: [String] = []
        for buildFileID in project.ids(sourcesPhase["files"]) {
            guard let buildFile = project.object(buildFileID),
                  let fileRefID = buildFile["fileRef"]?.stringValue,
                  let relativePath = resolvedPaths[fileRefID]
            else { continue }

            if relativePath.hasSuffix(".swift") {
                sources.append(projectDirectory + "/" + relativePath)
            } else {
                warnOnce("ignored resource: \(relativePath)", into: &warnings)
            }
        }
        return sources
    }

    private static func resolveGroupPaths(_ groupID: String, prefix: String, project: PBXProjectFile, into map: inout [String: String]) {
        guard let group = project.object(groupID) else { return }
        let ownPath = group["path"]?.stringValue
        let newPrefix: String
        if let ownPath, !ownPath.isEmpty {
            newPrefix = prefix.isEmpty ? ownPath : prefix + "/" + ownPath
        } else {
            newPrefix = prefix
        }

        for childID in project.ids(group["children"]) {
            guard let childIsa = project.isa(childID), let child = project.object(childID) else { continue }
            switch childIsa {
            case "PBXFileReference":
                let filePath = child["path"]?.stringValue ?? ""
                map[childID] = newPrefix.isEmpty ? filePath : newPrefix + "/" + filePath
            case "PBXGroup", "PBXVariantGroup":
                resolveGroupPaths(childID, prefix: newPrefix, project: project, into: &map)
            default:
                break
            }
        }
    }

    private static func warnOnce(_ message: String, into warnings: inout [String]) {
        guard !warnings.contains(message) else { return }
        warnings.append(message)
    }
}
