import Foundation
import Testing
@testable import SideloadRuntime

@Suite struct DeviceProfileTests {
    static let knownIDs = ["phone-6.1", "phone-6.1-island", "phone-6.7-island", "phone-4.7-se"]

    @Test(arguments: knownIDs)
    func everyBundledProfileDecodes(id: String) throws {
        let profile = try DeviceProfile.load(id: id, resourcesDirectory: repoResourcesDirectory())
        #expect(profile.id == id)
        #expect(profile.widthPoints > 0)
        #expect(profile.heightPoints > 0)
        #expect(profile.scale > 0)
    }

    @Test func phone61FileMatchesCompiledFallback() throws {
        let loaded = try DeviceProfile.load(id: "phone-6.1", resourcesDirectory: repoResourcesDirectory())
        #expect(loaded == DeviceProfile.phone61)
    }

    @Test func expectedScreenshotPixelSizes() throws {
        let expected: [String: (Int, Int)] = [
            "phone-6.1": (1170, 2532),
            "phone-6.1-island": (1179, 2556),
            "phone-6.7-island": (1290, 2796),
            "phone-4.7-se": (750, 1334),
        ]
        for (id, size) in expected {
            let profile = try DeviceProfile.load(id: id, resourcesDirectory: repoResourcesDirectory())
            #expect(profile.pixelWidth == size.0, "\(id) width")
            #expect(profile.pixelHeight == size.1, "\(id) height")
        }
    }
}
