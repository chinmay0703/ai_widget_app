import SwiftUI

/// A lightweight block-level Markdown renderer good enough for chat output:
/// headings, paragraphs, bullet / numbered lists, blockquotes and fenced code.
/// Inline styling (bold, italic, `code`, links) is handled by AttributedString.
struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(MarkdownParser.parse(text)) { block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let content):
            MarkdownParser.inline(content)
                .font(.system(size: level <= 1 ? 17 : 15, weight: .bold))
                .padding(.top, 2)

        case .paragraph(let content):
            MarkdownParser.inline(content)
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundColor(.secondary)
                        MarkdownParser.inline(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(index + 1).").foregroundColor(.secondary).monospacedDigit()
                        MarkdownParser.inline(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .quote(let content):
            HStack(spacing: 8) {
                Rectangle().fill(Color.secondary.opacity(0.4)).frame(width: 3)
                MarkdownParser.inline(content)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .code(let code):
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Parser

struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(level: Int, content: String)
        case paragraph(String)
        case bullets([String])
        case ordered([String])
        case quote(String)
        case code(String)
    }
    let id: Int
    let kind: Kind
}

enum MarkdownParser {
    /// Render inline markdown (bold/italic/code/links) into a SwiftUI Text.
    static func inline(_ string: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let attributed = try? AttributedString(markdown: string, options: options) {
            return Text(attributed)
        }
        return Text(string)
    }

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var nextID = 0
        func append(_ kind: MarkdownBlock.Kind) {
            blocks.append(MarkdownBlock(id: nextID, kind: kind))
            nextID += 1
        }

        let lines = text.components(separatedBy: "\n")
        var i = 0
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block.
            if trimmed.hasPrefix("```") {
                flushParagraph()
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                i += 1 // skip closing fence
                append(.code(code.joined(separator: "\n")))
                continue
            }

            // Blank line ends a paragraph.
            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Heading.
            if let heading = headingLevel(trimmed) {
                flushParagraph()
                let content = String(trimmed.drop(while: { $0 == "#" || $0 == " " }))
                append(.heading(level: heading, content: content))
                i += 1
                continue
            }

            // Blockquote.
            if trimmed.hasPrefix(">") {
                flushParagraph()
                var quote: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix(">") else { break }
                    quote.append(String(t.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                append(.quote(quote.joined(separator: " ")))
                continue
            }

            // Bullet list.
            if isBullet(trimmed) {
                flushParagraph()
                var items: [String] = []
                while i < lines.count && isBullet(lines[i].trimmingCharacters(in: .whitespaces)) {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    items.append(String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                append(.bullets(items))
                continue
            }

            // Ordered list.
            if isOrdered(trimmed) {
                flushParagraph()
                var items: [String] = []
                while i < lines.count && isOrdered(lines[i].trimmingCharacters(in: .whitespaces)) {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if let dot = t.firstIndex(of: ".") {
                        items.append(String(t[t.index(after: dot)...]).trimmingCharacters(in: .whitespaces))
                    }
                    i += 1
                }
                append(.ordered(items))
                continue
            }

            // Otherwise accumulate into the current paragraph.
            paragraph.append(trimmed)
            i += 1
        }
        flushParagraph()

        if blocks.isEmpty {
            append(.paragraph(text))
        }
        return blocks
    }

    private static func headingLevel(_ line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard hashes <= 6, line.dropFirst(hashes).hasPrefix(" ") else { return nil }
        return hashes
    }

    private static func isBullet(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func isOrdered(_ line: String) -> Bool {
        guard let dot = line.firstIndex(of: ".") else { return false }
        let prefix = line[line.startIndex..<dot]
        return !prefix.isEmpty && prefix.allSatisfy(\.isNumber)
            && line[line.index(after: dot)...].hasPrefix(" ")
    }
}
