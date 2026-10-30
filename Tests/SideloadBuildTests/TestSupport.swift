import Foundation

func fixturesDirectory(from filePath: String = #filePath) -> String {
    URL(fileURLWithPath: filePath).deletingLastPathComponent().appendingPathComponent("Fixtures").path
}
