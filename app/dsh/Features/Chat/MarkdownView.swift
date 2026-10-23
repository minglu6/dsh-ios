import SwiftUI
import UIKit
import DSHProtocol

enum MarkdownVariant {
    case body
    case compact
    case trajectory
}

private struct MarkdownTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var markdownTextScale: CGFloat {
        get { self[MarkdownTextScaleKey.self] }
        set { self[MarkdownTextScaleKey.self] = newValue }
    }
}

struct MarkdownView: View {
    let source: String
    var streaming = false
    var wrapCode = false
    var bodyColor: Color = T.ink
    var variant: MarkdownVariant = .body
    var onFile: ((String) -> Void)? = nil
    var onLink: ((URL) -> Void)? = nil
    @State private var textScale: CGFloat = 1
    @GestureState private var pinchScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: variant == .compact ? 4 : 8) {
            ForEach(Array(parseMarkdown(source, streaming: streaming).enumerated()), id: \.offset) { _, block in
                MdBlockView(block: block, wrapCode: wrapCode, bodyColor: bodyColor, variant: variant)
            }
        }
        .environment(\.markdownTextScale, boundedScale(textScale * pinchScale))
        .simultaneousGesture(
            MagnificationGesture()
                .updating($pinchScale) { value, state, _ in state = value }
                .onEnded { value in textScale = boundedScale(textScale * value) }
        )
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

    private func boundedScale(_ value: CGFloat) -> CGFloat {
        min(3, max(0.75, value))
    }
}

struct MdBlockView: View {
    let block: MdBlock
    let wrapCode: Bool
    let bodyColor: Color
    var variant: MarkdownVariant = .body
    @Environment(\.markdownTextScale) private var textScale

    private var compactSize: CGFloat {
        CGFloat(reasoningBodyFontSize(contentFontSize: AppPrefs.fontSize)) * textScale
    }

    /// Desktop compact `line-height: calc(20px + delta)` at the secondary size.
    private var compactLineSpacing: CGFloat {
        max(0, CGFloat(reasoningBodyLineHeightPoints) * textScale - UIFont.systemFont(ofSize: compactSize).lineHeight)
    }

    private var bodyFont: UIFont {
        LocalFonts.uiText(size: variant == .compact ? compactSize : (variant == .trajectory ? 13 : CGFloat(AppPrefs.fontSize)) * textScale)
    }

    private var codeFont: UIFont {
        LocalFonts.uiCode(size: (variant == .trajectory ? 12 : CGFloat(AppPrefs.codeFontSize)) * textScale)
    }

    private func headingFont(_ level: Int) -> UIFont {
        let font: UIFont
        if variant == .compact {
            font = bodyFont
        } else if variant == .trajectory {
            font = LocalFonts.uiText(size: (level == 1 ? 16 : level == 2 ? 15 : 14) * textScale)
        } else if level <= 1 {
            font = bodyFont
        } else {
            return scaledPreferredFont(.headline)
        }
        return font.withWeight(.semibold)
    }

    private func scaledPreferredFont(_ style: UIFont.TextStyle) -> UIFont {
        let font = UIFont.preferredFont(forTextStyle: style)
        return font.withSize(font.pointSize * textScale)
    }

    var body: some View {
        switch block {
        case .paragraph(let spans):
            wraps(spans)
        case .heading(let level, let spans):
            wraps(spans, font: headingFont(level))
        case .bulletList(let items, _):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(T.text3)
                            .frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + bodyFont.pointSize * 0.35 }
                        nested(item)
                    }
                }
            }
        case .orderedList(let items, let start, _):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        SelectableText("\(start + index).", font: bodyFont, color: UIColor(T.text3))
                            .alignmentGuide(.firstTextBaseline) { _ in bodyFont.ascender }
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
                    SelectableText(language, font: scaledPreferredFont(.caption2), color: UIColor(T.text3))
                }
                Group {
                    if wrapCode {
                        SelectableText(literal, font: codeFont, color: UIColor(T.ink), identifier: "markdown.code")
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            SelectableText(literal, font: codeFont, color: UIColor(T.ink), identifier: "markdown.code")
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
                            wraps(cell, font: scaledPreferredFont(.subheadline).withWeight(.semibold))
                                .frame(minWidth: 72, alignment: .leading).padding(6)
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

    private func wraps(_ spans: [MdSpan], font: UIFont? = nil) -> some View {
        let font = font ?? bodyFont
        let attributed = NSMutableAttributedString()
        for span in spans { attributed.append(spanText(span, font: font)) }
        let paragraph = NSMutableParagraphStyle()
        if variant == .compact { paragraph.lineSpacing = compactLineSpacing }
        attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))
        return SelectableText(
            attributedText: attributed,
            identifier: spans.contains(where: Self.isFileChipSpan) ? markdownFileChipAccessibilityIdentifier : "markdown.text"
        )
        .alignmentGuide(.firstTextBaseline) { _ in font.ascender }
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

    private func spanText(_ span: MdSpan, font: UIFont) -> NSAttributedString {
        switch span {
        case .text(let value, let bold, let italic):
            var traits = font.fontDescriptor.symbolicTraits
            if bold { traits.insert(.traitBold) }
            if italic { traits.insert(.traitItalic) }
            let styled = font.fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: font.pointSize) } ?? font
            return NSAttributedString(string: value, attributes: [.font: styled, .foregroundColor: UIColor(bodyColor)])
        case .code(let value):
            return NSAttributedString(string: value, attributes: [.font: codeFont, .foregroundColor: UIColor(bodyColor)])
        case .link(let text, let dest):
            if let path = parseFileLink(dest) {
                return fileChip(path: path, label: text, font: font)
            }
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: UIColor(T.link), .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
            if let url = URL(string: dest), isChatWebLink(url) { attributes[.link] = url }
            return NSAttributedString(string: text, attributes: attributes)
        case .fileChip(let path, let label):
            return fileChip(path: path, label: label, font: font)
        }
    }

    private func fileChip(path: String, label: String, font: UIFont) -> NSAttributedString {
        let display = label.isEmpty ? path : label
        var components = URLComponents()
        components.scheme = "dshfile"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "p", value: path)]
        guard let url = components.url else { preconditionFailure("dshfile URL") }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: UIColor(T.link), .link: url, .underlineStyle: 0,
        ]
        let result = NSMutableAttributedString()
        if let image = UIImage(named: markdownFileChipAssetName)?.withTintColor(UIColor(T.link), renderingMode: .alwaysOriginal) {
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - image.size.height) / 2, width: image.size.width, height: image.size.height)
            let icon = NSMutableAttributedString(attachment: attachment)
            icon.addAttributes(attributes, range: NSRange(location: 0, length: icon.length))
            result.append(icon)
        }
        result.append(NSAttributedString(string: " \(display)", attributes: attributes))
        return result
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        UIFont(descriptor: fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue],
        ]), size: pointSize)
    }
}
