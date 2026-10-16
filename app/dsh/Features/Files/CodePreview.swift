import SwiftUI
import WebKit
import DSHProtocol

/// WKWebView cannot intercept `https://`; load the same assets over `dsh-code-preview://`.
private let codePreviewScheme = "dsh-code-preview"
private let codePreviewSchemeURL = codePreviewURL.replacingOccurrences(of: "https://", with: "\(codePreviewScheme)://")

private func previewCss(_ color: Color) -> String {
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "#%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
}

/// Android `previewCodeFontFamily`: bundled Meslo is CSS `'DSH Meslo'` served at `/font/meslo.ttf`.
private func previewCodeFontFamily(_ value: String) -> String {
    let meslo = "\"DSH Meslo\", monospace"
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return meslo }
    let first = trimmed.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) ?? ""
    switch first.lowercased() {
    case "monospace", "ui-monospace": return "monospace"
    case "sans-serif", "system-ui", "ui-sans-serif", "ui-rounded", "-apple-system", "blinkmacsystemfont", "emoji":
        return "sans-serif"
    case "serif", "ui-serif", "math", "fangsong": return "serif"
    case "cursive": return "cursive"
    case "meslolgl dz", "meslolgl dz nerd font", "meslolgl dz nerd font mono",
         "meslolgs nf", "meslolgs nerd font":
        return meslo
    default:
        let normalized = normalizeFontFamily(value)
        return normalized.isEmpty ? meslo : "\(normalized), \(meslo)"
    }
}

struct CodePreviewBody: View {
    let path: String
    let text: String
    let wrap: Bool
    let plain: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var encodedOptions: String {
        let options: [String: Any] = [
            "wrap": wrap,
            "plain": plain,
            "dark": ThemeStateHolder.shared.dark,
            "fontSize": AppPrefs.codeFontSize,
            "fontFamily": previewCodeFontFamily(AppPrefs.codeFontFamily),
            "foreground": previewCss(T.ink),
            "muted": previewCss(T.text3),
            "background": previewCss(T.surface),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: options, options: []),
              let encoded = String(data: data, encoding: .utf8) else {
            preconditionFailure("code preview options JSON must encode")
        }
        return encoded
    }

    var body: some View {
        CodePreviewWebView(path: path, text: text, options: encodedOptions)
            .background(T.surface)
    }
}

private struct CodePreviewWebView: UIViewRepresentable {
    let path: String
    let text: String
    let options: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.ensureHandler()
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.handler, forURLScheme: codePreviewScheme)
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.navigationDelegate = context.coordinator
        context.coordinator.view = view
        if let url = URL(string: codePreviewSchemeURL) {
            view.load(URLRequest(url: url))
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.view = uiView
        context.coordinator.update(path: path, text: text, options: options)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.destroy()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let handler = CodePreviewSchemeHandler()
        weak var view: WKWebView?
        private var ready = false
        private var destroyed = false
        private var path: String?
        private var text: String?
        private var options: String?
        private var sentPath: String?
        private var sentText: String?
        private var sentOptions: String?

        func ensureHandler() {
            handler.assets = CodePreviewSchemeHandler.loadAssets()
        }

        func update(path: String, text: String, options: String) {
            self.path = path
            self.text = text
            self.options = options
            flush()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            if url?.scheme == codePreviewScheme {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if !destroyed && webView.url?.absoluteString == codePreviewSchemeURL {
                ready = true
                flush()
            }
        }

        private func flush() {
            guard ready, !destroyed, let view,
                  let path, let text, let options else { return }
            if sentOptions != options {
                view.evaluateJavaScript("window.codePreview.setOptions(\(options));", completionHandler: nil)
                sentOptions = options
            }
            if sentPath != path || sentText != text {
                view.evaluateJavaScript(codePreviewDocumentScript(path: path, text: text), completionHandler: nil)
                sentPath = path
                sentText = text
            }
        }

        func destroy() {
            destroyed = true
            ready = false
            view?.stopLoading()
            view?.navigationDelegate = nil
            view = nil
        }
    }
}

final class CodePreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    var assets: Set<String> = []

    static func loadAssets() -> Set<String> {
        let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "CodePreviewAssets")
            ?? Bundle.main.url(forResource: "manifest", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url),
              let names = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            preconditionFailure("code-preview manifest.json is required")
        }
        return Set(names)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let method = urlSchemeTask.request.httpMethod ?? "GET"
        guard method == "GET", let url = urlSchemeTask.request.url else {
            fail(urlSchemeTask, status: 403)
            return
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        guard let https = components?.string else {
            fail(urlSchemeTask, status: 403)
            return
        }
        let mainFrame = https == codePreviewURL
        guard let asset = codePreviewAssetFor(url: https, mainFrame: mainFrame, assets: assets) else {
            fail(urlSchemeTask, status: 403)
            return
        }
        let data: Data
        if asset == "@meslo" {
            guard let font = TerminalTypeface.bundledFontData() else {
                fail(urlSchemeTask, status: 404)
                return
            }
            data = font
        } else {
            guard let file = Self.assetURL(asset), let bytes = try? Data(contentsOf: file) else {
                fail(urlSchemeTask, status: 404)
                return
            }
            data = bytes
        }
        let mime: String
        switch (asset as NSString).pathExtension {
        case "html": mime = "text/html"
        case "js": mime = "text/javascript"
        case "css": mime = "text/css"
        default: mime = "font/ttf"
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "\(mime); charset=utf-8",
                "Cache-Control": "no-store",
                "X-Content-Type-Options": "nosniff",
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func fail(_ task: WKURLSchemeTask, status: Int) {
        let url = task.request.url ?? URL(string: "\(codePreviewScheme)://blocked")!
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!
        task.didReceive(response)
        task.didReceive(Data())
        task.didFinish()
    }

    private static func assetURL(_ name: String) -> URL? {
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        return Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "CodePreviewAssets")
            ?? Bundle.main.url(forResource: base, withExtension: ext)
    }
}
