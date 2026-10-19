import SwiftUI
import UIKit
import DSHProtocol

enum MarkdownVariant {
    case body
    case compact
}

struct MarkdownView: View {
    let source: String
    var streaming = false
    var wrapCode = false
    var bodyColor: Color = T.ink
    var variant: MarkdownVariant = .body
    var onFile: ((String) -> Void)? = nil
    var onLink: ((URL) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: variant == .compact ? 4 : 8) {
            ForEach(Array(parseMarkdown(source, streaming: streaming).enumerated()), id: \.offset) { _, block in
                MdBlockView(block: block, wrapCode: wrapCode, bodyColor: bodyColor, variant: variant)
            }
        }
        .font(variant == .compact
            ? LocalFonts.text(size: CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize)))
            : LocalFonts.text())
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "dshfile",
               let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "p" })?.value {
                onFile?(path)
                return .handled
            }
            if isChatWebLink(url) {
                onLink?(url)
                return .handled
            }
            return .systemAction
        })
    }
}

private struct MdBlockView: View {
    let block: MdBlock
    let wrapCode: Bool
    let bodyColor: Color
    var variant: MarkdownVariant = .body

    private var compactSize: CGFloat {
        CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize))
    }

    /// Desktop compact `line-height: calc(20px + delta)` at the secondary size.
    private var compactLineSpacing: CGFloat {
        max(0, CGFloat(reasoningBodyLineHeightPoints) - UIFont.systemFont(ofSize: compactSize).lineHeight)
    }

    var body: some View {
        switch block {
        case .paragraph(let spans):
            if variant == .compact {
                wraps(spans)
                    .font(LocalFonts.text(size: compactSize))
                    .lineSpacing(compactLineSpacing)
            } else {
                wraps(spans)
            }
        case .heading(let level, let spans):
            if variant == .compact {
                wraps(spans)
                    .font(LocalFonts.text(size: compactSize).weight(.semibold))
                    .lineSpacing(compactLineSpacing)
            } else {
                wraps(spans).font(level <= 1 ? LocalFonts.text().weight(.semibold) : .headline)
            }
        case .bulletList(let items, _):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(T.text3)
                            .frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + CGFloat(AppPrefs.fontSize) * 0.35 }
                        nested(item)
                    }
                }
            }
        case .orderedList(let items, let start, _):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(start + index).").foregroundStyle(T.text3)
                        nested(item)
                    }
                }
            }
        case .quote(let children):
            HStack(alignment: .top, spacing: 8) {
                T.border.frame(width: 3)
                nested(children)
            }
        case .code(let language, let literal, let incomplete):
            VStack(alignment: .leading, spacing: 4) {
                if let language, !language.isEmpty {
                    Text(language).font(.caption2).foregroundStyle(T.text3)
                }
                Group {
                    if wrapCode {
                        Text(literal)
                            .font(LocalFonts.code())
                            .foregroundStyle(T.ink)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(literal)
                                .font(LocalFonts.code())
                                .foregroundStyle(T.ink)
                                .textSelection(.enabled)
                        }
                    }
                }
                if incomplete { ProgressView().controlSize(.mini) }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.codeBlock, in: RoundedRectangle(cornerRadius: 10))
        case .table(let headers, let rows):
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(Array((headers.first ?? []).enumerated()), id: \.offset) { _, cell in
                            wraps(cell).font(.subheadline.weight(.semibold)).frame(minWidth: 72, alignment: .leading).padding(6)
                        }
                    }
                    .background(T.fill2)
                    .overlay(alignment: .bottom) { T.borderL3.frame(height: 0.5) }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                wraps(cell).frame(minWidth: 72, alignment: .leading).padding(6)
                            }
                        }
                        .overlay(alignment: .bottom) { T.border.frame(height: 0.5) }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.border, lineWidth: 0.5))
            }
        case .rule:
            Divider()
        }
    }

    private func nested(_ children: [MdBlock]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                MdBlockView(block: child, wrapCode: wrapCode, bodyColor: bodyColor, variant: variant)
            }
        }
    }

    @ViewBuilder
    private func wraps(_ spans: [MdSpan]) -> some View {
        let text = spans.reduce(Text("")) { acc, span in acc + spanText(span) }
        if spans.contains(where: Self.isFileChipSpan) {
            text
                .accessibilityIdentifier(markdownFileChipAccessibilityIdentifier)
                .overlay(alignment: .leading) {
                    Color.clear
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                        .accessibilityIdentifier(markdownFileChipAccessibilityIdentifier)
                }
        } else {
            text
        }
    }

    private static func isFileChipSpan(_ span: MdSpan) -> Bool {
        switch span {
        case .fileChip:
            return true
        case .link(_, let dest):
            return parseFileLink(dest) != nil
        default:
            return false
        }
    }

    private func spanText(_ span: MdSpan) -> Text {
        switch span {
        case .text(let value, let bold, let italic):
            var text = Text(value).foregroundColor(bodyColor)
            if bold { text = text.bold() }
            if italic { text = text.italic() }
            return text
        case .code(let value):
            return Text(value).font(LocalFonts.code()).foregroundColor(bodyColor)
        case .link(let text, let dest):
            if let path = parseFileLink(dest) {
                return fileChip(path: path, label: text)
            }
            if let url = URL(string: dest), isChatWebLink(url) {
                var attributed = AttributedString(text)
                attributed.link = url
                attributed.foregroundColor = T.link
                attributed.underlineStyle = .single
                return Text(attributed)
            }
            return Text(text).foregroundColor(T.link).underline()
        case .fileChip(let path, let label):
            return fileChip(path: path, label: label)
        }
    }

    private func fileChip(path: String, label: String) -> Text {
        let display = label.isEmpty ? path : label
        var components = URLComponents()
        components.scheme = "dshfile"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "p", value: path)]
        guard let url = components.url else {
            preconditionFailure("dshfile URL")
        }
        var attributed = AttributedString(" \(display)")
        attributed.link = url
        attributed.foregroundColor = T.link
        attributed.underlineStyle = NSUnderlineStyle()
        return Text(Image(markdownFileChipAssetName)).foregroundColor(T.link) + Text(attributed)
    }
}
