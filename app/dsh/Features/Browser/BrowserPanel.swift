import SwiftUI
import UIKit
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

    @StateObject private var tabs: BrowserTabsStore

    init(model: AppModel, sessionKey: String, onDismiss: @escaping () -> Void) {
        self.model = model
        self.sessionKey = sessionKey
        self.onDismiss = onDismiss
        _tabs = StateObject(wrappedValue: BrowserTabsStore(sessionKey: sessionKey, policy: BrowserPanelContent.policy(for: model.profiles)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabStrip
                BrowserSelectedPage(tabs: tabs, page: tabs.selected)
                    .id(tabs.selectedId)
            }
            .background(T.bg)
            .navigationTitle(tabs.selected.title.isEmpty ? L.t("浏览器", "Browser") : tabs.selected.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close(), action: onDismiss)
                }
            }
        }
        .onChange(of: model.profiles) { profiles in
            tabs.updatePolicy(Self.policy(for: profiles))
        }
        .onAppear { consumePendingURL() }
        .onChange(of: model.pendingBrowserURL) { _ in consumePendingURL() }
        .onDisappear { tabs.dispose() }
    }

    private func consumePendingURL() {
        guard let url = model.pendingBrowserURL else { return }
        model.pendingBrowserURL = nil
        tabs.open(url.absoluteString)
    }

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs.pages.map(\.id), id: \.self) { id in
                        if let page = tabs.pages.first(where: { $0.id == id }) {
                            BrowserTabChip(tabs: tabs, page: page)
                        }
                    }
                }
            }
            Button {
                tabs.add()
            } label: {
                Image(systemName: "plus").font(.system(size: 12)).foregroundStyle(T.text2).frame(width: 32, height: 32)
            }
            .accessibilityLabel(L.t("新标签页", "New tab"))
        }
        .padding(.horizontal, 6)
        .frame(height: 40)
    }

    private static func policy(for profiles: [Profile]) -> BrowserPolicy {
        BrowserPolicy(applicationOrigins: profiles.flatMap { profile in
            let host = profile.host.contains(":") && !profile.host.hasPrefix("[") ? "[\(profile.host)]" : profile.host
            return ["http://\(host):\(profile.port)", "https://\(host):\(profile.port)"]
        })
    }
}

private struct BrowserSelectedPage: View {
    @ObservedObject var tabs: BrowserTabsStore
    @ObservedObject var page: BrowserPageState
    @FocusState private var addressFocused: Bool

    private var state: BrowserPageState { page }

    var body: some View {
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
                BrowserViewport(tabs: tabs, page: page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
                        .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 8))
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
}

private struct BrowserTabChip: View {
    @ObservedObject var tabs: BrowserTabsStore
    @ObservedObject var page: BrowserPageState

    var body: some View {
        let selected = page.id == tabs.selectedId
        HStack(spacing: 0) {
            Button {
                tabs.select(page)
            } label: {
                Text(page.title.isEmpty ? L.t("浏览器", "Browser") : page.title)
                    .font(.system(size: 12))
                    .foregroundStyle(selected ? T.ink : T.text3)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button {
                tabs.close(page)
            } label: {
                Image(systemName: "xmark").font(.system(size: 9)).foregroundStyle(T.text3).frame(width: 32, height: 32)
            }
            .accessibilityLabel(L.t("关闭", "Close"))
        }
        .padding(.leading, 9)
        .frame(minWidth: 80, maxWidth: 180)
        .frame(height: 32)
        .background(selected ? T.bg : T.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? T.border : T.surface, lineWidth: 0.5))
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

@MainActor
private final class BrowserTabsStore: ObservableObject {
    @Published private(set) var pages: [BrowserPageState]
    @Published var selectedId: String
    var selected: BrowserPageState { pages.first { $0.id == selectedId } ?? pages[0] }

    private let defaults = UserDefaults.standard
    private let key: String
    private var policy: BrowserPolicy
    private var disposed = false

    init(sessionKey: String, policy: BrowserPolicy) {
        self.policy = policy
        let digest = SHA256.hash(data: Data(sessionKey.utf8))
        key = digest.map { String(format: "%02x", $0) }.joined()
        let stored = defaults.string(forKey: "\(key).tabs")
        let checkpoint = browserTabsCheckpoint(
            stored: stored,
            legacyURL: defaults.string(forKey: "\(key).url"),
            legacyTitle: defaults.string(forKey: "\(key).title")
        )
        var built: [BrowserPageState] = checkpoint.pages.map { page in
            BrowserPageState(id: page.id, url: page.url, title: page.title, policy: policy, onCheckpoint: {})
        }
        if built.isEmpty {
            built.append(BrowserPageState(id: UUID().uuidString, url: "", title: "", policy: policy, onCheckpoint: {}))
        }
        pages = built
        selectedId = built.first { $0.id == checkpoint.selected }?.id ?? built[0].id
        bindCheckpoints()
    }

    private func bindCheckpoints() {
        for page in pages {
            page.onCheckpoint = { [weak self] in self?.checkpoint() }
        }
    }

    func updatePolicy(_ value: BrowserPolicy) {
        policy = value
        pages.forEach { $0.policy = value }
    }

    func open(_ url: String) {
        if selected.url.isEmpty && !selected.started {
            selected.navigate(url)
        } else {
            let page = add()
            page.navigate(url)
        }
    }

    @discardableResult
    func add() -> BrowserPageState {
        let page = BrowserPageState(id: UUID().uuidString, url: "", title: "", policy: policy) { [weak self] in
            self?.checkpoint()
        }
        pages.append(page)
        select(page)
        return page
    }

    func select(_ page: BrowserPageState) {
        guard pages.contains(where: { $0.id == page.id }) else { return }
        selected.webView?.isHidden = true
        selectedId = page.id
        page.webView?.isHidden = false
        checkpoint()
        objectWillChange.send()
    }

    func close(_ page: BrowserPageState) {
        guard let index = pages.firstIndex(where: { $0.id == page.id }) else { return }
        pages.remove(at: index)
        page.release()
        if pages.isEmpty {
            pages.append(BrowserPageState(id: UUID().uuidString, url: "", title: "", policy: policy) { [weak self] in
                self?.checkpoint()
            })
        }
        if selectedId == page.id {
            selectedId = pages[min(index, pages.count - 1)].id
        }
        checkpoint()
        objectWillChange.send()
    }

    func viewFor(_ page: BrowserPageState) -> WKWebView {
        if let existing = page.webView { return existing }
        return page.createWebView(tabs: self)
    }

    func openWindow(from source: BrowserPageState) -> WKWebView? {
        guard pages.contains(where: { $0.id == source.id }) else { return nil }
        let page = add()
        page.started = true
        return viewFor(page)
    }

    func closeWindow(_ view: WKWebView) {
        pages.first { $0.webView === view }.map { close($0) }
    }

    func dispose() {
        if disposed { return }
        checkpoint()
        disposed = true
        pages.forEach { $0.release() }
    }

    private func checkpoint() {
        if disposed { return }
        let value = encodeBrowserTabsCheckpoint(BrowserTabsCheckpoint(
            selected: selectedId,
            pages: pages.map { BrowserTabCheckpoint(id: $0.id, url: $0.url, title: $0.title) }
        ))
        defaults.set(value, forKey: "\(key).tabs")
        defaults.removeObject(forKey: "\(key).url")
        defaults.removeObject(forKey: "\(key).title")
    }
}

@MainActor
private final class BrowserPageState: ObservableObject, Identifiable {
    let id: String
    var policy: BrowserPolicy
    fileprivate var onCheckpoint: () -> Void
    weak var webView: WKWebView?
    fileprivate var coordinator: BrowserWebCoordinator?

    @Published var address: String
    @Published var url: String
    @Published var title: String
    @Published var started = false
    @Published var loading = false
    @Published var error: String?
    @Published var canBack = false
    @Published var canForward = false

    init(id: String, url: String, title: String, policy: BrowserPolicy, onCheckpoint: @escaping () -> Void) {
        self.id = id
        self.policy = policy
        self.onCheckpoint = onCheckpoint
        self.address = url
        self.url = url
        self.title = title
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
            started = true
            onCheckpoint()
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
        onCheckpoint()
        objectWillChange.send()
    }

    func observeTitle(view: WKWebView, observedTitle: String?) {
        if error != nil { return }
        guard case .target = policy.parse(view.url?.absoluteString ?? "", allowShorthand: false) else { return }
        title = String((observedTitle ?? "").prefix(maxBrowserURLTitleLength))
        onCheckpoint()
        objectWillChange.send()
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

    fileprivate func createWebView(tabs: BrowserTabsStore) -> WKWebView {
        let coordinator = BrowserWebCoordinator(state: self, tabs: tabs)
        self.coordinator = coordinator
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = coordinator
        view.uiDelegate = coordinator
        view.allowsBackForwardNavigationGestures = true
        view.isOpaque = false
        view.backgroundColor = .clear
        webView = view
        if started && !url.isEmpty {
            switch policy.parse(url, allowShorthand: false) {
            case .target(let target, _):
                if let parsed = URL(string: target) { view.load(URLRequest(url: parsed)) }
            case .rejected(let reason):
                loading = false
                error = browserFailure(reason)
            }
        }
        return view
    }

    fileprivate func release() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView = nil
        coordinator = nil
    }
}

private struct BrowserViewport: UIViewRepresentable {
    @ObservedObject var tabs: BrowserTabsStore
    @ObservedObject var page: BrowserPageState

    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ container: UIView, context: Context) {
        let view = tabs.viewFor(page)
        if view.superview !== container {
            container.subviews.forEach { $0.removeFromSuperview() }
            view.frame = container.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(view)
        }
    }

    static func dismantleUIView(_ container: UIView, coordinator: ()) {
        container.subviews.forEach { $0.removeFromSuperview() }
    }
}

@MainActor
private final class BrowserWebCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var state: BrowserPageState
    weak var tabs: BrowserTabsStore?

    init(state: BrowserPageState, tabs: BrowserTabsStore) {
        self.state = state
        self.tabs = tabs
    }

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
        guard navigationAction.targetFrame == nil, let tabs else { return nil }
        return tabs.openWindow(from: state)
    }

    func webViewDidClose(_ webView: WKWebView) {
        tabs?.closeWindow(webView)
    }
}
