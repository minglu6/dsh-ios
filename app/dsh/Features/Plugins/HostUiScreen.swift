import SwiftUI
import WebKit
import DSHProtocol

struct HostUiRequest: Identifiable {
    let id = UUID()
    let hostId: String
    let connection: PocketClient.HostUiConnection
    var section: String? = nil
}

private func hostUiText(_ zh: String, _ en: String) -> String { L.en ? en : zh }

struct HostUiScreen: View {
    let request: HostUiRequest
    let onBack: () -> Void

    var body: some View {
        if #available(iOS 18.4, *) {
            HostUiAvailableScreen(request: request, onBack: onBack)
        } else {
            VStack(spacing: 20) {
                Text(hostUiText("主机插件界面需要 iOS 18.4 或更新版本，请使用原生插件管理。", "Host plugin interfaces require iOS 18.4 or later. Use native plugin management instead."))
                Button(hostUiText("返回", "Back"), action: onBack)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(T.bg.ignoresSafeArea())
        }
    }
}

@available(iOS 18.4, *)
private struct HostUiAvailableScreen: View {
    @StateObject private var controller: HostUiPageController
    let onBack: () -> Void
    @State private var prompt = ""

    init(request: HostUiRequest, onBack: @escaping () -> Void) {
        _controller = StateObject(wrappedValue: HostUiPageController(request: request))
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    controller.close()
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        OfficialGlyph(kind: .chevronLeft, size: 16)
                        Text(hostUiText("返回", "Back"))
                    }
                }
                Spacer(minLength: 0)
                Text(hostUiText("主机插件界面", "Host plugin interfaces"))
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button { controller.reconnect() } label: {
                    OfficialGlyph(kind: .refreshOutline, size: 18)
                        .frame(width: 32, height: 32)
                }
                .disabled(!controller.canReconnect)
                .accessibilityLabel(hostUiText("重新连接界面", "Reconnect interface"))
            }
            .font(.system(size: 13))
            .buttonStyle(.plain)
            .foregroundStyle(T.text2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Rectangle().fill(T.border).frame(height: 1)
            if let notice = controller.notice {
                Text(notice).font(.system(size: 12)).foregroundStyle(T.text2)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            }
            ZStack {
                if let webView = controller.webView {
                    HostUiWebView(webView: webView)
                }
                switch controller.state {
                case .idle, .loading:
                    ProgressView().padding(20).background(T.bg.opacity(0.95)).cornerRadius(8)
                case .ready:
                    EmptyView()
                case .failed(let message):
                    VStack(spacing: 16) {
                        Text(message).font(.system(size: 13)).foregroundStyle(T.err)
                            .multilineTextAlignment(.center)
                        Button(hostUiText("重试", "Retry")) { controller.reconnect() }
                            .disabled(!controller.canReconnect)
                    }.padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(controller.dialog != nil)
        }
        .background(T.bg.ignoresSafeArea())
        .overlay {
            if let dialog = controller.dialog {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(alignment: .leading, spacing: 16) {
                        Text(hostUiText("主机插件界面", "Host plugin interfaces"))
                            .font(.system(size: 14, weight: .semibold))
                        ScrollView { Text(dialog.message).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading) }
                            .frame(maxHeight: 240)
                        if dialog.kind == .prompt {
                            TextField("", text: $prompt).textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Spacer()
                            if dialog.kind != .alert {
                                Button(hostUiText("取消", "Cancel")) { controller.resolveDialog(accepted: false, text: nil) }
                            }
                            Button(hostUiText("确定", "OK")) { controller.resolveDialog(accepted: true, text: prompt) }
                        }.font(.system(size: 13))
                    }
                    .padding(20)
                    .foregroundStyle(T.text2)
                    .background(T.bg)
                    .cornerRadius(8)
                    .frame(maxWidth: 420)
                    .padding(24)
                    .onAppear { prompt = dialog.defaultText ?? "" }
                    .id(dialog.id)
                    .accessibilityAddTraits(.isModal)
                }
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.close() }
        .onChange(of: controller.connectionInvalidated) { invalidated in
            if invalidated { onBack() }
        }
    }
}

@available(iOS 18.4, *)
private struct HostUiWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) { uiView.stopLoading() }
}

/// Each attempt owns its cookie store and ticket. The serial operation chain is never
/// cancelled: even a late ui.open receipt must be revoked before another open starts.
@available(iOS 18.4, *)
@MainActor
final class HostUiPageController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    enum State: Equatable {
        case idle, loading, ready
        case failed(String)
    }

    struct Dialog: Identifiable {
        enum Kind { case alert, confirm, prompt }
        let id = UUID()
        let kind: Kind
        let message: String
        let defaultText: String?
        let completion: (Bool, String?) -> Void
    }

    @MainActor
    private final class Attempt {
        let revision: Int
        let store = WKWebsiteDataStore.nonPersistent()
        let ruleIdentifier = "dsh-host-ui-" + UUID().uuidString
        var ticket: String?
        var view: WKWebView?
        var expiry: Task<Void, Never>?
        var timeout: Task<Void, Never>?
        init(revision: Int) { self.revision = revision }
    }

    let request: HostUiRequest
    @Published private(set) var state: State = .idle
    @Published private(set) var webView: WKWebView?
    @Published private(set) var notice: String?
    @Published private(set) var dialog: Dialog?
    @Published private(set) var connectionInvalidated = false
    private var attempt: Attempt?
    private var revision = 0
    private var closed = false
    private var started = false
    private var operation: Task<Void, Never>?
    private var invalidation: Task<Void, Never>?

    var canReconnect: Bool { !closed && request.connection.isCurrent }

    init(request: HostUiRequest) {
        self.request = request
        super.init()
    }

    func start() {
        guard !started, !closed else { return }
        started = true
        let stream = request.connection.invalidations()
        invalidation = Task { [weak self] in
            for await _ in stream {
                guard !Task.isCancelled, let self else { return }
                self.close()
                self.connectionInvalidated = true
                return
            }
        }
        reconnect()
    }

    func reconnect() {
        guard canReconnect else {
            if !request.connection.isCurrent {
                close()
                connectionInvalidated = true
            }
            return
        }
        revision += 1
        let expected = revision
        detachView()
        state = .loading
        notice = nil
        let previous = operation
        operation = Task {
            await previous?.value
            await releaseAttempt()
            guard isCurrent(expected) else { return }
            await open(expected)
        }
    }

    func close() {
        guard !closed else { return }
        closed = true
        revision += 1
        invalidation?.cancel()
        invalidation = nil
        detachView()
        enqueueRelease()
    }

    private func isCurrent(_ expected: Int) -> Bool {
        !closed && revision == expected && request.connection.isCurrent
    }

    private func open(_ expected: Int) async {
        let next = Attempt(revision: expected)
        attempt = next
        do {
            let grant = try await request.connection.open(section: request.section)
            guard let ticket = grant["ticket"].str(), !ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw pageError(hostUiText("主机未返回界面票据。", "The Host returned no UI ticket."))
            }
            next.ticket = ticket
            guard isCurrent(expected) else { return }
            guard grant["path"].str() == "/pocket-ui/open" else {
                throw pageError(hostUiText("主机返回了不安全的认证路径。", "The Host returned an unsafe authentication path."))
            }
            let session = try await exchangeHostUiTicket(http: URLSessionHostUiHTTP(), origin: request.connection.origin, path: "/pocket-ui/open", ticket: ticket)
            guard isCurrent(expected) else { return }
            guard session.cookie.expiresAt > Date() else {
                throw pageError(expiredMessage)
            }
            next.expiry = timer(after: session.cookie.expiresAt.timeIntervalSinceNow, revision: expected, message: expiredMessage)
            let rules = try await contentRules(origin: session.origin, identifier: next.ruleIdentifier)
            guard isCurrent(expected) else { return }
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": session.cookie.header], for: session.origin.url)
            guard let parsed = cookies.first(where: { $0.name == session.cookie.name && $0.value == session.cookie.value }),
                  var properties = parsed.properties else {
                throw pageError(hostUiText("无法解析界面认证 Cookie。", "The UI authentication cookie could not be parsed."))
            }
            properties[.maximumAge] = nil
            properties[.expires] = session.cookie.expiresAt
            properties[.sameSitePolicy] = "strict"
            guard let cookie = HTTPCookie(properties: properties),
                  cookie.isHTTPOnly, cookie.path == "/", cookie.isSecure == session.cookie.secure,
                  cookie.domain == session.cookie.domain else {
                throw pageError(hostUiText("无法安全安装界面认证 Cookie。", "The UI authentication cookie could not be installed safely."))
            }
            next.timeout = timer(after: 5, revision: expected, message: hostUiText("界面认证 Cookie 安装超时，请重试。", "UI authentication cookie installation timed out. Retry to reconnect."))
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                next.store.httpCookieStore.setCookie(cookie) { continuation.resume() }
            }
            next.timeout?.cancel()
            next.timeout = nil
            guard isCurrent(expected) else { return }
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = next.store
            configuration.userContentController.add(rules)
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
            configuration.mediaTypesRequiringUserActionForPlayback = .all
            configuration.allowsInlineMediaPlayback = false
            let view = WKWebView(frame: .zero, configuration: configuration)
            view.navigationDelegate = self
            view.uiDelegate = self
            view.allowsLinkPreview = false
            view.allowsBackForwardNavigationGestures = false
            view.isOpaque = false
            view.backgroundColor = .clear
            next.view = view
            webView = view
            armLoadTimeout(next)
            view.load(URLRequest(url: session.startURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        } catch {
            guard isCurrent(expected) else { return }
            state = .failed(error.localizedDescription)
            detachView()
            await releaseAttempt()
        }
    }

    private var expiredMessage: String {
        hostUiText("插件界面会话已过期，请重新连接。", "The plugin UI session expired. Reconnect to continue.")
    }

    private func pageError(_ message: String) -> PocketError { PocketError(code: "host-ui", message: message) }

    private func timer(after seconds: TimeInterval, revision: Int, message: String) -> Task<Void, Never> {
        Task { [weak self] in
            do { try await Task.sleep(for: .seconds(max(0, seconds))) } catch { return }
            self?.fail(message, expected: revision)
        }
    }

    private func armLoadTimeout(_ attempt: Attempt) {
        attempt.timeout?.cancel()
        attempt.timeout = timer(after: 30, revision: attempt.revision, message: hostUiText("主机页面加载超时，请重新连接。", "The Host page timed out. Reconnect to retry."))
    }

    private func fail(_ message: String, expected: Int) {
        guard isCurrent(expected) else { return }
        revision += 1
        state = .failed(message)
        detachView()
        enqueueRelease()
    }

    private func enqueueRelease() {
        let previous = operation
        operation = Task {
            await previous?.value
            await releaseAttempt()
        }
    }

    private func detachView() {
        resolveDialog(accepted: false, text: nil)
        attempt?.expiry?.cancel()
        attempt?.timeout?.cancel()
        if let view = attempt?.view {
            view.stopLoading()
            view.navigationDelegate = nil
            view.uiDelegate = nil
            view.removeFromSuperview()
        }
        attempt?.view = nil
        webView = nil
    }

    private func releaseAttempt() async {
        guard let old = attempt else { return }
        attempt = nil
        old.expiry?.cancel()
        old.timeout?.cancel()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            old.store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { continuation.resume() }
        }
        WKContentRuleListStore.default().removeContentRuleList(forIdentifier: old.ruleIdentifier) { _ in }
        if let ticket = old.ticket {
            do { try await request.connection.close(ticket: ticket) }
            catch {
                if !closed {
                    notice = hostUiText("主机未确认旧界面会话已撤销；本机界面及数据已清除。", "The Host did not confirm revocation of the previous UI session; its local view and data were cleared.")
                }
            }
        }
    }

    private func contentRules(origin: HostUiOrigin, identifier: String) async throws -> WKContentRuleList {
        var components = URLComponents(url: origin.url, resolvingAgainstBaseURL: false)!
        components.port = nil
        let base = components.url!.absoluteString.dropLast()
        let defaultPort = (origin.scheme == "https" && origin.port == 443) || (origin.scheme == "http" && origin.port == 80)
        let port = defaultPort ? "(:\(origin.port))?" : ":\(origin.port)"
        let allowed = "^" + NSRegularExpression.escapedPattern(for: String(base)) + port + "/"
        let socketBase = (origin.scheme == "https" ? "wss" : "ws") + String(base.dropFirst(origin.scheme.count))
        let allowedSocket = "^" + NSRegularExpression.escapedPattern(for: socketBase) + port + "/"
        let rules: [[String: Any]] = [
            ["trigger": ["url-filter": ".*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": allowed], "action": ["type": "ignore-previous-rules"]],
            ["trigger": ["url-filter": allowedSocket], "action": ["type": "ignore-previous-rules"]],
            // Local image/font resources remain usable; navigation still rejects these schemes.
            ["trigger": ["url-filter": "^data:", "resource-type": ["image", "font", "media"]], "action": ["type": "ignore-previous-rules"]],
            ["trigger": ["url-filter": "^blob:", "resource-type": ["image", "font", "media"]], "action": ["type": "ignore-previous-rules"]]
        ]
        let encoded = String(decoding: try JSONSerialization.data(withJSONObject: rules), as: UTF8.self)
        return try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: encoded) { list, error in
                if let error { continuation.resume(throwing: error) }
                else if let list { continuation.resume(returning: list) }
                else { continuation.resume(throwing: PocketError(code: "host-ui", message: "Host UI resource policy unavailable")) }
            }
        }
    }

    private func active(_ view: WKWebView) -> Attempt? {
        guard let attempt, attempt.view === view, isCurrent(attempt.revision) else { return nil }
        return attempt
    }

    private func allows(_ url: URL?) -> Bool {
        guard let url else { return false }
        return HostUiPolicy(origin: request.connection.origin).allows(url.absoluteString)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard active(webView) != nil else { decisionHandler(.cancel); return }
        guard navigationAction.targetFrame != nil, !navigationAction.shouldPerformDownload, allows(navigationAction.request.url) else {
            notice = hostUiText("已阻止外部导航、新窗口或文件下载。", "External navigation, new windows, or downloads were blocked.")
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let current = active(webView) else { decisionHandler(.cancel); return }
        let response = navigationResponse.response as? HTTPURLResponse
        if navigationResponse.isForMainFrame, let status = response?.statusCode, status >= 400 {
            decisionHandler(.cancel)
            let message = status == 401 ? hostUiText("主机界面认证已失效，请重新连接。", "Host UI authentication expired. Reconnect to continue.") : hostUiText("主机页面请求失败：HTTP ", "Host page request failed: HTTP ") + String(status)
            fail(message, expected: current.revision)
            return
        }
        guard allows(navigationResponse.response.url), navigationResponse.canShowMIMEType,
              !(response?.value(forHTTPHeaderField: "Content-Disposition")?.lowercased().hasPrefix("attachment") ?? false) else {
            decisionHandler(.cancel)
            if navigationResponse.isForMainFrame {
                fail(hostUiText("主机返回了不允许显示的页面或下载。", "The Host returned a disallowed page or download."), expected: current.revision)
            }
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard let current = active(webView) else { return }
        state = .loading
        armLoadTimeout(current)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let current = active(webView) else { return }
        guard allows(webView.url) else {
            fail(hostUiText("页面已离开授权的主机会话。", "The page left its authorized Host session."), expected: current.revision)
            return
        }
        current.timeout?.cancel()
        current.timeout = nil
        state = .ready
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { navigationFailed(webView, error: error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { navigationFailed(webView, error: error) }

    private func navigationFailed(_ view: WKWebView, error: Error) {
        guard let current = active(view) else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        fail(hostUiText("主机页面加载失败：", "Host page failed to load: ") + error.localizedDescription, expected: current.revision)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let current = active(webView) else { return }
        fail(hostUiText("主机界面进程已终止，请重新连接。", "The Host UI process terminated. Reconnect to continue."), expected: current.revision)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(active(webView) != nil && challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust ? .performDefaultHandling : .cancelAuthenticationChallenge, nil)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        notice = hostUiText("插件界面不允许打开新窗口。", "New windows are disabled in plugin interfaces.")
        return nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        notice = hostUiText("插件界面不允许访问手机文件。", "Plugin interfaces cannot access phone files.")
        completionHandler(nil)
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.deny) }

    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.deny) }

    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) { completionHandler(nil) }

    private func presentDialog(_ view: WKWebView, frame: WKFrameInfo, kind: Dialog.Kind, message: String, defaultText: String? = nil, completion: @escaping (Bool, String?) -> Void) {
        guard active(view) != nil, allows(frame.request.url), dialog == nil else { completion(false, nil); return }
        dialog = Dialog(kind: kind, message: message, defaultText: defaultText, completion: completion)
    }

    func resolveDialog(accepted: Bool, text: String?) {
        let pending = dialog
        dialog = nil
        pending?.completion(accepted, text)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        presentDialog(webView, frame: frame, kind: .alert, message: message) { _, _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        presentDialog(webView, frame: frame, kind: .confirm, message: message) { accepted, _ in completionHandler(accepted) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        presentDialog(webView, frame: frame, kind: .prompt, message: prompt, defaultText: defaultText) { accepted, text in completionHandler(accepted ? text ?? "" : nil) }
    }
}
