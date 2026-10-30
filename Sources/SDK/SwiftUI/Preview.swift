/// Declares a preview of a view. The MVP type-checks the body (so a typo
/// inside a `#Preview` still fails the build) but does not render it —
/// previews render in the shell starting in Phase 2.
@freestanding(declaration)
public macro Preview(_ name: String? = nil, body: @escaping @MainActor () -> any View) = #externalMacro(module: "SwiftUIMacros", type: "PreviewMacro")
