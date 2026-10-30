import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

/// `#Preview { ... }` type-checks its body (so mistakes inside a preview
/// still surface as build errors) but expands to nothing — actually
/// rendering previews in the shell is a post-MVP feature.
public struct PreviewMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

@main
struct SwiftUIMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [PreviewMacro.self]
}
