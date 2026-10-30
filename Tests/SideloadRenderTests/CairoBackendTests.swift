import Testing
@testable import SideloadRender

@Suite struct CairoBackendTests {
    @Test @MainActor func fillRectDrawsRequestedColorAtCenter() throws {
        var frame = Frame(pixelWidth: 100, pixelHeight: 100, scale: 1)
        let backend = CairoBackend(fontLibrary: try FontLibrary(resourcesDirectory: repoResourcesDirectory()))
        backend.render(.fillRect(SRect(x: 0, y: 0, width: 100, height: 100), color: RGBA(red: 1, green: 0, blue: 0)), into: &frame)

        let center = frame.pixel(x: 50, y: 50)
        #expect(center.red > 0.95)
        #expect(center.green < 0.05)
        #expect(center.blue < 0.05)
    }

    @Test @MainActor func glyphRunDrawsDarkPixelsInsideMeasuredBoundsOnly() throws {
        let resources = repoResourcesDirectory()
        let fontLibrary = try FontLibrary(resourcesDirectory: resources)
        let measurer = HarfBuzzTextMeasurer(fontLibrary: fontLibrary)
        let font = FontSpec(size: 40, weight: .bold)
        let run = measurer.shape("H", font: font)

        var frame = Frame(pixelWidth: 100, pixelHeight: 100, scale: 1)
        let backend = CairoBackend(fontLibrary: fontLibrary)
        let baseline = Point(x: 10, y: 60)
        backend.render(
            .group(offset: Point(x: 0, y: 0), children: [
                .fillRect(SRect(x: 0, y: 0, width: 100, height: 100), color: .white),
                .glyphRun(run, origin: baseline, color: .black, font: font),
            ]),
            into: &frame
        )

        // Inside the glyph's horizontal advance and above its baseline by
        // less than the ascent, we expect some dark ink.
        var foundDarkInside = false
        for x in Int(baseline.x)..<Int(baseline.x + run.advanceWidth) {
            for y in Int(baseline.y - run.ascent)..<Int(baseline.y) {
                guard x >= 0, x < 100, y >= 0, y < 100 else { continue }
                if frame.pixel(x: x, y: y).red < 0.5 { foundDarkInside = true }
            }
        }
        #expect(foundDarkInside)

        // Far outside the glyph's box (bottom-right corner) nothing was drawn.
        let corner = frame.pixel(x: 95, y: 95)
        #expect(corner.red > 0.95)
    }

    @Test @MainActor func globeSymbolStrokesStayInsideItsBox() throws {
        let resources = repoResourcesDirectory()
        let fontLibrary = try FontLibrary(resourcesDirectory: resources)
        let symbolLibrary = try SymbolLibrary(resourcesDirectory: resources)
        let globe = symbolLibrary.symbol(named: "globe")
        #expect(!globe.isPlaceholder)

        var frame = Frame(pixelWidth: 40, pixelHeight: 40, scale: 1)
        let backend = CairoBackend(fontLibrary: fontLibrary)
        // Globe artwork is a 24x24 viewBox; draw it inset by 8pt so a
        // bounds violation would show up outside that margin.
        backend.render(
            .group(offset: Point(x: 8, y: 8), children: [
                .fillRect(SRect(x: -8, y: -8, width: 40, height: 40), color: .white),
                .path(globe.ops, fill: nil, stroke: .black, style: globe.strokeStyle),
            ]),
            into: &frame
        )

        for x in 0..<40 {
            for y in 0..<40 {
                let insideBox = x >= 6 && x <= 34 && y >= 6 && y <= 34
                if !insideBox {
                    #expect(frame.pixel(x: x, y: y).red > 0.95, "stroke drawn outside the symbol's box at (\(x), \(y))")
                }
            }
        }
    }
}
