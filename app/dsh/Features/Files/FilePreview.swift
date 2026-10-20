import SwiftUI
import UIKit
import PDFKit
import DSHProtocol

private enum TextPreviewMode: Hashable { case preview, code, plain }

struct FilePreviewView: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    let path: String
    var onBack: (() -> Void)?

    var body: some View {
        FilePreviewContent(model: model, sessionId: sessionId, path: path, onBack: onBack)
            .id([model.activeId ?? "", sessionId, path])
    }
}

private struct FilePreviewContent: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    let path: String
    var onBack: (() -> Void)?

    @State private var mode: TextPreviewMode = .preview
    @State private var generation = 0
    @State private var loading = true
    @State private var error: String?
    @State private var text: String?
    @State private var bytes: Data?
    @State private var office: OfficePreviewDownload?
    @State private var refreshed: String?
    @State private var copied = false
    @State private var wrap = false
    @State private var fullImage = false
    @State private var modeMenu = false

    private var kind: PreviewKind { previewKindFor(path) }
    private var extensionName: String {
        if let dot = path.lastIndex(of: ".") { return String(path[path.index(after: dot)...]).lowercased() }
        return ""
    }
    private var richText: Bool { ["md", "markdown", "html", "htm", "csv", "tsv"].contains(extensionName) }
    private var language: String? { previewCodeLanguage(path) }
    private var modes: [TextPreviewMode] {
        var list: [TextPreviewMode] = []
        if richText { list.append(.preview) }
        if richText || language != nil { list.append(.code) }
        list.append(.plain)
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            header(previewFileName(path).nilIfBlank ?? path) { (onBack ?? { model.pop() })() }
            toolbar
            Divider()
            if let refreshed {
                Text(refreshed).font(Font.system(size: 12)).foregroundStyle(T.text3).padding(.horizontal, 16)
            }
            bodyContent
        }
        .background(T.bg)
        .task(id: "\(sessionId)-\(path)-\(generation)") { await load() }
        .fullScreenCover(isPresented: $fullImage) {
            if let bytes { FullScreenImagePreview(bytes: bytes) { fullImage = false } }
        }
        .onAppear {
            wrap = model.codeWordWrap
            mode = modes.first ?? .plain
        }
    }

    private var toolbar: some View {
        HStack {
            PreviewPathLabel(path: path)
            Spacer(minLength: 8)
            if kind == .office, !loading, error == nil, let office {
                OfficeFontWarning(fonts: office.missingFonts)
            }
            if kind == .text, modes.count > 1 {
                Menu {
                    ForEach(modes, id: \.self) { candidate in
                        Button {
                            mode = candidate
                        } label: {
                            if candidate == mode {
                                Label(modeLabel(candidate), systemImage: "checkmark")
                            } else {
                                Text(modeLabel(candidate))
                            }
                        }
                    }
                } label: {
                    Text(modeLabel(mode)).font(Font.system(size: 12)).foregroundStyle(T.text2)
                }
                .accessibilityLabel(L.openWith())
            }
            if kind == .text, mode != .preview {
                Button { wrap.toggle() } label: {
                    OfficialGlyph(
                        kind: wrap ? .nowrapFill : .wrapFill,
                        size: CGFloat(documentPreviewWrapIconSizePoints),
                        color: T.text2
                    )
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(wrap ? L.unwrapLines() : L.wrapLines())
            }
            Button { generation += 1 } label: {
                OfficialGlyph(
                    kind: .refreshOutline,
                    size: 16,
                    color: loading ? T.text3 : T.text2
                )
            }
            .disabled(loading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L.refreshFile())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(T.surface)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if loading && (kind == .workbook ? bytes == nil : (kind != .text || text == nil)) {
            Spacer()
            ProgressView().tint(T.accent)
            Spacer()
        } else if let error {
            VStack(alignment: .leading, spacing: 8) {
                Text(error).foregroundStyle(T.err)
                Button(L.docRetry()) { generation += 1 }
            }
            .padding(16)
            Spacer()
        } else if kind == .image, let bytes {
            VStack {
                Button(L.viewOriginal()) { fullImage = true }.foregroundStyle(T.accent)
                ImagePreviewBody(bytes: bytes)
            }
        } else if kind == .pdf, let bytes {
            PdfPreviewBody(data: bytes)
        } else if kind == .office, let office {
            PdfPreviewBody(url: office.fileURL)
        } else if kind == .workbook, let bytes {
            WorkbookPreviewBody(path: path, bytes: bytes)
        } else if let text {
            switch mode {
            case .preview where ["csv", "tsv"].contains(extensionName):
                DelimitedPreview(text: text, delimiter: extensionName == "tsv" ? "\t" : ",")
            case .preview where ["md", "markdown"].contains(extensionName):
                ScrollView {
                    MarkdownPreview(text: text).padding(16)
                }
            case .preview:
                ScrollView {
                    Text(text).font(.system(size: 14)).foregroundStyle(T.ink).frame(maxWidth: .infinity, alignment: .leading).padding(16)
                }
            case .code, .plain:
                VStack(spacing: 0) {
                    if mode == .code {
                        HStack {
                            Text(language ?? L.code())
                                .font(Font.system(size: 12, design: .monospaced))
                                .foregroundStyle(T.text2)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = text
                                copied = true
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                                    copied = false
                                }
                            } label: {
                                OfficialGlyph(
                                    kind: copied ? .checkOutline : .copyOutline,
                                    size: CGFloat(documentPreviewWrapIconSizePoints),
                                    color: T.text2
                                )
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(copied ? L.copied() : L.copy())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                    CodePreviewBody(path: path, text: text, wrap: wrap, plain: mode == .plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            Text(L.docUnsupported()).foregroundStyle(T.text2).padding(16)
            Spacer()
        }
    }

    private func modeLabel(_ mode: TextPreviewMode) -> String {
        switch mode {
        case .preview: return L.preview()
        case .code: return richText ? L.source() : L.code()
        case .plain: return L.plainText()
        }
    }

    private func load() async {
        loading = true
        error = nil
        copied = false
        if let seeded = model.uiTestFilePreviewText, kind == .text {
            text = seeded
            loading = false
            return
        }
        do {
            switch kind {
            case .image, .pdf:
                let result = try await model.readFileBytes(sessionId: sessionId, path: path)
                try Task.checkCancellation()
                if result["eof"].bool() == false {
                    throw PocketError(code: "preview", message: L.incompleteFile())
                }
                guard let raw = result["data"].str(), let next = Data(base64Encoded: raw) else {
                    throw PocketError(code: "bad-reply", message: "Empty file response")
                }
                refreshed = bytes.map { $0 == next ? L.fileUnchanged() : L.fileUpdated() }
                bytes = next
            case .office:
                let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                try await model.withOfficePreview(sessionId: sessionId, path: path) { reader in
                    let next = try await downloadOfficePreview(
                        metadata: reader.metadata,
                        cacheDirectory: cache,
                        read: reader.read
                    )
                    defer { next.close() }
                    try Task.checkCancellation()
                    if let previous = office {
                        refreshed = previous.version == next.version && previous.generation == next.generation
                            ? L.fileUnchanged() : L.fileUpdated()
                        previous.close()
                    }
                    office = next
                    loading = false
                    while !Task.isCancelled {
                        try await Task.sleep(nanoseconds: 60_000_000_000)
                    }
                }
            case .workbook:
                let next = try await readWorkbookChunks { offset, length in
                    try await model.readFileBytes(sessionId: sessionId, path: path, offset: offset, length: length)
                }
                try Task.checkCancellation()
                let unchanged = bytes == next
                refreshed = bytes.map { _ in unchanged ? L.fileUnchanged() : L.fileUpdated() }
                if !unchanged { bytes = next }
            case .text:
                let next = try await model.readAllText(sessionId: sessionId, path: path)
                try Task.checkCancellation()
                refreshed = text.map { $0 == next ? L.fileUnchanged() : L.fileUpdated() }
                text = next
            case .unsupported:
                break
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            self.error = {
                switch kind {
                case .office: return officePreviewErrorMessage(error, english: L.en)
                case .workbook: return workbookPreviewErrorMessage(error, english: L.en, unavailable: L.docErrorUnavailable)
                default: return error.localizedDescription.isEmpty ? L.docErrorUnavailable(String(describing: error)) : error.localizedDescription
                }
            }()
        }
        if kind != .office || error != nil { loading = false }
    }
}

struct PreviewPathLabel: View {
    let path: String
    var body: some View {
        let cut: String.Index? = {
            switch (path.lastIndex(of: "/"), path.lastIndex(of: "\\")) {
            case let (a?, b?): return a > b ? a : b
            case let (a?, nil): return a
            case let (nil, b?): return b
            default: return nil
            }
        }()
        let prefix = cut.map { String(path[...$0]) } ?? ""
        let name = cut.map { String(path[path.index(after: $0)...]) } ?? path
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                Text(prefix).foregroundStyle(T.text3)
                Text(name).foregroundStyle(T.ink)
            }
            .font(Font.system(size: 12, design: .monospaced))
        }
    }
}

private struct MarkdownPreview: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let line):
                    Text(line).font(level <= 1 ? Font.title2.weight(.semibold) : Font.headline).foregroundStyle(T.ink)
                case .code(let code):
                    Text(code)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(T.ink)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(T.codeBlock, in: RoundedRectangle(cornerRadius: 8))
                case .paragraph(let line):
                    Text(inline(line)).foregroundStyle(T.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Block { case heading(Int, String), code(String), paragraph(String) }

    private var blocks: [Block] {
        var out: [Block] = []
        var code: [String]?
        for raw in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init) {
            if raw.hasPrefix("```") {
                if let current = code {
                    out.append(.code(current.joined(separator: "\n")))
                    code = nil
                } else {
                    code = []
                }
                continue
            }
            if var current = code {
                current.append(raw)
                code = current
                continue
            }
            if raw.hasPrefix("### ") { out.append(.heading(3, String(raw.dropFirst(4)))) }
            else if raw.hasPrefix("## ") { out.append(.heading(2, String(raw.dropFirst(3)))) }
            else if raw.hasPrefix("# ") { out.append(.heading(1, String(raw.dropFirst(2)))) }
            else { out.append(.paragraph(raw)) }
        }
        if let current = code { out.append(.code(current.joined(separator: "\n"))) }
        return out
    }

    private func inline(_ line: String) -> AttributedString {
        AttributedString(line)
    }
}

private struct DelimitedPreview: View {
    let text: String
    let delimiter: Character
    var body: some View {
        let result = Result { try parseDelimitedPreview(text, delimiter: delimiter) }
        switch result {
        case .failure(let error):
            Text(error.localizedDescription).foregroundStyle(T.err).padding(16)
        case .success(let rows):
            let columns = rows.map(\.count).max() ?? 0
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(0..<columns, id: \.self) { column in
                                Text(row.indices.contains(column) ? row[column] : "")
                                    .font(Font.system(size: 12, design: .monospaced))
                                    .foregroundStyle(T.ink)
                                    .frame(width: 160, alignment: .leading)
                                    .padding(8)
                            }
                        }
                        .background(index == 0 ? T.fill2 : T.surface)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct ImagePreviewBody: View {
    let bytes: Data
    var original = false
    var body: some View {
        Group {
            if let image = UIImage(data: bytes) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Text(L.imagePreviewFailed()).foregroundStyle(T.text2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.colors.bgDocumentPreview)
    }
}

private struct FullScreenImagePreview: View {
    let bytes: Data
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 1
    @State private var translation: CGSize = .zero

    var body: some View {
        VStack {
            HStack {
                Button(L.reset()) { scale = 1; translation = .zero }
                Button("−") { scale = max(1, scale / 1.5) }.accessibilityLabel(L.zoomOut())
                Button("+") { scale = min(8, scale * 1.5) }.accessibilityLabel(L.zoomIn())
                Spacer()
                Button(L.close(), action: onDismiss)
            }
            .padding()
            GeometryReader { geo in
                ImagePreviewBody(bytes: bytes, original: true)
                    .scaleEffect(scale)
                    .offset(translation)
                    .gesture(MagnificationGesture().onChanged { scale = min(8, max(1, $0)) })
                    .gesture(DragGesture().onChanged { translation = $0.translation })
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .background(T.surface.ignoresSafeArea())
    }
}

private struct OfficeFontWarning: View {
    let fonts: [String]
    @State private var expanded = false

    var body: some View {
        if fonts.isEmpty {
            EmptyView()
        } else {
            Button {
                expanded.toggle()
            } label: {
                OfficialGlyph(
                    kind: .warningTriangle,
                    size: CGFloat(documentPreviewWarningIconSizePoints),
                    color: T.warnText
                )
                .frame(width: 32, height: 32)
            }
            .accessibilityLabel(L.t("缺失 \(fonts.count) 种字体，点击查看", "Missing fonts: \(fonts.count). Click to view."))
            .popover(isPresented: $expanded) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.t("缺失的字体", "Missing fonts")).font(Font.system(size: 14, weight: .semibold)).foregroundStyle(T.ink)
                        Spacer()
                        Button { expanded = false } label: {
                            OfficialGlyph(kind: .closeOutline, size: 14, color: T.text2)
                        }
                        .accessibilityLabel(L.t("关闭字体详情", "Close font details"))
                    }
                    Text(L.t("本次预览无法使用以下字体，预览中的文字和排版可能与原文档不同。", "These fonts are unavailable for this preview. Text and layout may differ from the original document."))
                        .font(Font.system(size: 13))
                        .foregroundStyle(T.text2)
                    Text(L.t("\(fonts.count) 种字体", "Fonts: \(fonts.count)")).font(Font.system(size: 12)).foregroundStyle(T.text3)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(fonts, id: \.self) { font in
                                Divider()
                                Text(font).font(Font.system(size: 13)).foregroundStyle(T.ink).padding(.vertical, 8)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
                .padding(16)
                .frame(maxWidth: 340)
            }
        }
    }
}

private struct PdfPreviewBody: View {
    var data: Data?
    var url: URL?

    var body: some View {
        let document: PDFDocument? = {
            if let data { return PDFDocument(data: data) }
            if let url { return PDFDocument(url: url) }
            return nil
        }()
        if let document {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        Text("\(L.pdfPage(index + 1)) / \(document.pageCount)")
                            .font(Font.system(size: 12))
                            .foregroundStyle(T.text3)
                        if let page = document.page(at: index) {
                            PdfPageImage(page: page, label: L.pdfPage(index + 1))
                        }
                    }
                }
                .padding(12)
            }
            .background(T.documentPreviewBg)
        } else {
            Text(L.pdfDocumentOpenFailed()).foregroundStyle(T.err).padding(16)
        }
    }
}

private struct PdfPageImage: View {
    let page: PDFPage
    let label: String

    var body: some View {
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(3, max(1, 1024 / max(bounds.width, 1)))
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .accessibilityLabel(label)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}

