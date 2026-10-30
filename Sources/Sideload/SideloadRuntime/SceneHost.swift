import Foundation
import SideloadRender

/// What `run(host:options:)` asks the SDK for: given the window's content
/// area, produce the frame to render. SwiftUI's `App.main()` implements
/// this to resolve its `WindowGroup`'s view tree — `SideloadRuntime` itself
/// never imports SwiftUI.
@MainActor
public protocol SceneHost {
    func makeRenderNode(contentSize: CGSize, textMeasurer: TextMeasurer, symbolLibrary: SymbolLibrary) -> RenderNode
}
