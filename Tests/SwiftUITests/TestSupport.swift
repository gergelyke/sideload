import Foundation

func repoResourcesDirectory(from filePath: String = #filePath) -> String {
    let url = URL(fileURLWithPath: filePath)
    let repoRoot = url
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return repoRoot.appendingPathComponent("Resources").path
}
