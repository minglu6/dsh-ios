import SwiftUI
import DSHProtocol

struct FileTypeIcon: View {
    let path: String
    var type = "file"
    var openable = true
    var expanded: Bool? = nil

    var body: some View {
        let kind = fileTypeKind(path: path, type: type)
        let symbol = kind == "folder"
            ? fileTreeFolderSymbol(expanded: expanded ?? false)
            : fileTypeSymbol(kind)
        Image(systemName: symbol)
            .foregroundStyle(openable ? Color(hex: 0xFF000000 | fileTypeAccent(kind)) : T.text3)
            .frame(width: 20)
            .accessibilityHidden(true)
    }
}
