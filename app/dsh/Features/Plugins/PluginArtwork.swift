import SwiftUI
import WebKit
import DSHProtocol

struct PluginArtwork: View {
    let kind: String
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(T.fill2)
            Image(systemName: symbol).font(.system(size: size * 0.45)).foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }

    private var symbol: String {
        switch kind {
        case "subagent": return "person.2"
        case "search": return "magnifyingglass"
        case "loop": return "arrow.triangle.2.circlepath"
        case "terminal": return "terminal"
        default: return "puzzlepiece.extension"
        }
    }

    private var color: Color {
        switch kind {
        case "subagent": return Color(red: 0.27, green: 0.90, blue: 0.64)
        case "search": return Color(red: 0.41, green: 0.63, blue: 1)
        case "loop": return Color(red: 0.66, green: 0.59, blue: 0.99)
        case "terminal": return Color(red: 0.40, green: 0.62, blue: 1)
        default: return T.accent
        }
    }
}

struct PluginMetadataArtwork: View {
    let icon: String?
    var size: CGFloat = 36

    var body: some View {
        if let xml = pluginMetadataSVG(icon) {
            PluginSVGView(xml: xml).frame(width: size, height: size)
        } else {
            PluginArtwork(kind: "default", size: size)
        }
    }
}

private struct PluginSVGView: UIViewRepresentable {
    let xml: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let html = "<html><head><meta name=viewport content='width=36,initial-scale=1'></head><body style='margin:0;background:transparent'>\(xml)</body></html>"
        view.loadHTMLString(html, baseURL: nil)
    }
}
