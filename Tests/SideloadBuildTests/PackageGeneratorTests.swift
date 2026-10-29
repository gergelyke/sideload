import Foundation
import Testing
@testable import SideloadBuild

@Suite struct PackageGeneratorTests {
    @Test func targetNameSanitizesNonIdentifierCharacters() {
        #expect(PackageGenerator.targetName(for: "Hello World") == "Hello_World")
        #expect(PackageGenerator.targetName(for: "HelloWorld") == "HelloWorld")
        #expect(PackageGenerator.targetName(for: "9Lives") == "_9Lives")
    }

    @Test func packageIdentityIsSDKRootsLastComponentLowercased() {
        #expect(PackageGenerator.packageIdentity(sdkRoot: "/home/dev/Sideload") == "sideload")
        #expect(PackageGenerator.packageIdentity(sdkRoot: "/checkouts/my-fork") == "my-fork")
    }

    @Test func generatedPackageSwiftMatchesExpectedStringForSwift5() {
        let text = PackageGenerator.renderPackageSwift(
            targetName: "HelloWorld",
            sdkRoot: "/opt/sideload",
            packageIdentity: "sideload",
            swiftLanguageModeV5: true
        )
        let expected = """
        // swift-tools-version:6.4
        import PackageDescription

        let package = Package(
            name: "HelloWorld",
            platforms: [.macOS(.v13)],
            dependencies: [
                .package(path: "/opt/sideload"),
            ],
            targets: [
                .executableTarget(
                    name: "HelloWorld",
                    dependencies: [
                        .product(name: "SideloadSDK", package: "sideload"),
                    ],
                    swiftSettings: [.swiftLanguageMode(.v5)]
                ),
            ]
        )

        """
        #expect(text == expected)
    }

    @Test func generatedPackageOmitsLanguageModeForSwift6() {
        let text = PackageGenerator.renderPackageSwift(
            targetName: "HelloWorld",
            sdkRoot: "/opt/sideload",
            packageIdentity: "sideload",
            swiftLanguageModeV5: false
        )
        #expect(!text.contains("swiftLanguageMode"))
    }

    @Test func generateWritesPackageSourcesAndSourceMap() throws {
        let fm = FileManager.default
        let projectDir = NSTemporaryDirectory() + "sideload-pkgtest-\(UUID().uuidString)"
        try fm.createDirectory(atPath: projectDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: projectDir) }

        let sourcePath = projectDir + "/Main.swift"
        try "print(\"hi\")".write(toFile: sourcePath, atomically: true, encoding: .utf8)

        let app = ImportedApp(name: "HelloWorld", displayName: "Hello World", swiftVersion: "5.0", sources: [sourcePath], warnings: [])
        let (buildDirectory, targetName) = try PackageGenerator.generate(app: app, projectDirectory: projectDir, sdkRoot: "/opt/sideload")

        #expect(targetName == "HelloWorld")
        #expect(fm.fileExists(atPath: buildDirectory + "/Package.swift"))
        #expect(fm.fileExists(atPath: buildDirectory + "/Sources/HelloWorld/Main.swift"))
        #expect(fm.fileExists(atPath: buildDirectory + "/source-map.json"))

        let mapData = try Data(contentsOf: URL(fileURLWithPath: buildDirectory + "/source-map.json"))
        let map = try JSONDecoder().decode([SourceMapEntry].self, from: mapData)
        #expect(map.count == 1)
        #expect(map[0].originalPath == sourcePath)
        #expect(map[0].copyPath == buildDirectory + "/Sources/HelloWorld/Main.swift")
    }

    @Test func diagnosticLineRewritesToOriginalPath() {
        let sourceMap = [SourceMapEntry(copyPath: "/proj/.sideload/build/Sources/App/ContentView.swift", originalPath: "/proj/HelloWorld/ContentView.swift")]
        let line = "/proj/.sideload/build/Sources/App/ContentView.swift:12:5: error: cannot find 'Foo' in scope"
        let rewritten = BuildDriver.rewrite(line, sourceMap: sourceMap)
        #expect(rewritten == "/proj/HelloWorld/ContentView.swift:12:5: error: cannot find 'Foo' in scope")
    }
}
