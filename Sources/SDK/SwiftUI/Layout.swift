import Foundation
internal import SideloadRender

/// What a parent proposes a child's size should be. Either dimension may
/// be left unconstrained (`nil`), meaning "use your ideal size".
struct ProposedSize {
    var width: CGFloat?
    var height: CGFloat?
}

/// The propose-then-place layout protocol every internal primitive and
/// container implements.
@MainActor
protocol LayoutNode {
    func sizeThatFits(_ proposal: ProposedSize) -> CGSize
    func place(in rect: CGRect) -> RenderNode
}
