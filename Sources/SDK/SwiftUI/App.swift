import Foundation
internal import SideloadRender
internal import SideloadRuntime

@MainActor @preconcurrency
public protocol App {
    associatedtype Body: Scene

    @SceneBuilder var body: Body { get }

    init()
}

extension App {
    public static func main() {
        let app = Self()
        let host = AppSceneHost(app: app)
        do {
            try SideloadRuntime.run(host: host, options: LaunchOptions.fromEnvironment())
        } catch {
            FileHandle.standardError.write(Data("sideload: \(error)\n".utf8))
            exit(1)
        }
    }
}

@MainActor @preconcurrency
public protocol Scene {
    associatedtype Body: Scene

    @SceneBuilder var body: Body { get }
}

protocol _SceneContentProviding {
    @MainActor var _content: any View { get }
}

public struct WindowGroup<Content: View>: Scene, _SceneContentProviding {
    public typealias Body = Never

    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never { fatalError() }

    var _content: any View { content }
}

@resultBuilder
@MainActor
public struct SceneBuilder {
    public static func buildBlock<S: Scene>(_ scene: S) -> S {
        scene
    }
}

/// Bridges an `App` to `SideloadRuntime.run`: resolves the app's single
/// `WindowGroup` scene into a `RenderNode`, proposing the window's full
/// content area and centering the result — real SwiftUI lets a
/// `WindowGroup`'s root view size itself more flexibly, but the MVP's
/// fixture only needs centering.
struct AppSceneHost<A: App>: SceneHost {
    let app: A

    func makeRenderNode(contentSize: CGSize, textMeasurer: TextMeasurer, symbolLibrary: SymbolLibrary) -> RenderNode {
        guard let providing = app.body as? _SceneContentProviding else {
            fatalError("Sideload's MVP only supports a single WindowGroup scene")
        }
        let services = _RenderServices(textMeasurer: textMeasurer, symbolLibrary: symbolLibrary)
        let layout = _resolveLayout(providing._content, environment: _Environment(), services: services)
        let size = layout.sizeThatFits(ProposedSize(width: contentSize.width, height: contentSize.height))
        let rect = CGRect(
            x: (contentSize.width - size.width) / 2,
            y: (contentSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        return layout.place(in: rect)
    }
}
