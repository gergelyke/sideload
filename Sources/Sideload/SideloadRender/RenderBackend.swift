@MainActor
public protocol RenderBackend {
    func render(_ root: RenderNode, into frame: inout Frame)
}
