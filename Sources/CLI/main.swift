import ArgumentParser
import Foundation
import SideloadBuild
#if canImport(Glibc)
import Glibc
#endif

@main
struct Sideload: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sideload",
        abstract: "Build and run your iOS app on Linux.",
        subcommands: [Build.self, Run.self]
    )
}

struct Build: ParsableCommand {
    @Argument(help: "Path to an .xcodeproj, a directory containing one, or a directory of Swift files.")
    var path: String

    func run() throws {
        do {
            let (binaryPath, _) = try Self.buildApp(at: path)
            print(binaryPath)
        } catch {
            FileHandle.standardError.write(Data("sideload: \(error)\n".utf8))
            throw ExitCode(1)
        }
    }

    static func buildApp(at path: String) throws -> (binaryPath: String, app: ImportedApp) {
        let app = try ProjectImporter.importApp(at: path)
        for warning in app.warnings {
            FileHandle.standardError.write(Data("sideload: warning: \(warning)\n".utf8))
        }
        let sdkRoot = try SDKRoot.find()
        let projectDirectory = projectDirectory(forInputPath: path)
        let (buildDirectory, targetName) = try PackageGenerator.generate(app: app, projectDirectory: projectDirectory, sdkRoot: sdkRoot)
        let binaryPath = try BuildDriver.build(packagePath: buildDirectory, targetName: targetName) { line in
            FileHandle.standardError.write(Data((line + "\n").utf8))
        }
        return (binaryPath, app)
    }

    static func projectDirectory(forInputPath path: String) -> String {
        if path.hasSuffix(".xcodeproj") {
            return (path as NSString).deletingLastPathComponent.isEmpty ? "." : (path as NSString).deletingLastPathComponent
        }
        return path
    }
}

struct Run: ParsableCommand {
    @Argument(help: "Path to an .xcodeproj, a directory containing one, or a directory of Swift files.")
    var path: String

    @Option(help: "Device profile id, e.g. phone-6.1.")
    var device: String?

    @Flag(help: "Run without opening a window.")
    var headless: Bool = false

    @Option(help: "Write a screenshot PNG to this path (implies --headless).")
    var screenshot: String?

    func run() throws {
        do {
            let (binaryPath, app) = try Build.buildApp(at: path)
            let sdkRoot = try SDKRoot.find()

            var environment = ProcessInfo.processInfo.environment
            if let device { environment["SIDELOAD_DEVICE"] = device }
            if headless || screenshot != nil { environment["SIDELOAD_HEADLESS"] = "1" }
            if let screenshot { environment["SIDELOAD_SCREENSHOT"] = screenshot }
            environment["SIDELOAD_RESOURCES"] = sdkRoot + "/Resources"
            environment["SIDELOAD_APP_NAME"] = app.displayName

            // execve replaces this process with the app binary, so a
            // signal sent to `sideload run` (SIGTERM from Tools/e2e.sh,
            // for instance) reaches the app directly.
            let argv: [UnsafeMutablePointer<CChar>?] = [strdup(binaryPath), nil]
            let envp: [UnsafeMutablePointer<CChar>?] = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
            execve(binaryPath, argv, envp)

            // execve only returns on failure.
            FileHandle.standardError.write(Data("sideload: could not launch \(binaryPath): \(String(cString: strerror(errno)))\n".utf8))
            throw ExitCode(1)
        } catch let exitCode as ExitCode {
            throw exitCode
        } catch {
            FileHandle.standardError.write(Data("sideload: \(error)\n".utf8))
            throw ExitCode(1)
        }
    }
}
