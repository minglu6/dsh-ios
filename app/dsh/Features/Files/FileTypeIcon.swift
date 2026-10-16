import SwiftUI
import DSHProtocol

/// Desktop file-icon kind → SF Symbol. Colors come from `fileTypeAccent`.
func fileTypeSymbol(_ kind: String) -> String {
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
    case "other": return "doc"
    case "python", "go", "rust", "java", "kotlin", "swift", "ruby", "docker",
         "git", "node", "react", "vue", "css", "yaml", "shell", "c", "cpp",
         "csharp", "php", "sql", "toml", "ini", "env", "angular", "svelte",
         "dart", "elixir", "erlang", "haskell", "lua", "perl", "r", "scala",
         "solidity", "zig", "wasm", "graphql", "cmake", "makefile",
         "powershell", "protobuf", "objective-c", "clojure":
        return "doc.fill"
    default:
        preconditionFailure("unmapped file-icon kind: \(kind)")
    }
}

struct FileTypeIcon: View {
    let path: String
    var directory = false
    var openable = true

    var body: some View {
        let kind = directory ? "folder" : classifyFileType(path)
        Image(systemName: fileTypeSymbol(kind))
            .foregroundStyle(openable ? Color(hex: 0xFF000000 | fileTypeAccent(kind)) : T.text3)
            .frame(width: 20)
            .accessibilityHidden(true)
    }
}
