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
    @State private var renderError: String?
    @State private var reloadID = 0

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
        ZStack {
            CodePreviewWebView(path: path, text: text, options: encodedOptions, reloadID: reloadID) {
                renderError = $0
            }
            if let renderError {
                VStack(alignment: .leading, spacing: 12) {
                    Text(renderError).foregroundStyle(T.err)
                        .accessibilityIdentifier("codePreviewError")
                    Button(L.docRetry()) { reloadID += 1 }
                        .accessibilityIdentifier("codePreviewRetry")
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(T.surface)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.surface)
    }
}

private struct CodePreviewWebView: UIViewRepresentable {
    let path: String
    let text: String
    let options: String
    let reloadID: Int
    let onError: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.ensureHandler()
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.handler, forURLScheme: codePreviewScheme)
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController.add(context.coordinator, name: "codePreview")
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.accessibilityIdentifier = "codePreviewViewport"
        view.navigationDelegate = context.coordinator
        context.coordinator.view = view
        context.coordinator.onError = onError
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.view = uiView
        context.coordinator.onError = onError
        context.coordinator.update(path: path, text: text, options: options)
        context.coordinator.loadIfNeeded(reloadID: reloadID)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.destroy()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
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
        var onError: ((String?) -> Void)?
        private var loadedID: Int?
        private var inFlight = false
        private var failed = false
        private var loadGeneration = 0
        private var readyTimeout: DispatchWorkItem?
        private var navigation: WKNavigation?

        func ensureHandler() {
            handler.assets = CodePreviewSchemeHandler.loadAssets()
        }

        func update(path: String, text: String, options: String) {
            self.path = path
            self.text = text
            self.options = options
            flush()
        }

        func loadIfNeeded(reloadID: Int) {
            guard !destroyed, loadedID != reloadID, let view,
                  let url = URL(string: codePreviewSchemeURL) else { return }
            loadedID = reloadID
            loadGeneration += 1
            ready = false
            failed = false
            inFlight = false
            sentPath = nil
            sentText = nil
            sentOptions = nil
            publishError(nil)
            readyTimeout?.cancel()
            let generation = loadGeneration
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, self.loadGeneration == generation, !self.ready else { return }
                self.fail("Code preview initialization timed out.")
            }
            readyTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
            let controller = view.configuration.userContentController
            controller.removeAllUserScripts()
            controller.addUserScript(WKUserScript(
                source: "Object.defineProperty(window, 'codePreviewLoadID', { value: \(generation) });",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
            navigation = view.load(URLRequest(url: url))
        }

        private func publishError(_ message: String?) {
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.destroyed else { return }
                self.onError?(message)
            }
        }

        private func fail(_ message: String) {
            guard !destroyed else { return }
            failed = true
            ready = false
            readyTimeout?.cancel()
            publishError(message)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            if url?.scheme == codePreviewScheme {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !destroyed, !failed, message.frameInfo.isMainFrame,
                  message.webView === view,
                  message.frameInfo.request.url?.absoluteString == codePreviewSchemeURL,
                  let payload = message.body as? [String: Any],
                  payload["loadID"] as? Int == loadGeneration else { return }
            switch payload["type"] as? String {
            case "ready":
                ready = true
                readyTimeout?.cancel()
                flush()
            case "error":
                fail(payload["message"] as? String ?? "Code preview JavaScript failed.")
            default: break
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard navigation === self.navigation else { return }
            fail(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard navigation === self.navigation else { return }
            fail(error.localizedDescription)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            fail("Code preview process terminated.")
        }

        private func flush() {
            guard ready, !destroyed, !failed, !inFlight, let view,
                  let path, let text, let options,
                  sentPath != path || sentText != text || sentOptions != options else { return }
            let document = sentPath != path || sentText != text
                ? codePreviewDocumentScript(path: path, text: text) : ""
            let script = """
            (() => {
                window.codePreview.setOptions(\(options));
                \(document)
                return window.codePreviewBridge.ack();
            })()
            """
            inFlight = true
            let generation = loadGeneration
            view.evaluateJavaScript(script) { [weak self] result, error in
                guard let self, !self.destroyed, self.loadGeneration == generation else { return }
                self.inFlight = false
                guard !self.failed else { return }
                if let error {
                    self.fail(error.localizedDescription)
                    return
                }
                guard let ack = result as? [String: Any],
                      ack["ready"] as? Bool == true,
                      ack["textLength"] as? Int == text.utf16.count else {
                    self.fail("Code preview did not acknowledge the source document.")
                    return
                }
                self.sentPath = path
                self.sentText = text
                self.sentOptions = options
                self.flush()
            }
        }

        func destroy() {
            destroyed = true
            ready = false
            readyTimeout?.cancel()
            view?.configuration.userContentController.removeScriptMessageHandler(forName: "codePreview")
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
