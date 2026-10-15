import Foundation

public enum PreviewKind: String, Sendable, Equatable {
    case text, image, pdf, unsupported
}

public func previewKindFor(_ path: String) -> PreviewKind {
    let suffix: String = {
        if let dot = path.lastIndex(of: ".") {
            return String(path[path.index(after: dot)...]).lowercased()
        }
        return ""
    }()
    switch suffix {
    case "png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "avif", "heic", "heif":
        return .image
    case "pdf":
        return .pdf
    case "doc", "docx", "xls", "xlsx", "xlsm", "xlsb", "ppt", "pptx",
         "odt", "ods", "odp", "pages", "numbers", "key",
         "zip", "gz", "tar", "7z", "rar", "exe", "so", "dylib",
         "mp4", "mov", "mp3", "wav", "woff", "ttf":
        return .unsupported
    default:
        return .text
    }
}

public func previewFileName(_ path: String) -> String {
    let slash = path.lastIndex(of: "/")
    let back = path.lastIndex(of: "\\")
    if let slash, let back {
        return String(path[path.index(after: max(slash, back))...])
    }
    if let slash { return String(path[path.index(after: slash)...]) }
    if let back { return String(path[path.index(after: back)...]) }
    return path
}

/// RFC 4180 quoted cells, escaped quotes and embedded newlines; no lossy line splitting.
public func parseDelimitedPreview(_ text: String, delimiter: Character) throws -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var cell = ""
    var quoted = false
    var index = text.startIndex
    var cells = 0
    func finishCell() throws {
        cells += 1
        if cells > 100_000 || row.count >= 128 {
            throw PocketError(code: "preview", message: "Table too large for grid preview; use Source / 表格过大，请切换源码查看")
        }
        row.append(cell)
        cell = ""
    }
    while index < text.endIndex {
        let ch = text[index]
        let next = text.index(after: index)
        if ch == "\"", quoted, next < text.endIndex, text[next] == "\"" {
            cell.append("\"")
            index = text.index(after: next)
            continue
        }
        if ch == "\"", quoted || cell.isEmpty {
            quoted.toggle()
            index = next
            continue
        }
        if ch == delimiter, !quoted {
            try finishCell()
            index = next
            continue
        }
        if isRowBreak(ch), !quoted {
            try finishCell()
            rows.append(row)
            row = []
            if ch == "\r", next < text.endIndex, text[next] == "\n" {
                index = text.index(after: next)
            } else {
                index = next
            }
            continue
        }
        cell.append(ch)
        index = next
    }
    if quoted { throw PocketError(code: "preview", message: "Unclosed quoted table cell") }
    let trailingBreak = text.last.map(isRowBreak) == true
    if !cell.isEmpty || !row.isEmpty || (!text.isEmpty && !trailingBreak) {
        try finishCell()
        rows.append(row)
    }
    return rows
}

private func isRowBreak(_ ch: Character) -> Bool {
    ch == "\n" || ch == "\r" || ch == "\r\n"
}

public func classifyFileType(_ path: String) -> String {
    let name = previewFileName(path).lowercased()
    if name == "package.json" || name.hasPrefix("package.") && name.hasSuffix(".json") { return "node" }
    if name.hasPrefix("dockerfile") { return "docker" }
    if name.contains(".component.") && (name.hasSuffix(".html") || name.hasSuffix(".ts")) { return "angular" }
    if name.hasPrefix(".env") { return "env" }
    if name == "readme" || name.hasPrefix("readme.") { return "markdown" }
    let suffix: String = {
        if let dot = name.lastIndex(of: ".") { return String(name[name.index(after: dot)...]) }
        return ""
    }()
    switch suffix {
    case "md", "markdown": return "markdown"
    case "png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "avif", "heic", "heif": return "image"
    case "pdf": return "pdf"
    case "html", "htm": return "html"
    case "csv", "tsv", "xls", "xlsx", "xlsm", "xlsb": return "excel"
    case "ppt", "pptx": return "ppt"
    case "doc", "docx": return "word"
    case "mp4", "mov", "webm": return "video"
    case "kt", "kts": return "kotlin"
    case "swift": return "swift"
    case "js", "mjs", "cjs": return "javascript"
    case "ts", "tsx": return "typescript"
    case "py": return "python"
    case "go": return "go"
    case "rs": return "rust"
    case "json": return "json"
    case "yml", "yaml": return "yaml"
    case "sh", "bash", "zsh": return "shell"
    case "css": return "css"
    case "xml": return "xml"
    case "java": return "java"
    case "c": return "c"
    case "cpp", "cc", "cxx", "hpp": return "cpp"
    case "h": return "c"
    default: return suffix.isEmpty ? "other" : "code"
    }
}
