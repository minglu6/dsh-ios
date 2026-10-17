import SwiftUI
import DSHProtocol

struct FileTypeIcon: View {
    let path: String
    var type = "file"
    var openable = true
    var expanded: Bool? = nil

    var body: some View {
        let kind = fileTypeKind(path: path, type: type)
        let color = openable ? Color(hex: 0xFF000000 | fileTypeAccent(kind)) : T.text3
        Group {
            if kind == "folder" {
                OfficialGlyph(
                    kind: (expanded ?? false) ? .folderOpen : .folderClose,
                    size: 16,
                    color: color
                )
            } else {
                Image(systemName: fileTypeSymbol(kind))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 20)
    }
}
