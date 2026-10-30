import Foundation
import Testing
import SideloadRender
@testable import SideloadShell

@Suite struct PNGSinkTests {
    @Test(arguments: [(390, 844, 3.0, 1170, 2532), (375, 667, 2.0, 750, 1334)])
    @MainActor
    func writesSizeMatchingDevicePixelsPerProfile(args: (Int, Int, Double, Int, Int)) throws {
        let (pointWidth, pointHeight, scale, expectedPixelWidth, expectedPixelHeight) = args
        let pixelWidth = Int((Double(pointWidth) * scale).rounded())
        let pixelHeight = Int((Double(pointHeight) * scale).rounded())
        #expect(pixelWidth == expectedPixelWidth)
        #expect(pixelHeight == expectedPixelHeight)

        let path = NSTemporaryDirectory() + "/sideload-pngsink-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let sink = PNGSink(path: path, pixelWidth: pixelWidth, pixelHeight: pixelHeight, scale: scale)
        try sink.run { w, h, s in
            var frame = Frame(pixelWidth: w, pixelHeight: h, scale: s)
            frame.buffer.withUnsafeMutableBufferPointer { _ in }
            return frame
        }

        let dimensions = Frame.pngDimensions(at: path)
        #expect(dimensions?.width == expectedPixelWidth)
        #expect(dimensions?.height == expectedPixelHeight)
    }
}
