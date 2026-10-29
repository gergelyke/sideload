import Foundation
import Testing
import SideloadRender
import SideloadRuntime
@testable import SwiftUI

/// A copy of `Fixtures/HelloWorld/HelloWorld/ContentView.swift`'s view,
/// kept in sync by hand (the fixture itself is plain, unmodified-looking
/// app code and isn't allowed to `@testable import SwiftUI`).
private struct FixtureContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

private func isBlueish(_ pixel: RGBA) -> Bool {
    pixel.alpha > 0.5 && pixel.blue > 0.6 && pixel.red < 0.4 && pixel.green < 0.6
}

private func isDark(_ pixel: RGBA) -> Bool {
    pixel.alpha > 0.5 && pixel.red < 0.3 && pixel.green < 0.3 && pixel.blue < 0.3
}

@Suite struct FixtureRenderTests {
    static let deviceIDs = ["phone-6.1", "phone-6.1-island", "phone-6.7-island", "phone-4.7-se"]

    @Test(arguments: deviceIDs)
    @MainActor
    func fixtureRendersBlueGlobeAboveBlackTextCenteredOnEveryDevice(deviceID: String) throws {
        let resources = repoResourcesDirectory()
        let profile = try DeviceProfile.load(id: deviceID, resourcesDirectory: resources)
        let fontLibrary = try FontLibrary(resourcesDirectory: resources)
        let symbolLibrary = try SymbolLibrary(resourcesDirectory: resources)
        let textMeasurer = HarfBuzzTextMeasurer(fontLibrary: fontLibrary)
        let backend = CairoBackend(fontLibrary: fontLibrary)

        let contentWidth = profile.widthPoints - profile.safeAreaInsets.leading - profile.safeAreaInsets.trailing
        let contentHeight = profile.heightPoints - profile.safeAreaInsets.top - profile.safeAreaInsets.bottom

        let services = _RenderServices(textMeasurer: textMeasurer, symbolLibrary: symbolLibrary)
        let layout = _resolveLayout(FixtureContentView(), environment: _Environment(), services: services)
        let size = layout.sizeThatFits(ProposedSize(width: contentWidth, height: contentHeight))
        let rect = CGRect(
            x: (contentWidth - size.width) / 2,
            y: (contentHeight - size.height) / 2,
            width: size.width, height: size.height
        )
        let contentNode = layout.place(in: rect)
        let rootNode = RenderNode.group(
            offset: Point(x: profile.safeAreaInsets.leading, y: profile.safeAreaInsets.top),
            children: [contentNode]
        )

        var frame = Frame(pixelWidth: profile.pixelWidth, pixelHeight: profile.pixelHeight, scale: profile.scale)
        backend.render(rootNode, into: &frame)

        var blueMinX = Int.max, blueMaxX = Int.min, blueMinY = Int.max, blueMaxY = Int.min
        var darkMinX = Int.max, darkMaxX = Int.min, darkMinY = Int.max, darkMaxY = Int.min

        for y in 0..<frame.pixelHeight {
            for x in 0..<frame.pixelWidth {
                let pixel = frame.pixel(x: x, y: y)
                if isBlueish(pixel) {
                    blueMinX = min(blueMinX, x); blueMaxX = max(blueMaxX, x)
                    blueMinY = min(blueMinY, y); blueMaxY = max(blueMaxY, y)
                } else if isDark(pixel) {
                    darkMinX = min(darkMinX, x); darkMaxX = max(darkMaxX, x)
                    darkMinY = min(darkMinY, y); darkMaxY = max(darkMaxY, y)
                }
            }
        }

        #expect(blueMaxX >= blueMinX, "no blue (globe) pixels found for \(deviceID)")
        #expect(darkMaxX >= darkMinX, "no dark (text) pixels found for \(deviceID)")
        guard blueMaxX >= blueMinX, darkMaxX >= darkMinX else { return }

        #expect(darkMinY > blueMaxY, "text should be below the globe on \(deviceID)")

        let centerX = Double(frame.pixelWidth) / 2
        let blueCenter = Double(blueMinX + blueMaxX) / 2
        let darkCenter = Double(darkMinX + darkMaxX) / 2
        let tolerance = Double(frame.pixelWidth) * 0.02 // 2% of screen width

        #expect(abs(blueCenter - centerX) < tolerance, "globe not horizontally centered on \(deviceID)")
        #expect(abs(darkCenter - centerX) < tolerance, "text not horizontally centered on \(deviceID)")
    }
}
