import Foundation

/// How `sideload run` tells the launched app process what to do, passed
/// as environment variables because `run` replaces itself with the app
/// binary via `execve`.
public struct LaunchOptions: Sendable {
    public var device: String
    public var headless: Bool
    public var screenshotPath: String?
    public var resourcesDirectory: String
    public var appName: String

    public init(
        device: String = "phone-6.1",
        headless: Bool = false,
        screenshotPath: String? = nil,
        resourcesDirectory: String,
        appName: String = "Sideload"
    ) {
        self.device = device
        self.headless = headless
        self.screenshotPath = screenshotPath
        self.resourcesDirectory = resourcesDirectory
        self.appName = appName
    }

    public static func fromEnvironment() -> LaunchOptions {
        let env = ProcessInfo.processInfo.environment
        return LaunchOptions(
            device: env["SIDELOAD_DEVICE"] ?? "phone-6.1",
            headless: env["SIDELOAD_HEADLESS"] != nil,
            screenshotPath: env["SIDELOAD_SCREENSHOT"],
            resourcesDirectory: env["SIDELOAD_RESOURCES"] ?? FileManager.default.currentDirectoryPath,
            appName: env["SIDELOAD_APP_NAME"] ?? "Sideload"
        )
    }
}
