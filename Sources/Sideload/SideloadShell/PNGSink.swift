import SideloadRender

/// Renders exactly one frame and writes it to a PNG file.
@MainActor
public final class PNGSink: FrameSink {
    private let path: String
    private let pixelWidth: Int
    private let pixelHeight: Int
    private let scale: Double

    public init(path: String, pixelWidth: Int, pixelHeight: Int, scale: Double) {
        self.path = path
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
    }

    public func run(_ produce: (Int, Int, Double) -> Frame) throws {
        let frame = produce(pixelWidth, pixelHeight, scale)
        try frame.writePNG(to: path)
    }
}
