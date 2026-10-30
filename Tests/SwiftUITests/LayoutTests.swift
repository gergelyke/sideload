import Testing
import SideloadRender
@testable import SwiftUI

@MainActor
private func makeServices() throws -> _RenderServices {
    let resources = repoResourcesDirectory()
    let fontLibrary = try FontLibrary(resourcesDirectory: resources)
    let symbolLibrary = try SymbolLibrary(resourcesDirectory: resources)
    return _RenderServices(textMeasurer: HarfBuzzTextMeasurer(fontLibrary: fontLibrary), symbolLibrary: symbolLibrary)
}

@Suite struct LayoutTests {
    @Test @MainActor func vstackHeightIsChildrenPlusSpacing() throws {
        let services = try makeServices()
        let environment = _Environment()

        let textA = _resolveLayout(Text("A"), environment: environment, services: services)
        let textB = _resolveLayout(Text("B"), environment: environment, services: services)
        let sizeA = textA.sizeThatFits(ProposedSize(width: nil, height: nil))
        let sizeB = textB.sizeThatFits(ProposedSize(width: nil, height: nil))

        let stack = VStack {
            Text("A")
            Text("B")
        }
        let stackLayout = _resolveLayout(stack, environment: environment, services: services)
        let stackSize = stackLayout.sizeThatFits(ProposedSize(width: nil, height: nil))

        let expectedHeight = sizeA.height + sizeB.height + 8 // default stack spacing
        #expect(abs(stackSize.height - expectedHeight) < 0.01)
    }

    @Test @MainActor func paddingAdds32PointsPerDimensionByDefault() throws {
        let services = try makeServices()
        let environment = _Environment()

        let bare = _resolveLayout(Text("Hello"), environment: environment, services: services)
        let bareSize = bare.sizeThatFits(ProposedSize(width: nil, height: nil))

        let padded = Text("Hello").padding()
        let paddedLayout = _resolveLayout(padded, environment: environment, services: services)
        let paddedSize = paddedLayout.sizeThatFits(ProposedSize(width: nil, height: nil))

        #expect(abs(paddedSize.width - (bareSize.width + 32)) < 0.01)
        #expect(abs(paddedSize.height - (bareSize.height + 32)) < 0.01)
    }
}
