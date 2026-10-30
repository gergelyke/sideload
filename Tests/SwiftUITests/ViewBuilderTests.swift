import Testing
@testable import SwiftUI

@Suite struct ViewBuilderTests {
    @Test @MainActor func twoChildVStackHasTwoChildren() {
        let stack = VStack {
            Text("A")
            Text("B")
        }
        let flattened = _flattenChildren(stack.content)
        #expect(flattened.count == 2)
    }

    @Test @MainActor func ifElseBuildsConditionalContent() {
        struct Conditional: View {
            let flag: Bool
            var body: some View {
                if flag {
                    Text("yes")
                } else {
                    Text("no")
                }
            }
        }
        let body = Conditional(flag: true).body
        #expect(body is _ConditionalContent<Text, Text>)
    }

    @Test @MainActor func emptyBlockIsEmptyView() {
        let stack = VStack {}
        let content: Any = stack.content
        #expect(content is EmptyView)
    }
}
