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

/// SF Symbol for a file-icon kind. Unknown kinds share the generic document glyph.
public func fileTypeSymbol(_ kind: String) -> String {
    switch kind {
    case "folder": return "folder.fill"
    case "markdown": return "doc.richtext"
    case "image": return "photo"
    case "pdf": return "doc.fill"
    case "excel": return "tablecells"
    case "word": return "doc.text.fill"
    case "ppt": return "rectangle.on.rectangle"
    case "video": return "film"
    case "html", "code", "xml": return "chevron.left.forwardslash.chevron.right"
    case "javascript", "typescript", "json": return "curlybraces"
    case "warning": return "exclamationmark.triangle"
    case "other": return "doc"
    case "python", "go", "rust", "java", "kotlin", "swift", "ruby", "docker",
         "git", "node", "react", "vue", "css", "yaml", "shell", "c", "cpp",
         "csharp", "php", "sql", "toml", "ini", "env", "angular", "svelte",
         "dart", "elixir", "erlang", "haskell", "lua", "perl", "r", "scala",
         "solidity", "zig", "wasm", "graphql", "cmake", "makefile",
         "powershell", "protobuf", "objective-c", "clojure":
        return "doc.fill"
    default:
        return "doc"
    }
}

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
