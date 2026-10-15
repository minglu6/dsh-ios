import SwiftUI
import WebKit
import CryptoKit
import DSHProtocol

struct BrowserPanel: View {
    @ObservedObject var model: AppModel
    let sessionKey: String
    var onDismiss: () -> Void

    var body: some View {
        BrowserPanelContent(model: model, sessionKey: sessionKey, onDismiss: onDismiss)
            .id(sessionKey)
    }
}

private struct BrowserPanelContent: View {
    @ObservedObject var model: AppModel
    let sessionKey: String
    var onDismiss: () -> Void

    @StateObject private var state: BrowserPageState
    @FocusState private var addressFocused: Bool

    init(model: AppModel, sessionKey: String, onDismiss: @escaping () -> Void) {
        self.model = model
        self.sessionKey = sessionKey
        self.onDismiss = onDismiss
        _state = StateObject(wrappedValue: BrowserPageState(sessionKey: sessionKey, policy: BrowserPanelContent.policy(for: model.profiles)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                toolbar
                if state.loading {
                    ProgressView().progressViewStyle(.linear).tint(T.accent)
                } else {
                    Divider()
                }
                if let error = state.error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(T.err)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                if !state.started {
                    idle
                } else {
                    BrowserWebView(state: state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(T.bg)
            .navigationTitle(state.title.isEmpty ? L.t("浏览器", "Browser") : state.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close(), action: onDismiss)
                }
            }
        }
        .onChange(of: model.profiles) { profiles in
            state.policy = Self.policy(for: profiles)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            IconHit(system: "chevron.left", label: L.t("后退", "Back"), enabled: state.canBack, tint: state.canBack ? T.text2 : T.text3.opacity(0.4)) {
                state.error = nil
                state.goBack()
            }
            IconHit(system: "chevron.right", label: L.t("前进", "Forward"), enabled: state.canForward, tint: state.canForward ? T.text2 : T.text3.opacity(0.4)) {
                state.error = nil
                state.goForward()
            }
            IconHit(system: "arrow.clockwise", label: L.t("刷新", "Reload"), enabled: !state.url.isEmpty, tint: T.text2) {
                state.reload()
            }
            HStack(spacing: 0) {
                TextField("", text: Binding(
                    get: { state.address },
                    set: { if $0.count <= maxBrowserURLLength { state.address = $0 } }
                ), prompt: Text(L.t("输入 HTTP(S) 地址", "Enter an HTTP(S) address")).foregroundColor(T.text3).font(.system(size: 12)))
                .font(.system(size: 12))
                .foregroundStyle(T.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($addressFocused)
                .submitLabel(.go)
                .onSubmit { go() }
                .accessibilityLabel(L.t("输入 HTTP(S) 地址", "Enter an HTTP(S) address"))
                Button(action: go) {
                    Image(systemName: "link").font(.system(size: 12)).foregroundStyle(T.text2).frame(width: 32, height: 32)
                }
                .accessibilityLabel(L.t("前往", "Go"))
            }
            .padding(.leading, 9)
            .frame(height: 32)
            .background(T.bg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.border, lineWidth: 0.5))
            IconHit(system: "arrow.up.right", label: L.t("在系统浏览器中打开", "Open in system browser"), enabled: !state.url.isEmpty, tint: T.text2) {
                external()
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 48)
    }

    private var idle: some View {
        VStack(spacing: 8) {
            Spacer()
            if state.url.isEmpty {
                Text(L.t("输入 HTTP(S) 地址开始浏览", "Enter an HTTP(S) address to start browsing"))
                    .font(.system(size: 13))
                    .foregroundStyle(T.text3)
            } else {
                Text(L.t("上次打开", "Previously opened")).font(.system(size: 12)).foregroundStyle(T.text3)
                Text(state.title).font(.system(size: 14)).foregroundStyle(T.ink).padding(.top, 8)
                Text(state.url).font(.system(size: 12)).foregroundStyle(T.text3).padding(.vertical, 8)
                Button {
                    state.navigate(state.url)
                } label: {
                    Text(L.t("恢复页面", "Restore page"))
                        .foregroundStyle(T.onPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(T.primaryButton, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func go() {
        addressFocused = false
        state.navigate(state.address)
    }

    private func external() {
        switch state.policy.parse(state.url, allowShorthand: false) {
        case .rejected(let reason):
            state.error = browserFailure(reason)
        case .target(let url, _):
            guard let parsed = URL(string: url) else {
                state.error = browserFailure(.invalid)
                return
            }
            UIApplication.shared.open(parsed, options: [:]) { ok in
                if !ok {
                    DispatchQueue.main.async {
                        state.error = L.t("未找到系统浏览器。", "No system browser is available.")
                    }
                }
            }
        }
    }

    private static func policy(for profiles: [Profile]) -> BrowserPolicy {
        BrowserPolicy(applicationOrigins: profiles.flatMap { profile in
            let host = profile.host.contains(":") && !profile.host.hasPrefix("[") ? "[\(profile.host)]" : profile.host
            return ["http://\(host):\(profile.port)", "https://\(host):\(profile.port)"]
        })
    }
}

private struct IconHit: View {
    let system: String
    let label: String
    let enabled: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: 14)).foregroundStyle(tint).frame(width: 32, height: 32)
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

func browserFailure(_ reason: BrowserAddressFailure) -> String {
    switch reason {
    case .empty: return L.t("请输入地址。", "Enter an address.")
    case .invalid: return L.t("这个地址无效或过长。", "That address is invalid or too long.")
    case .protocolKind: return L.t("只支持 HTTP 和 HTTPS 地址；本地文件请使用文档预览。", "Only HTTP and HTTPS addresses are supported; use Document Preview for local files.")
    case .credentials: return L.t("地址不能包含用户名或密码。", "Addresses cannot contain a username or password.")
    case .applicationOrigin: return L.t("不能在嵌入浏览器中打开 DSH 应用自身。", "The embedded browser cannot open the DSH application itself.")
    }
}

/// Only a checkpoint, never a saved WebView, cookie, bridge credential or automatic navigation.
private final class BrowserCheckpoint {
    private let defaults = UserDefaults.standard
    private let key: String

    init(sessionKey: String) {
        let digest = SHA256.hash(data: Data(sessionKey.utf8))
        key = digest.map { String(format: "%02x", $0) }.joined()
    }

    var url: String { defaults.string(forKey: "\(key).url") ?? "" }
    var title: String { defaults.string(forKey: "\(key).title") ?? "" }

    func save(url: String, title: String) {
        defaults.set(url, forKey: "\(key).url")
        defaults.set(String(title.prefix(512)), forKey: "\(key).title")
    }
}

@MainActor
final class BrowserPageState: ObservableObject {
    var policy: BrowserPolicy
    private let checkpoint: BrowserCheckpoint
    weak var webView: WKWebView?

    @Published var address: String
    @Published var url: String
    @Published var title: String
    @Published var started = false
    @Published var loading = false
    @Published var error: String?
    @Published var canBack = false
    @Published var canForward = false

    init(sessionKey: String, policy: BrowserPolicy) {
        self.policy = policy
        let checkpoint = BrowserCheckpoint(sessionKey: sessionKey)
        self.checkpoint = checkpoint
        self.address = checkpoint.url
        self.url = checkpoint.url
        self.title = checkpoint.title
    }

    func navigate(_ input: String) {
        switch policy.parse(input) {
        case .rejected(let reason):
            error = browserFailure(reason)
        case .target(let next, let nextTitle):
            url = next
            address = next
            title = nextTitle
            error = nil
            loading = true
            checkpoint.save(url: url, title: title)
            started = true
            if let parsed = URL(string: url) {
                webView?.load(URLRequest(url: parsed))
            }
        }
    }

    func observe(view: WKWebView, observedUrl: String?) {
        guard let observedUrl else { return }
        guard case .target(let next, _) = policy.parse(observedUrl, allowShorthand: false) else { return }
        url = next
        address = next
        canBack = view.canGoBack
        canForward = view.canGoForward
        checkpoint.save(url: url, title: title)
    }

    func observeTitle(view: WKWebView, observedTitle: String?) {
        if error != nil { return }
        guard case .target = policy.parse(view.url?.absoluteString ?? "", allowShorthand: false) else { return }
        title = String((observedTitle ?? "").prefix(512))
        checkpoint.save(url: url, title: title)
    }

    func reload() {
        if !started {
            navigate(url)
            return
        }
        switch policy.parse(url, allowShorthand: false) {
        case .rejected(let reason):
            error = browserFailure(reason)
        case .target:
            error = nil
            loading = true
            webView?.reload()
        }
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
}

private struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var state: BrowserPageState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.isOpaque = false
        view.backgroundColor = .clear
        state.webView = view
        switch state.policy.parse(state.url, allowShorthand: false) {
        case .target(let url, _):
            if let parsed = URL(string: url) { view.load(URLRequest(url: parsed)) }
        case .rejected(let reason):
            state.loading = false
            state.error = browserFailure(reason)
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.state = state
        state.webView = uiView
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.state.webView = nil
        uiView.stopLoading()
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var state: BrowserPageState
        init(state: BrowserPageState) { self.state = state }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            switch state.policy.parse(url.absoluteString, allowShorthand: false) {
            case .rejected(let reason):
                if navigationAction.targetFrame?.isMainFrame != false {
                    state.loading = false
                    state.error = browserFailure(reason)
                }
                decisionHandler(.cancel)
            case .target:
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if !navigationResponse.canShowMIMEType {
                state.loading = false
                state.error = L.t("不支持下载，请在系统浏览器中打开。", "Downloads are unavailable; open this page in the system browser.")
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            let raw = webView.url?.absoluteString ?? state.url
            switch state.policy.parse(raw, allowShorthand: false) {
            case .rejected(let reason):
                webView.stopLoading()
                state.loading = false
                state.error = browserFailure(reason)
            case .target(_, let title):
                state.loading = true
                state.error = nil
                state.title = title
                state.observe(view: webView, observedUrl: raw)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.loading = false
            state.observe(view: webView, observedUrl: webView.url?.absoluteString)
            state.observeTitle(view: webView, observedTitle: webView.title)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            state.loading = false
            state.error = L.t("网页加载失败：", "Page load failed: ") + error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            state.loading = false
            state.error = L.t("网页加载失败：", "Page load failed: ") + error.localizedDescription
        }

        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            state.error = L.t("已阻止新窗口，请在系统浏览器中打开。", "New windows are blocked; use the system browser.")
            return nil
        }
    }
}
