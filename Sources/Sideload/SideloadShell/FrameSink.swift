import SideloadRender

/// Something that can take a stream of rendered frames: a PNG file, a
/// window, or (later) a headless PNG recorder for UI tests.
@MainActor
public protocol FrameSink {
    /// Runs the sink to completion. `produce` renders one frame at the
    /// requested pixel size and scale; `run` calls it as often as the sink
    /// needs a frame (once for `PNGSink`, once per redraw for a window).
    func run(_ produce: (_ pixelWidth: Int, _ pixelHeight: Int, _ scale: Double) -> Frame) throws
}
