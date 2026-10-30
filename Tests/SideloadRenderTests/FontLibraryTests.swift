import Testing
@testable import SideloadRender

@Suite struct FontLibraryTests {
    @Test @MainActor func allFourWeightsLoad() throws {
        let library = try FontLibrary(resourcesDirectory: repoResourcesDirectory())
        for weight in [FontWeight.regular, .medium, .semibold, .bold] {
            _ = try library.face(weight: weight, sizeInPoints: 17)
        }
    }
}
