import Foundation

/// The repo's top-level `Resources/` directory, found relative to this
/// source file (`Tests/SideloadRenderTests/TestSupport.swift`) rather than
/// via SwiftPM resource bundling, since `FontLibrary`/`SymbolLibrary` read
/// the same directory the CLI points at `--resources` in production.
func repoResourcesDirectory(from filePath: String = #filePath) -> String {
    let url = URL(fileURLWithPath: filePath)
    let repoRoot = url
        .deletingLastPathComponent() // TestSupport.swift
        .deletingLastPathComponent() // SideloadRenderTests
        .deletingLastPathComponent() // Tests
    return repoRoot.appendingPathComponent("Resources").path
}

func makeTempPath(_ name: String) -> String {
    NSTemporaryDirectory() + "/sideload-test-\(UUID().uuidString)-\(name)"
}
