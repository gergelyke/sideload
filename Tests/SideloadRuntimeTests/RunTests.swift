import Foundation
import Testing
import SideloadRender
@testable import SideloadRuntime

private struct FillingHost: SceneHost {
    func makeRenderNode(contentSize: CGSize, textMeasurer: TextMeasurer, symbolLibrary: SymbolLibrary) -> RenderNode {
        .fillRect(SRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height), color: .black)
    }
}

@Suite struct RunTests {
    @Test @MainActor func safeAreaInsetOffsetsContentInHeadlessRender() throws {
        let path = NSTemporaryDirectory() + "/sideload-run-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let options = LaunchOptions(
            device: "phone-6.1",
            headless: true,
            screenshotPath: path,
            resourcesDirectory: repoResourcesDirectory()
        )
        try _runCore(host: FillingHost(), options: options)

        let frame = try Frame.readPNG(at: path, scale: 3)

        // phone-6.1's top safe-area inset is 47pt at 3x scale = 141px.
        #expect(frame.pixel(x: 10, y: 140).red > 0.9, "row just above the safe area should still be the white background")
        #expect(frame.pixel(x: 10, y: 141).red < 0.1, "row at the safe-area boundary should be the host's black fill")
    }

    @Test @MainActor func headlessWithoutScreenshotPathThrows() {
        let options = LaunchOptions(headless: true, screenshotPath: nil, resourcesDirectory: repoResourcesDirectory())
        #expect(throws: RuntimeError.missingScreenshotPath) {
            try _runCore(host: FillingHost(), options: options)
        }
    }
}
