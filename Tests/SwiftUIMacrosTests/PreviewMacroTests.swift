import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import SwiftUIMacros

@Suite struct PreviewMacroTests {
    let macros: [String: Macro.Type] = ["Preview": PreviewMacro.self]

    @Test func unnamedPreviewExpandsToNothing() {
        assertMacroExpansion(
            """
            #Preview {
                Text("x")
            }
            """,
            expandedSource: "",
            macros: macros
        )
    }

    @Test func namedPreviewExpandsToNothing() {
        assertMacroExpansion(
            """
            #Preview("Named") {
                Text("x")
            }
            """,
            expandedSource: "",
            macros: macros
        )
    }
}
