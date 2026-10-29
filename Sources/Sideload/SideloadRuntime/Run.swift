import Foundation
import SideloadRender
import SideloadShell

public enum RuntimeError: Error, Sendable, CustomStringConvertible {
    case missingScreenshotPath

    public var description: String {
        switch self {
        case .missingScreenshotPath:
            return "--headless requires --screenshot <file>"
        }
    }
}

/// Loads the requested device profile and resources, builds one
/// `RenderBackend` for the process's lifetime, and hands frames to either
/// a `PNGSink` (headless) or an `SDLWindowSink` (windowed).
@MainActor
public func run(host: some SceneHost, options: LaunchOptions) throws {
    let profile = try DeviceProfile.load(id: options.device, resourcesDirectory: options.resourcesDirectory)
    let fontLibrary = try FontLibrary(resourcesDirectory: options.resourcesDirectory)
    let symbolLibrary = try SymbolLibrary(resourcesDirectory: options.resourcesDirectory)
    let textMeasurer = HarfBuzzTextMeasurer(fontLibrary: fontLibrary)
    let backend = CairoBackend(fontLibrary: fontLibrary)

    let contentSize = CGSize(
        width: profile.widthPoints - profile.safeAreaInsets.leading - profile.safeAreaInsets.trailing,
        height: profile.heightPoints - profile.safeAreaInsets.top - profile.safeAreaInsets.bottom
    )
    let safeAreaOffset = Point(x: profile.safeAreaInsets.leading, y: profile.safeAreaInsets.top)

    func produceFrame(pixelWidth: Int, pixelHeight: Int, scale: Double) -> Frame {
        let contentNode = host.makeRenderNode(contentSize: contentSize, textMeasurer: textMeasurer, symbolLibrary: symbolLibrary)
        let rootNode = RenderNode.group(offset: safeAreaOffset, children: [contentNode])
        var frame = Frame(pixelWidth: pixelWidth, pixelHeight: pixelHeight, scale: scale)
        backend.render(rootNode, into: &frame)
        return frame
    }

    if options.headless {
        guard let screenshotPath = options.screenshotPath else {
            throw RuntimeError.missingScreenshotPath
        }
        let sink = PNGSink(path: screenshotPath, pixelWidth: profile.pixelWidth, pixelHeight: profile.pixelHeight, scale: profile.scale)
        try sink.run(produceFrame)
    } else {
        let sink = SDLWindowSink(
            title: options.appName,
            pointWidth: Int(profile.widthPoints), pointHeight: Int(profile.heightPoints),
            pixelWidth: profile.pixelWidth, pixelHeight: profile.pixelHeight,
            scale: profile.scale
        )
        try sink.run(produceFrame)
    }
}
