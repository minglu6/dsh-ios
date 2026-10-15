import SwiftUI
import UIKit
import DSHProtocol

private enum TextPreviewMode: Hashable { case preview, code, plain }

struct FilePreviewView: View {
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
                Text(refreshed).font(.system(size: 12)).foregroundStyle(T.text3).padding(.horizontal, 16)
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
                    Text(modeLabel(mode)).font(.system(size: 12)).foregroundStyle(T.text2)
                }
                .accessibilityLabel(L.openWith())
            }
            if kind == .text, mode != .preview {
                Button { wrap.toggle() } label: {
                    Image(systemName: wrap ? "text.justify.leading" : "text.alignleft")
                        .foregroundStyle(T.text2)
                }
                .accessibilityLabel(wrap ? L.unwrapLines() : L.wrapLines())
            }
            Button { generation += 1 } label: {
                Image(systemName: "arrow.clockwise").foregroundStyle(loading ? T.text3 : T.text2)
            }
            .disabled(loading)
            .accessibilityLabel(L.refreshFile())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(T.surface)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if loading && (kind != .text || text == nil) {
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
                                .font(.system(size: 12, design: .monospaced))
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
                                Image(systemName: copied ? "checkmark" : "square.on.square").foregroundStyle(T.text2)
                            }
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
        do {
            switch kind {
            case .image, .pdf:
                let result = try await model.readFileBytes(sessionId: sessionId, path: path)
                if result["eof"].bool() == false {
                    throw PocketError(code: "preview", message: L.incompleteFile())
                }
                guard let raw = result["data"].str(), let next = Data(base64Encoded: raw) else {
                    throw PocketError(code: "bad-reply", message: "Empty file response")
                }
                refreshed = bytes.map { $0 == next ? L.fileUnchanged() : L.fileUpdated() }
                bytes = next
            case .text:
                let next = try await model.readAllText(sessionId: sessionId, path: path)
                refreshed = text.map { $0 == next ? L.fileUnchanged() : L.fileUpdated() }
                text = next
            case .unsupported:
                break
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

private struct PreviewPathLabel: View {
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
            .font(.system(size: 12, design: .monospaced))
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
                    Text(line).font(level <= 1 ? .title2.weight(.semibold) : .headline).foregroundStyle(T.ink)
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
                                    .font(.system(size: 12, design: .monospaced))
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

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}

