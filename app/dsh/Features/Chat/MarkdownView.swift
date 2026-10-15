import SwiftUI
import DSHProtocol

struct MarkdownView: View {
    let source: String
    var streaming = false
    var wrapCode = false
    var bodyColor: Color = T.ink
    var onFile: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseMarkdown(source, streaming: streaming).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "dshfile",
                  let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "p" })?.value
            else { return .systemAction }
            onFile?(path)
            return .handled
        })
    }

    @ViewBuilder
    private func blockView(_ block: MdBlock) -> some View {
        switch block {
        case .paragraph(let spans):
            wraps(spans)
        case .heading(let level, let spans):
            wraps(spans).font(level <= 1 ? .system(size: CGFloat(AppPrefs.fontSize), weight: .semibold) : .headline)
        case .bulletList(let items, _):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(T.text3)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(item.enumerated()), id: \.offset) { _, child in blockView(child) }
                        }
                    }
                }
            }
        case .orderedList(let items, let start, _):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(start + index).").foregroundStyle(T.text3)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(item.enumerated()), id: \.offset) { _, child in blockView(child) }
                        }
                    }
                }
            }
        case .quote(let children):
            HStack(alignment: .top, spacing: 8) {
                T.border.frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in blockView(child) }
                }
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
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Divider()
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                wraps(cell).frame(minWidth: 72, alignment: .leading).padding(6)
                            }
                        }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.border, lineWidth: 0.5))
            }
        case .rule:
            Divider()
        }
    }

    private func wraps(_ spans: [MdSpan]) -> Text {
        spans.reduce(Text("")) { acc, span in acc + spanText(span) }
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
        var attributed = AttributedString(display)
        attributed.link = url
        attributed.foregroundColor = T.link
        attributed.underlineStyle = .single
        return Text(attributed)
    }
}
