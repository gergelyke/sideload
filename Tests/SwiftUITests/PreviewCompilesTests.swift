import Testing
@testable import SwiftUI

private struct PreviewedView: View {
    var body: some View {
        Text("Hello, world!")
    }
}

#Preview {
    PreviewedView()
}

#Preview("Named") {
    PreviewedView()
}

@Suite struct PreviewCompilesTests {
    @Test func fileWithFileScopePreviewCompiles() {
        // Compiling this file at all is the test: #Preview above must
        // expand cleanly and its body must still type-check.
    }
}
