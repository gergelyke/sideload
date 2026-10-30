import Foundation
import Testing
import SideloadRender
import SideloadRuntime

/// Pixel checks against a screenshot of the real `Fixtures/HelloWorld`
/// app, produced by `Tools/e2e.sh` (which builds and runs it through the
/// actual CLI, not through any internal testing shortcut) and named by
/// `SIDELOAD_E2E_PNG`. Skipped — not failed — when that variable is
/// unset, so a plain `swift test` stays fast and self-contained.
@Suite struct EndToEndTests {
    @Test func helloWorldScreenshotMatchesExpectedLayout() throws {
        guard let path = ProcessInfo.processInfo.environment["SIDELOAD_E2E_PNG"] else {
            return
        }
        let profile = DeviceProfile.phone61
        let frame = try Frame.readPNG(at: path, scale: profile.scale)

        #expect(frame.pixelWidth == profile.pixelWidth)
        #expect(frame.pixelHeight == profile.pixelHeight)

        func isWhite(_ p: RGBA) -> Bool { p.red > 0.95 && p.green > 0.95 && p.blue > 0.95 }
        func isDark(_ p: RGBA) -> Bool { p.alpha > 0.5 && p.red < 0.3 && p.green < 0.3 && p.blue < 0.3 }
        func isBlueish(_ p: RGBA) -> Bool { p.alpha > 0.5 && p.blue > 0.6 && p.red < 0.4 && p.green < 0.6 }

        // Background is white away from the content.
        #expect(isWhite(frame.pixel(x: 20, y: 20)))
        #expect(isWhite(frame.pixel(x: frame.pixelWidth - 20, y: frame.pixelHeight - 20)))

        let topSafeAreaPixels = Int(profile.safeAreaInsets.top * profile.scale)
        let bottomSafeAreaPixels = Int(profile.safeAreaInsets.bottom * profile.scale)

        var darkRows = Set<Int>()
        var blueRows = Set<Int>()
        var anyInTopSafeArea = false
        var anyInBottomSafeArea = false

        for y in 0..<frame.pixelHeight {
            for x in 0..<frame.pixelWidth {
                let pixel = frame.pixel(x: x, y: y)
                let dark = isDark(pixel)
                let blue = isBlueish(pixel)
                if dark { darkRows.insert(y) }
                if blue { blueRows.insert(y) }
                if (dark || blue), y < topSafeAreaPixels { anyInTopSafeArea = true }
                if (dark || blue), y >= frame.pixelHeight - bottomSafeAreaPixels { anyInBottomSafeArea = true }
            }
        }

        #expect(!darkRows.isEmpty, "expected dark text pixels somewhere in the screenshot")
        #expect(!blueRows.isEmpty, "expected tint-blue globe pixels somewhere in the screenshot")
        if let topBlueRow = blueRows.min(), let topDarkRow = darkRows.min() {
            #expect(topBlueRow < topDarkRow, "globe should be above the text")
        }

        // Content should sit roughly in the vertical center band, well
        // clear of the safe areas.
        let verticalCenter = frame.pixelHeight / 2
        let band = frame.pixelHeight / 4
        let contentRows = darkRows.union(blueRows)
        #expect(contentRows.contains { abs($0 - verticalCenter) < band })

        #expect(!anyInTopSafeArea, "no content should be drawn inside the top safe area")
        #expect(!anyInBottomSafeArea, "no content should be drawn inside the bottom safe area")
    }
}
