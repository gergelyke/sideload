import Foundation

public struct SafeAreaInsets: Codable, Sendable, Equatable {
    public var top: Double
    public var leading: Double
    public var bottom: Double
    public var trailing: Double

    public init(top: Double, leading: Double, bottom: Double, trailing: Double) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

/// Screen geometry for one device, loaded from
/// `Resources/DeviceProfiles/<id>.json`. The id describes the screen
/// (e.g. `phone-6.1`), never a product name.
public struct DeviceProfile: Codable, Sendable, Equatable {
    public var id: String
    public var displayName: String
    public var widthPoints: Double
    public var heightPoints: Double
    public var scale: Double
    public var safeAreaInsets: SafeAreaInsets
    public var cornerRadius: Double?

    public init(
        id: String,
        displayName: String,
        widthPoints: Double,
        heightPoints: Double,
        scale: Double,
        safeAreaInsets: SafeAreaInsets,
        cornerRadius: Double? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.widthPoints = widthPoints
        self.heightPoints = heightPoints
        self.scale = scale
        self.safeAreaInsets = safeAreaInsets
        self.cornerRadius = cornerRadius
    }

    public var pixelWidth: Int { Int((widthPoints * scale).rounded()) }
    public var pixelHeight: Int { Int((heightPoints * scale).rounded()) }

    /// Compiled in so the runtime has a usable default even when no
    /// `--resources` directory is given.
    public static let phone61 = DeviceProfile(
        id: "phone-6.1",
        displayName: "6.1\" notch iPhone",
        widthPoints: 390,
        heightPoints: 844,
        scale: 3,
        safeAreaInsets: SafeAreaInsets(top: 47, leading: 0, bottom: 34, trailing: 0)
    )

    public enum LoadError: Error, Sendable {
        case notFound(String)
        case decodeFailed(String)
    }

    public static func load(id: String, resourcesDirectory: String) throws -> DeviceProfile {
        let path = resourcesDirectory + "/DeviceProfiles/\(id).json"
        guard let data = FileManager.default.contents(atPath: path) else {
            if id == phone61.id { return phone61 }
            throw LoadError.notFound(path)
        }
        do {
            return try JSONDecoder().decode(DeviceProfile.self, from: data)
        } catch {
            throw LoadError.decodeFailed("\(path): \(error)")
        }
    }
}
