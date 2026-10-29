import Foundation
import Testing
@testable import SideloadRender

@Suite struct FrameTests {
    @Test func pixelDimensionsScaleFromPoints() {
        let frame = Frame(pixelWidth: 200, pixelHeight: 80, scale: 2)
        #expect(frame.pointWidth == 100)
        #expect(frame.pointHeight == 40)
    }

    @Test @MainActor func pngRoundTripsDimensions() throws {
        var frame = Frame(pixelWidth: 200, pixelHeight: 80, scale: 2)
        let backend = CairoBackend(fontLibrary: try FontLibrary(resourcesDirectory: repoResourcesDirectory()))
        backend.render(.fillRect(SRect(x: 0, y: 0, width: 100, height: 40), color: .white), into: &frame)

        let path = makeTempPath("roundtrip.png")
        defer { try? FileManager.default.removeItem(atPath: path) }
        try frame.writePNG(to: path)

        let dimensions = Frame.pngDimensions(at: path)
        #expect(dimensions?.width == 200)
        #expect(dimensions?.height == 80)
    }
}
