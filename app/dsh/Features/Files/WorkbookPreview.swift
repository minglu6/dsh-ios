import SwiftUI
import WebKit
import DSHProtocol

private let workbookScheme = "dsh-workbook-preview"
private let workbookSchemeURL = workbookURL.replacingOccurrences(of: "https://", with: "\(workbookScheme)://")

private func workbookCss(_ color: Color) -> String {
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(
        format: "#%02x%02x%02x%02x",
        Int((r * 255).rounded()),
        Int((g * 255).rounded()),
        Int((b * 255).rounded()),
        Int((a * 255).rounded())
    )
}

struct WorkbookPreviewBody: View {
    let path: String
    let bytes: Data

    @Environment(\.colorScheme) private var colorScheme

    private var encodedOptions: String {
        let tokens: [String: String] = [
            "--dsw-alias-label-primary": workbookCss(T.ink),
            "--dsw-alias-label-secondary": workbookCss(T.text2),
            "--dsw-alias-label-tertiary": workbookCss(T.text3),
            "--dsw-alias-bg-document-preview": workbookCss(T.documentPreviewBg),
            "--dsw-alias-state-warn-label": workbookCss(T.warnText),
            "--dsw-alias-state-warn-tertiary": workbookCss(T.warnTint),
            "--dsw-alias-interactive-bg-hover": workbookCss(T.hoverBg),
            "--dsw-alias-interactive-bg-active": workbookCss(T.interactiveBgActive),
            "--dsw-alias-tooltip-bg": workbookCss(T.tooltipBg),
        ]
        let options: [String: Any] = [
            "dark": ThemeStateHolder.shared.dark,
            "locale": L.en ? "en" : "zh",
            "tokens": tokens,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: options, options: []),
              let encoded = String(data: data, encoding: .utf8) else {
            preconditionFailure("workbook preview options JSON must encode")
        }
        return encoded
    }

    var body: some View {
        WorkbookPreviewWebView(path: path, bytes: bytes, options: encodedOptions)
            .background(T.documentPreviewBg)
    }
}

private struct WorkbookPreviewWebView: UIViewRepresentable {
    let path: String
    let bytes: Data
    let options: String

    func makeCoordinator() -> Coordinator { Coordinator(bytes: bytes) }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.ensureHandler()
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.handler, forURLScheme: workbookScheme)
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        context.coordinator.view = view
        if let url = URL(string: workbookSchemeURL) {
            view.load(URLRequest(url: url))
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.view = uiView
        context.coordinator.bytes = bytes
        context.coordinator.handler.bytes = bytes
        context.coordinator.handler.format = (path as NSString).pathExtension.lowercased()
        context.coordinator.update(path: path, options: options)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.destroy()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let handler: WorkbookSchemeHandler
        weak var view: WKWebView?
        var bytes: Data
        private var ready = false
        private var destroyed = false
        private var path: String?
        private var options: String?
        private var sentOptions: String?
        private var sentDocument = false
        private let documentURL = "\(workbookOrigin)/document/\(UUID().uuidString)"

        init(bytes: Data) {
            self.bytes = bytes
            self.handler = WorkbookSchemeHandler(bytes: bytes, documentURL: documentURL)
        }

        func ensureHandler() {
            handler.assets = WorkbookSchemeHandler.loadAssets()
            handler.bytes = bytes
        }

        func update(path: String, options: String) {
            self.path = path
            self.options = options
            handler.format = (path as NSString).pathExtension.lowercased()
            flush()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.request.url?.scheme == workbookScheme {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if !destroyed && webView.url?.absoluteString == workbookSchemeURL {
                ready = true
                flush()
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            nil
        }

        private func flush() {
            guard ready, !destroyed, let view, let options else { return }
            if sentOptions != options {
                view.evaluateJavaScript("window.workbookPreview.setOptions(\(options));", completionHandler: nil)
                sentOptions = options
            }
            if !sentDocument, let path {
                let format = (path as NSString).pathExtension.lowercased()
                let schemeDocument = documentURL.replacingOccurrences(of: "https://", with: "\(workbookScheme)://")
                let doc = jsonString(schemeDocument)
                let fmt = jsonString(format)
                view.evaluateJavaScript("window.workbookPreview.setDocument(\(doc),\(fmt));", completionHandler: nil)
                sentDocument = true
            }
        }

        func destroy() {
            destroyed = true
            ready = false
            view?.evaluateJavaScript("window.workbookPreview?.dispose();", completionHandler: nil)
            view?.stopLoading()
            view?.navigationDelegate = nil
            view?.uiDelegate = nil
            view = nil
        }

        private func jsonString(_ value: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
                  let encoded = String(data: data, encoding: .utf8) else {
                preconditionFailure("workbook document JSON must encode")
            }
            return encoded
        }
    }
}

final class WorkbookSchemeHandler: NSObject, WKURLSchemeHandler {
    var assets: Set<String> = []
    var bytes: Data
    var format: String = ""
    let documentURL: String

    init(bytes: Data, documentURL: String) {
        self.bytes = bytes
        self.documentURL = documentURL
    }

    static func loadAssets() -> Set<String> {
        let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "WorkbookPreviewAssets")
            ?? Bundle.main.url(forResource: "manifest", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url),
              let names = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            preconditionFailure("workbook-preview manifest.json is required")
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
        let mainFrame = https == workbookURL
        guard let resource = workbookPreviewResourceFor(url: https, mainFrame: mainFrame, assets: assets, documentUrl: documentURL) else {
            fail(urlSchemeTask, status: 403)
            return
        }
        if resource == "@document" {
            if bytes.count > workbookMaxBytes || !["xls", "xlsx"].contains(format) {
                fail(urlSchemeTask, status: 403)
                return
            }
            respond(urlSchemeTask, url: url, mime: "application/octet-stream", data: bytes)
            return
        }
        guard let file = Self.assetURL(resource), let data = try? Data(contentsOf: file) else {
            fail(urlSchemeTask, status: 404)
            return
        }
        let mime: String
        switch (resource as NSString).pathExtension {
        case "html": mime = "text/html"
        case "css": mime = "text/css"
        default: mime = "text/javascript"
        }
        respond(urlSchemeTask, url: url, mime: mime, data: data)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func respond(_ task: WKURLSchemeTask, url: URL, mime: String, data: Data) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mime.hasPrefix("text/") ? "\(mime); charset=utf-8" : mime,
                "Cache-Control": "no-store",
                "Content-Length": "\(data.count)",
                "X-Content-Type-Options": "nosniff",
            ]
        )!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    private func fail(_ task: WKURLSchemeTask, status: Int) {
        let url = task.request.url ?? URL(string: "\(workbookScheme)://blocked")!
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
        return Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "WorkbookPreviewAssets")
            ?? Bundle.main.url(forResource: base, withExtension: ext)
    }
}
