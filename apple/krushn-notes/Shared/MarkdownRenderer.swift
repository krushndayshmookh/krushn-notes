import Foundation
import SwiftUI

// MARK: - MarkdownRenderer

/// Renders markdown content to an AttributedString using Apple's built-in parser.
/// Falls back to plain text on failure.
enum MarkdownRenderer {
    static func render(_ markdown: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
        } catch {
            return AttributedString(markdown)
        }
    }
}

// MARK: - MarkdownTextView

/// A SwiftUI view that renders markdown as styled text.
struct MarkdownTextView: View {
    let content: String

    var body: some View {
        ScrollView {
            Text(MarkdownRenderer.render(content))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
