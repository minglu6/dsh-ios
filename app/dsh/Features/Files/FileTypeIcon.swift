import SwiftUI
import DSHProtocol

struct FileTypeIcon: View {
    let path: String
    var type = "file"
    var openable = true

    var body: some View {
        let kind = fileTypeKind(path: path, type: type)
        Image(systemName: fileTypeSymbol(kind))
            .foregroundStyle(openable ? Color(hex: 0xFF000000 | fileTypeAccent(kind)) : T.text3)
            .frame(width: 20)
            .accessibilityHidden(true)
    }
}
