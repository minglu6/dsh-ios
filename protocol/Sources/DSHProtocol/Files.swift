import Foundation

public enum PreviewKind: String, Sendable, Equatable {
    case text, image, pdf, office, workbook, unsupported
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
    case "doc", "docx", "ppt", "pptx":
        return .office
    case "xls", "xlsx":
        return .workbook
    case "xlsm", "xlsb", "odt", "ods", "odp", "pages", "numbers", "key",
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

/// Official desktop `FileTypeIcon` / `CodeFileIcon` name → kind map.
public func classifyFileType(_ path: String) -> String {
    let name = previewFileName(path).lowercased()
    if let kind = fileTypeNames[name] { return kind }
    if name.hasPrefix("dockerfile.") { return "docker" }
    if name.hasPrefix(".env.") { return "env" }
    if let kind = fileTypeSuffixes.first(where: { name.hasSuffix($0.key) })?.value { return kind }
    let extensionName: String = {
        if let dot = name.lastIndex(of: ".") { return String(name[name.index(after: dot)...]) }
        return ""
    }()
    return fileTypeExtensions[extensionName] ?? "other"
}

/// Workspace listing `type` → file-icon kind. Non-file/non-directory entries
/// (`socket`, `fifo`, Host `other`, …) use the desktop warning glyph.
public func fileTypeKind(path: String, type: String) -> String {
    switch type {
    case "directory": return "folder"
    case "file": return classifyFileType(path)
    default: return "warning"
    }
}

/// Desktop file-icon fill (`#rrggbb`) for the classified kind.
public func fileTypeAccent(_ kind: String) -> UInt32 {
    switch kind {
    case "folder": return 0xF7AD31
    case "excel": return 0x22C55E
    case "pdf": return 0xEC1313
    case "ppt": return 0xF59E0B
    case "word": return 0x5686FE
    case "image", "video": return 0x8B76F6
    case "markdown", "html", "code": return 0x4176E6
    case "other", "warning": return 0xCFD3D6
    case "javascript": return 0xF0DB4F
    case "typescript": return 0x007ACC
    case "python": return 0x3776AB
    case "go": return 0x00ADD8
    case "rust": return 0xDEA584
    case "java": return 0x0074BD
    case "kotlin": return 0x7F52FF
    case "swift": return 0xF05138
    case "ruby": return 0xCC342D
    case "docker": return 0x2496ED
    case "git": return 0xF05032
    case "node": return 0x539E43
    case "react": return 0x61DAFB
    case "vue": return 0x41B883
    case "css": return 0x1572B6
    case "json": return 0x6E7781
    case "yaml": return 0xCB171E
    case "shell": return 0x303642
    case "c": return 0x659AD2
    case "cpp": return 0x00599C
    case "csharp": return 0x9B4F96
    case "php": return 0x777BB4
    case "xml": return 0x005FAD
    case "sql": return 0x336791
    case "toml": return 0x9C4121
    case "ini": return 0x6E7781
    case "env": return 0xECD53F
    case "angular": return 0xDD0031
    case "svelte": return 0xFF3E00
    case "dart": return 0x00C4B3
    case "elixir": return 0x8D67AF
    case "erlang": return 0xA90533
    case "haskell": return 0x5E5187
    case "lua": return 0x000080
    case "perl": return 0x0073A1
    case "r": return 0x276DC3
    case "scala": return 0xDC322F
    case "solidity": return 0x363636
    case "zig": return 0xE18A00
    case "wasm": return 0x654FF0
    case "graphql": return 0xE10098
    case "cmake": return 0x064F8C
    case "makefile": return 0x427819
    case "powershell": return 0x2671BE
    case "protobuf": return 0x4285F4
    case "objective-c": return 0x438EFF
    case "clojure": return 0x91DC47
    default:
        return 0xCFD3D6
    }
}

/// Desktop folder row: official close/open sheet, never SF `folder` / `folder.fill`.
public func fileTreeFolderUsesOfficialGlyph() -> Bool { true }

public func fileTreeFolderSymbol(expanded: Bool) -> String {
    expanded ? "official.folderOpen" : "official.folderClose"
}

public func isForbiddenSystemFolderSymbol(_ name: String) -> Bool {
    name == "folder" || name == "folder.fill"
}

/// Desktop `FileTypeIcon` traditional `FileGlyph` kinds (28×28 folded sheet
/// + category mark). Language kinds use `CODE_FILE_ARTWORK` (see
/// `fileTypeHasCodeFileArtwork`).
public func fileTypeHasTraditionalGlyph(_ kind: String) -> Bool {
    switch kind {
    case "markdown", "image", "pdf", "excel", "word", "ppt", "video", "html", "code", "other":
        return true
    default:
        return false
    }
}

/// Desktop `ui-primitives` `CODE_FILE_TYPE_SET` / `CodeFileIcon` 20×20
/// full-color markup (`#region lib/types/code-file-icon-artwork.js`).
public func fileTypeHasCodeFileArtwork(_ kind: String) -> Bool {
    switch kind {
    case "angular", "c", "clojure", "cmake", "cpp", "csharp", "css", "dart",
         "docker", "elixir", "env", "erlang", "flutter", "git", "go", "graphql",
         "haskell", "ini", "java", "javascript", "json", "kotlin", "lua",
         "makefile", "node", "objective-c", "perl", "php", "powershell",
         "protobuf", "python", "r", "react", "ruby", "rust", "scala", "shell",
         "solidity", "sql", "svelte", "swift", "toml", "typescript", "vue",
         "wasm", "xml", "yaml", "zig":
        return true
    default:
        return false
    }
}

/// Asset catalog imageset for a `CODE_FILE_ARTWORK` kind (`codeFile_python`).
public func fileTypeCodeFileAssetName(_ kind: String) -> String {
    "codeFile_" + kind.replacingOccurrences(of: "-", with: "_")
}

/// Identifier painted by `FileTypeGlyph` / `OfficialGlyph` / `CodeFileArtworkIcon`.
/// Unknown kinds follow desktop `FileGlyph` `other`, never SF `doc.fill`.
public func fileTypeSymbol(_ kind: String) -> String {
    switch kind {
    case "folder": return fileTreeFolderSymbol(expanded: true)
    case "markdown": return "official.fileMarkdown"
    case "image": return "official.fileImage"
    case "pdf": return "official.filePdf"
    case "excel": return "official.fileExcel"
    case "word": return "official.fileWord"
    case "ppt": return "official.filePpt"
    case "video": return "official.fileVideo"
    case "html": return "official.fileHtml"
    case "code": return "official.fileCode"
    case "other": return "official.fileOther"
    case "warning": return "official.warningOutline"
    default:
        if fileTypeHasCodeFileArtwork(kind) {
            return "official.codeFile.\(kind)"
        }
        return "official.fileOther"
    }
}

public func isForbiddenTraditionalFileTypeSystemSymbol(_ name: String) -> Bool {
    name == "doc.richtext"
        || name == "photo"
        || name == "tablecells"
        || name == "doc.text.fill"
        || name == "rectangle.on.rectangle"
        || name == "film"
        || name == "chevron.left.forwardslash.chevron.right"
        || name == "doc"
        || name == "exclamationmark.triangle"
}

/// Language `CodeFileIcon` never falls back to SF document fills.
public func isForbiddenCodeFileSystemSymbol(_ name: String) -> Bool {
    name == "doc.fill" || name == "doc"
}

/// Desktop `FileTypeIcon` `FILE_BODY` / `FILE_FOLD`, viewBox 0 0 28 28.
public let fileGlyphBodyPath =
    "M8.48924 28H19.5108C21.6479 28 22.7165 28 23.5594 27.6509C24.6833 27.1853 25.5762 26.2924 26.0417 25.1685C26.3909 24.3256 26.3909 23.257 26.3909 21.1199V8.79443C26.3909 8.32877 26.3909 8.09593 26.3471 7.87507C26.2887 7.58058 26.173 7.30042 26.0067 7.05048C25.882 6.86303 25.7177 6.69799 25.3893 6.36792L20.0611 1.01354C19.7304 0.681235 19.5651 0.515081 19.3769 0.38885C19.126 0.220541 18.8443 0.103463 18.5481 0.0443412C18.3259 0 18.0915 0 17.6226 0H8.48924C6.35209 0 5.28351 0 4.4406 0.349145C3.31672 0.814671 2.4238 1.70759 1.95828 2.83147C1.60913 3.67438 1.60913 4.74296 1.60913 6.88011V21.1199C1.60913 23.257 1.60913 24.3256 1.95828 25.1685C2.4238 26.2924 3.31672 27.1853 4.4406 27.6509C5.28351 28 6.35209 28 8.48924 28Z"
public let fileGlyphFoldPath =
    "M26.3909 7.37445L19.0525 0V3.77445C19.0525 4.89271 19.0525 5.45184 19.2352 5.89289C19.4788 6.48096 19.946 6.94818 20.5341 7.19176C20.9751 7.37445 21.5342 7.37445 22.6525 7.37445H26.3909Z"

/// Desktop `--dsw-static-neutral-400` fold fill when `muted` (`other`).
public let fileGlyphMutedFoldHex: UInt32 = 0xFFA2A4A6
/// Desktop `--dsw-static-neutral-00` at 70% on a colored sheet.
public let fileGlyphFoldWhiteOpacity: Double = 0.7
public let fileGlyphMarkScale: Double = 1.12
public let fileGlyphLargeMarkScale: Double = 1.22
public let fileGlyphViewBox: Double = 28
public let fileTreeFileIconSizePoints: Double = 16

public let fileGlyphCodeLeftPath =
    "M10.0053 13.126L7.0236 16.3788C6.96052 16.4476 6.96052 16.5532 7.0236 16.622L10.0053 19.8748"
public let fileGlyphCodeRightPath =
    "M17.9941 13.126L20.9759 16.3788C21.039 16.4476 21.039 16.5532 20.9759 16.622L17.9941 19.8748"
public let fileGlyphCodeSlashPath = "M15.2652 12.957L12.7344 20.0433"
public let fileGlyphCodeStrokeWidth: Double = 1.35

public let fileGlyphExcelGridPath =
    "M14 11.5H11.4C10.5599 11.5 10.1399 11.5 9.81901 11.6635C9.53677 11.8073 9.3073 12.0368 9.16349 12.319C9 12.6399 9 13.0599 9 13.9V16.5M14 11.5H16.6C17.4401 11.5 17.8601 11.5 18.181 11.6635C18.4632 11.8073 18.6927 12.0368 18.8365 12.319C19 12.6399 19 13.0599 19 13.9V16.5M14 11.5V21.5M14 21.5H16.6C17.4401 21.5 17.8601 21.5 18.181 21.3365C18.4632 21.1927 18.6927 20.9632 18.8365 20.681C19 20.3601 19 19.9401 19 19.1V16.5M14 21.5H11.4C10.5599 21.5 10.1399 21.5 9.81901 21.3365C9.53677 21.1927 9.3073 20.9632 9.16349 20.681C9 20.3601 9 19.9401 9 19.1V16.5M19 16.5H9"
public let fileGlyphExcelStrokeWidth: Double = 1.2

public let fileGlyphHtmlMarkPath =
    "M13.9994 9.68298C17.212 9.68298 19.8167 12.2872 19.8168 15.4997C19.8168 18.7123 17.2121 21.3171 13.9994 21.3171C10.7869 21.3169 8.18274 18.7122 8.18274 15.4997C8.1829 12.2873 10.787 9.68315 13.9994 9.68298ZM9.26213 16.0247C9.47025 17.9241 10.7936 19.4876 12.5639 20.0463C12.42 19.7977 12.2952 19.5152 12.1879 19.2116C11.885 18.3541 11.693 17.2434 11.6424 16.0247H9.26213ZM16.3565 16.0247C16.3059 17.2434 16.1145 18.3542 15.8116 19.2116C15.7044 19.5151 15.5788 19.7971 15.435 20.0456C17.2054 19.487 18.5293 17.9242 18.7374 16.0247H16.3565ZM12.6938 16.0247C12.7439 17.1459 12.9212 18.1334 13.1784 18.8616C13.332 19.2962 13.503 19.61 13.6686 19.805C13.834 19.9996 13.9473 20.0256 13.9994 20.0258C14.0514 20.0258 14.1651 20.0002 14.331 19.805C14.4966 19.61 14.6676 19.2962 14.8211 18.8616C15.0784 18.1334 15.2557 17.1459 15.3058 16.0247H12.6938ZM13.9994 10.733C13.9473 10.7331 13.834 10.7598 13.6686 10.9545C13.503 11.1494 13.3319 11.4633 13.1784 11.8978C12.903 12.6777 12.7188 13.7545 12.6849 14.9747H15.3147C15.2808 13.7545 15.0966 12.6777 14.8211 11.8978C14.6676 11.4633 14.4965 11.1494 14.331 10.9545C14.1651 10.7593 14.0514 10.733 13.9994 10.733ZM15.5888 11.0051C15.6701 11.1756 15.7444 11.3576 15.8116 11.5478C16.1343 12.4613 16.3308 13.6619 16.3647 14.9747H18.7374C18.5352 13.1307 17.2817 11.6036 15.5888 11.0051ZM12.4101 11.0051C10.7174 11.6037 9.46428 13.1308 9.26213 14.9747H11.6349C11.6688 13.6619 11.8652 12.4613 12.1879 11.5478C12.2551 11.3577 12.3288 11.1756 12.4101 11.0051Z"

public let fileGlyphImagePeakPath =
    "M10.4212 15.9204C10.5756 15.6558 10.9579 15.6558 11.1123 15.9204L13.6493 20.2696C13.8048 20.5362 13.6125 20.8711 13.3037 20.8711H8.22974C7.92102 20.8711 7.72868 20.5362 7.88423 20.2696L10.4212 15.9204Z"
public let fileGlyphImageHillPath =
    "M15.4981 13.186C15.6505 12.9117 16.0451 12.9117 16.1975 13.186L20.1368 20.2769C20.2849 20.5435 20.0922 20.8711 19.7872 20.8711H11.9084C11.6034 20.8711 11.4107 20.5435 11.5588 20.2769L15.4981 13.186Z"
public let fileGlyphImageSunPath =
    "M11.8603 11.3997C11.8603 12.286 11.1418 13.0045 10.2555 13.0045C9.36924 13.0045 8.65076 12.286 8.65076 11.3997C8.65076 10.5134 9.36924 9.79492 10.2555 9.79492C11.1418 9.79492 11.8603 10.5134 11.8603 11.3997Z"

public let fileGlyphMarkdownMarkPath =
    "M8.7588 19.5V14.6H9.8998L11.9298 17.932H11.3278L13.3018 14.6H14.4428L14.4568 19.5H13.1828L13.1688 16.539H13.3858L11.9088 19.017H11.2928L9.7738 16.539H10.0398V19.5H8.7588ZM15.4375 19.5V14.6H17.7545C18.2958 14.6 18.7718 14.7003 19.1825 14.901C19.5932 15.1017 19.9128 15.384 20.1415 15.748C20.3748 16.112 20.4915 16.546 20.4915 17.05C20.4915 17.5493 20.3748 17.9833 20.1415 18.352C19.9128 18.716 19.5932 18.9983 19.1825 19.199C18.7718 19.3997 18.2958 19.5 17.7545 19.5H15.4375ZM16.8235 18.394H17.6985C17.9785 18.394 18.2212 18.3427 18.4265 18.24C18.6365 18.1327 18.7998 17.9787 18.9165 17.778C19.0332 17.5727 19.0915 17.33 19.0915 17.05C19.0915 16.7653 19.0332 16.5227 18.9165 16.322C18.7998 16.1213 18.6365 15.9697 18.4265 15.867C18.2212 15.7597 17.9785 15.706 17.6985 15.706H16.8235V18.394Z"

public let fileGlyphPdfMarkPath =
    "M6.80616 19.5V14.6H9.04616C9.49416 14.6 9.87916 14.6723 10.2012 14.817C10.5278 14.9617 10.7798 15.1717 10.9572 15.447C11.1345 15.7177 11.2232 16.0397 11.2232 16.413C11.2232 16.7817 11.1345 17.1013 10.9572 17.372C10.7798 17.6427 10.5278 17.8527 10.2012 18.002C9.87916 18.1467 9.49416 18.219 9.04616 18.219H7.57616L8.19216 17.617V19.5H6.80616ZM8.19216 17.764L7.57616 17.127H8.96216C9.2515 17.127 9.46616 17.064 9.60616 16.938C9.75083 16.812 9.82316 16.637 9.82316 16.413C9.82316 16.1843 9.75083 16.007 9.60616 15.881C9.46616 15.755 9.2515 15.692 8.96216 15.692H7.57616L8.19216 15.055V17.764ZM11.8989 19.5V14.6H14.2159C14.7573 14.6 15.2333 14.7003 15.6439 14.901C16.0546 15.1017 16.3743 15.384 16.6029 15.748C16.8363 16.112 16.9529 16.546 16.9529 17.05C16.9529 17.5493 16.8363 17.9833 16.6029 18.352C16.3743 18.716 16.0546 18.9983 15.6439 19.199C15.2333 19.3997 14.7573 19.5 14.2159 19.5H11.8989ZM13.2849 18.394H14.1599C14.4399 18.394 14.6826 18.3427 14.8879 18.24C15.0979 18.1327 15.2613 17.9787 15.3779 17.778C15.4946 17.5727 15.5529 17.33 15.5529 17.05C15.5529 16.7653 15.4946 16.5227 15.3779 16.322C15.2613 16.1213 15.0979 15.9697 14.8879 15.867C14.6826 15.7597 14.4399 15.706 14.1599 15.706H13.2849V18.394ZM17.6821 19.5V14.6H21.5251V15.671H19.0681V19.5H17.6821ZM18.9701 17.82V16.749H21.2311V17.82H18.9701Z"

public let fileGlyphPptMarkPath =
    "M11.0132 20.5V13.5H14.2132C14.8532 13.5 15.4032 13.6033 15.8632 13.81C16.3299 14.0167 16.6899 14.3167 16.9432 14.71C17.1966 15.0967 17.3232 15.5567 17.3232 16.09C17.3232 16.6167 17.1966 17.0733 16.9432 17.46C16.6899 17.8467 16.3299 18.1467 15.8632 18.36C15.4032 18.5667 14.8532 18.67 14.2132 18.67H12.1132L12.9932 17.81V20.5H11.0132ZM12.9932 18.02L12.1132 17.11H14.0932C14.5066 17.11 14.8132 17.02 15.0132 16.84C15.2199 16.66 15.3232 16.41 15.3232 16.09C15.3232 15.7633 15.2199 15.51 15.0132 15.33C14.8132 15.15 14.5066 15.06 14.0932 15.06H12.1132L12.9932 14.15V18.02Z"

public let fileGlyphVideoMarkPath =
    "M17.5 14.634C18.1667 15.0189 18.1667 15.9811 17.5 16.366L11.5 19.8301C10.8333 20.215 10 19.7339 10 18.9641L10 12.0359C10 11.2661 10.8333 10.785 11.5 11.1699L17.5 14.634Z"

public let fileGlyphWordMarkPath =
    "M10.5118 20.5L8.24179 13.5H10.2818L12.1918 19.56H11.1618L13.1718 13.5H14.9918L16.8918 19.56H15.9018L17.8718 13.5H19.7618L17.4918 20.5H15.3718L13.7518 15.35H14.3218L12.6318 20.5H10.5118Z"

public func fileTypeUsesLargeMark(_ kind: String) -> Bool {
    kind == "markdown" || kind == "pdf" || kind == "ppt" || kind == "word"
}

public func fileTypeUsesCenteredMark(_ kind: String) -> Bool {
    kind == "html" || kind == "image" || kind == "video"
}

/// Desktop `ui-sidebar-files` header: `IconPauseOutlineRegular` when auto-refresh
/// is on, otherwise `IconPlayOutlineRegular`; reload is `IconRefreshOutlineRegular`.
public func filesAutoRefreshSymbol(enabled: Bool) -> String {
    enabled ? "official.pauseOutline" : "official.playOutline"
}

public func filesReloadSymbol() -> String { "official.refreshOutline" }

public func isForbiddenFilesToolbarSystemSymbol(_ name: String) -> Bool {
    name == "pause" || name == "play.fill" || name == "play" || name == "arrow.clockwise"
}

/// Desktop `IconPlayOutlineArtwork` Regular. Ring matches the 16×16 warning circle.
public let iconPlayOutlineTrianglePath =
    "M10.3329 7.91346C10.3996 7.95195 10.3996 8.04818 10.3329 8.08667L6.78304 10.1362C6.71638 10.1747 6.63304 10.1266 6.63304 10.0496L6.63304 5.95055C6.63304 5.87357 6.71638 5.82546 6.78304 5.86395L10.3329 7.91346Z"

/// Desktop `IconPauseOutlineArtwork` Regular.
public let iconPauseOutlineLeftPath = "M6.5 5V11"
public let iconPauseOutlineRightPath = "M9.5 5V11"

private let fileTypeNames: [String: String] = [
    ".bash_profile": "shell",
    ".bashrc": "shell",
    ".env": "env",
    ".gitattributes": "git",
    ".gitconfig": "git",
    ".gitignore": "git",
    ".gitmodules": "git",
    ".mailmap": "git",
    ".profile": "shell",
    ".zprofile": "shell",
    ".zshrc": "shell",
    "bsdmakefile": "makefile",
    "cmakelists.txt": "cmake",
    "commit_editmsg": "git",
    "compose.yaml": "docker",
    "compose.yml": "docker",
    "docker-compose.yaml": "docker",
    "docker-compose.yml": "docker",
    "dockerfile": "docker",
    "gemfile": "ruby",
    "gnumakefile": "makefile",
    "guardfile": "ruby",
    "makefile": "makefile",
    "npm-shrinkwrap.json": "node",
    "package-lock.json": "node",
    "package.json": "node",
    "podfile": "ruby",
    "rakefile": "ruby",
    "changelog": "markdown",
    "contributing": "markdown",
    "readme": "markdown",
]

private let fileTypeSuffixes: [String: String] = [
    ".component.ts": "angular",
    ".component.html": "angular",
    ".directive.ts": "angular",
    ".service.ts": "angular",
    ".module.ts": "angular",
    ".pipe.ts": "angular",
    ".guard.ts": "angular",
    ".interceptor.ts": "angular",
    ".dockerfile": "docker",
]

private let fileTypeExtensions: [String: String] = [
    "scss": "code", "sass": "code", "less": "code", "vue": "vue", "svelte": "svelte",
    "astro": "code", "bat": "code", "cmd": "code",
    "csv": "excel", "tsv": "excel",
    "html": "html", "htm": "html",
    "png": "image", "jpg": "image", "jpeg": "image", "gif": "image", "svg": "image",
    "webp": "image", "avif": "image", "bmp": "image", "ico": "image", "tif": "image",
    "tiff": "image", "heic": "image", "heif": "image",
    "md": "markdown", "mdx": "markdown", "markdown": "markdown",
    "pdf": "pdf",
    "ppt": "ppt", "pptx": "ppt", "key": "ppt",
    "mp4": "video", "mov": "video", "m4v": "video", "webm": "video", "mkv": "video",
    "avi": "video", "mpg": "video", "mpeg": "video",
    "doc": "word", "docx": "word", "rtf": "word", "odt": "word", "pages": "word",
    "xls": "excel", "xlsx": "excel", "xlsm": "excel", "xlsb": "excel",
    "xlt": "excel", "xltx": "excel", "xltm": "excel", "ods": "excel", "ots": "excel",
    "fods": "excel", "numbers": "excel",
    "bash": "shell", "c": "c", "c++": "cpp", "cc": "cpp", "cfg": "ini",
    "cjs": "javascript", "clj": "clojure", "cljc": "clojure", "cljs": "clojure",
    "cmake": "cmake", "cpp": "cpp", "cs": "csharp", "csh": "shell", "css": "css",
    "csx": "csharp", "cts": "typescript", "cxx": "cpp", "dart": "dart", "dtd": "xml",
    "edn": "clojure", "env": "env", "erl": "erlang", "es6": "javascript",
    "escript": "erlang", "ex": "elixir", "exs": "elixir", "fish": "shell",
    "gemspec": "ruby", "go": "go", "gql": "graphql", "graphql": "graphql",
    "h": "c", "h++": "cpp", "hh": "cpp", "hpp": "cpp", "hrl": "erlang",
    "hs": "haskell", "hxx": "cpp", "ini": "ini", "ipp": "cpp", "java": "java",
    "js": "javascript", "json": "json", "json5": "json", "jsonc": "json",
    "jsx": "react", "ksh": "shell", "kt": "kotlin", "kts": "kotlin",
    "lhs": "haskell", "lua": "lua", "m": "objective-c", "mak": "makefile",
    "mjs": "javascript", "mk": "makefile", "mm": "objective-c", "mts": "typescript",
    "node": "node", "pch": "objective-c", "php": "php", "php3": "php",
    "php4": "php", "php5": "php", "phps": "php", "phtml": "php",
    "pl": "perl", "plist": "xml", "pm": "perl", "pod": "perl",
    "proto": "protobuf", "ps1": "powershell", "psd1": "powershell", "psm1": "powershell",
    "py": "python", "pyi": "python", "pyw": "python", "pyx": "python",
    "r": "r", "rake": "ruby", "rb": "ruby", "rmd": "r", "rs": "rust",
    "sc": "scala", "scala": "scala", "sh": "shell", "sol": "solidity",
    "sql": "sql", "swift": "swift", "t": "perl", "tcsh": "shell",
    "toml": "toml", "tpp": "cpp", "ts": "typescript", "tsx": "react",
    "wasm": "wasm", "wast": "wasm", "wat": "wasm",
    "xml": "xml", "xsd": "xml", "xsl": "xml", "xslt": "xml",
    "yaml": "yaml", "yml": "yaml", "zig": "zig", "zsh": "shell",
]
