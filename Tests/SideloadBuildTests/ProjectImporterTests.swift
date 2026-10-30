import Foundation
import Testing
@testable import SideloadBuild

@Suite struct ProjectImporterTests {
    @Test func synchronizedFixtureFindsBothSwiftFilesAndLanguageMode5() throws {
        let xcodeprojDir = fixturesDirectory() + "/Synchronized.xcodeproj"
        try makeXcodeprojWrapper(at: xcodeprojDir, pbxprojNamed: "Synchronized.pbxproj")
        defer { try? FileManager.default.removeItem(atPath: xcodeprojDir) }

        let app = try ProjectImporter.importApp(at: xcodeprojDir)

        #expect(app.name == "HelloWorld")
        #expect(app.swiftVersion == "5.0")
        #expect(app.displayName == "Hello World")

        let filenames = Set(app.sources.map { ($0 as NSString).lastPathComponent })
        #expect(filenames == ["HelloWorldApp.swift", "ContentView.swift"])
        #expect(!filenames.contains("NotesIgnoreMe.txt"))
        #expect(app.warnings.contains("ignored resource: Assets.xcassets"))
    }

    @Test func classicFixtureResolvesNestedGroupPaths() throws {
        let xcodeprojDir = fixturesDirectory() + "/Classic.xcodeproj"
        try makeXcodeprojWrapper(at: xcodeprojDir, pbxprojNamed: "Classic.pbxproj")
        defer { try? FileManager.default.removeItem(atPath: xcodeprojDir) }

        let app = try ProjectImporter.importApp(at: xcodeprojDir)

        #expect(app.name == "HelloWorldClassic")
        let suffixes = Set(app.sources.map { path -> String in
            let projectDir = (xcodeprojDir as NSString).deletingLastPathComponent
            return String(path.dropFirst(projectDir.count + 1))
        })
        #expect(suffixes == ["AppFile.swift", "Sub/SubView.swift"])
    }

    @Test func directoryWithTwoXcodeprojsFails() throws {
        let dir = fixturesDirectory() + "/TwoProjects"
        let fm = FileManager.default
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: dir) }
        try fm.createDirectory(atPath: dir + "/A.xcodeproj", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: dir + "/B.xcodeproj", withIntermediateDirectories: true)

        #expect(throws: ImportError.self) {
            try ProjectImporter.importApp(at: dir)
        }
    }

    /// `Fixtures/*.pbxproj` are plain text files (so they're easy to
    /// hand-edit and diff); wrap one in a throwaway `.xcodeproj` folder,
    /// alongside the already-checked-in sibling source folder, for the
    /// importer to read.
    private func makeXcodeprojWrapper(at xcodeprojDir: String, pbxprojNamed name: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: xcodeprojDir, withIntermediateDirectories: true)
        try fm.copyItem(atPath: fixturesDirectory() + "/" + name, toPath: xcodeprojDir + "/project.pbxproj")
    }
}
