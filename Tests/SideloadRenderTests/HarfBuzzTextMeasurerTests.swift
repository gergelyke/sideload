import Testing
@testable import SideloadRender

@Suite struct HarfBuzzTextMeasurerTests {
    @Test @MainActor func helloWorldIsWiderThanHello() throws {
        let fontLibrary = try FontLibrary(resourcesDirectory: repoResourcesDirectory())
        let measurer = HarfBuzzTextMeasurer(fontLibrary: fontLibrary)
        let font = FontSpec(size: 17)

        let hello = measurer.shape("Hello", font: font)
        let helloWorld = measurer.shape("Hello, world!", font: font)

        #expect(helloWorld.advanceWidth > hello.advanceWidth)

        // Recorded on first run against the vendored Inter variable font;
        // re-record (and note why) if the vendored font ever changes.
        let recordedWidth = 100.53125
        #expect(abs(helloWorld.advanceWidth - recordedWidth) < 0.5)
    }
}
