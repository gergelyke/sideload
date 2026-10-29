import Foundation
import Testing
@testable import SideloadRender

@Suite struct SymbolLibraryTests {
    @Test func everyVendoredSVGParses() throws {
        let lucideDir = repoResourcesDirectory() + "/Symbols/lucide"
        let files = try FileManager.default.contentsOfDirectory(atPath: lucideDir)
            .filter { $0.hasSuffix(".svg") }
        #expect(!files.isEmpty)
        for file in files {
            let path = lucideDir + "/" + file
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            do {
                let ops = try SVGPathParser.parse(data: data, file: path)
                #expect(!ops.isEmpty, "\(file) parsed to no path operations")
            } catch {
                Issue.record("\(file) failed to parse: \(error)")
            }
        }
    }

    @Test func unmappedNameFallsBackToPlaceholder() throws {
        let library = try SymbolLibrary(resourcesDirectory: repoResourcesDirectory())
        let symbol = library.symbol(named: "not.a.real.symbol")
        #expect(symbol.isPlaceholder)
    }

    @Test func mappedNameLoadsRealArtwork() throws {
        let library = try SymbolLibrary(resourcesDirectory: repoResourcesDirectory())
        let globe = library.symbol(named: "globe")
        #expect(!globe.isPlaceholder)
        #expect(!globe.ops.isEmpty)
    }
}
