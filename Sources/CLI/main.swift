import ArgumentParser
import Foundation

@main
struct Sideload: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sideload",
        abstract: "Build and run your iOS app on Linux.",
        subcommands: [Build.self, Run.self]
    )
}

struct Build: ParsableCommand {
    @Argument(help: "Path to an .xcodeproj, a directory containing one, or an SwiftPM package.")
    var path: String

    func run() throws {
        FileHandle.standardError.write(Data("sideload: build not implemented yet\n".utf8))
        throw ExitCode(2)
    }
}

struct Run: ParsableCommand {
    @Argument(help: "Path to an .xcodeproj, a directory containing one, or an SwiftPM package.")
    var path: String

    @Option(help: "Device profile id, e.g. phone-6.1.")
    var device: String?

    @Flag(help: "Run without opening a window.")
    var headless: Bool = false

    @Option(help: "Write a screenshot PNG to this path (implies --headless when set alone).")
    var screenshot: String?

    func run() throws {
        FileHandle.standardError.write(Data("sideload: run not implemented yet\n".utf8))
        throw ExitCode(2)
    }
}
