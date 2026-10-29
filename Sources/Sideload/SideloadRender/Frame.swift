import CCairo

public enum FrameError: Error, Sendable {
    case surfaceCreationFailed
    case writeFailed(String)
}

/// An owned pixel buffer in Cairo's `ARGB32` layout (premultiplied, native
/// endian 32-bit words), at a fixed point-to-pixel `scale`.
public struct Frame: Sendable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let scale: Double
    public let stride: Int
    public var buffer: [UInt8]

    public init(pixelWidth: Int, pixelHeight: Int, scale: Double) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
        self.stride = Int(cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, Int32(pixelWidth)))
        self.buffer = [UInt8](repeating: 0, count: stride * max(pixelHeight, 1))
    }

    /// The point size this frame represents (pixel size divided by scale).
    public var pointWidth: Double { Double(pixelWidth) / scale }
    public var pointHeight: Double { Double(pixelHeight) / scale }

    /// Reads one pixel back out of the ARGB32 buffer, unpremultiplying
    /// alpha. For tests and pixel-check tooling.
    public func pixel(x: Int, y: Int) -> RGBA {
        let offset = y * stride + x * 4
        let b = Double(buffer[offset])
        let g = Double(buffer[offset + 1])
        let r = Double(buffer[offset + 2])
        let a = Double(buffer[offset + 3])
        guard a > 0 else { return RGBA(red: 0, green: 0, blue: 0, alpha: 0) }
        return RGBA(red: r / a, green: g / a, blue: b / a, alpha: a / 255)
    }

    /// Reads back the pixel dimensions of a PNG file written by
    /// `writePNG`, without decoding pixel data. For round-trip tests.
    public static func pngDimensions(at path: String) -> (width: Int, height: Int)? {
        guard let surface = cairo_image_surface_create_from_png(path) else { return nil }
        defer { cairo_surface_destroy(surface) }
        guard cairo_surface_status(surface) == CAIRO_STATUS_SUCCESS else { return nil }
        return (Int(cairo_image_surface_get_width(surface)), Int(cairo_image_surface_get_height(surface)))
    }

    /// Reads a PNG file written by `writePNG` back into a `Frame` so
    /// tests can inspect its pixels with `pixel(x:y:)`. The PNG itself
    /// carries no scale factor, so the caller supplies the one it wrote
    /// with.
    public static func readPNG(at path: String, scale: Double) throws -> Frame {
        guard let pngSurface = cairo_image_surface_create_from_png(path) else {
            throw FrameError.surfaceCreationFailed
        }
        defer { cairo_surface_destroy(pngSurface) }
        guard cairo_surface_status(pngSurface) == CAIRO_STATUS_SUCCESS else {
            throw FrameError.writeFailed(String(cString: cairo_status_to_string(cairo_surface_status(pngSurface))))
        }

        let width = Int(cairo_image_surface_get_width(pngSurface))
        let height = Int(cairo_image_surface_get_height(pngSurface))
        var frame = Frame(pixelWidth: width, pixelHeight: height, scale: scale)

        // Re-stamp the decoded PNG onto our own buffer via cairo_paint so
        // the pixel layout matches our ARGB32 buffer exactly, regardless
        // of what format the PNG decoded to internally.
        try frame.buffer.withUnsafeMutableBufferPointer { ptr in
            guard let ourSurface = cairo_image_surface_create_for_data(
                ptr.baseAddress, CAIRO_FORMAT_ARGB32, Int32(width), Int32(height), Int32(frame.stride)
            ) else {
                throw FrameError.surfaceCreationFailed
            }
            defer { cairo_surface_destroy(ourSurface) }
            guard let cr = cairo_create(ourSurface) else { throw FrameError.surfaceCreationFailed }
            defer { cairo_destroy(cr) }
            cairo_set_source_surface(cr, pngSurface, 0, 0)
            cairo_paint(cr)
        }
        return frame
    }

    public func writePNG(to path: String) throws {
        var mutableBuffer = buffer
        let status: cairo_status_t = try mutableBuffer.withUnsafeMutableBufferPointer { ptr in
            guard let surface = cairo_image_surface_create_for_data(
                ptr.baseAddress,
                CAIRO_FORMAT_ARGB32,
                Int32(pixelWidth),
                Int32(pixelHeight),
                Int32(stride)
            ) else {
                throw FrameError.surfaceCreationFailed
            }
            defer { cairo_surface_destroy(surface) }
            return cairo_surface_write_to_png(surface, path)
        }
        if status != CAIRO_STATUS_SUCCESS {
            let message = String(cString: cairo_status_to_string(status))
            throw FrameError.writeFailed(message)
        }
    }
}
