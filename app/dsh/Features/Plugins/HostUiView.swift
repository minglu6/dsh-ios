import SwiftUI
import WebKit
import DSHProtocol

struct HostUiView: View {
    @ObservedObject var model: AppModel
    let title: String
    var section: String? = nil
    var onBack: () -> Void

    @State private var session: HostUiSession?
    @State private var error: String?
    @State private var loading = true
    @State private var attempt = 0

    var body: some View {
        VStack(spacing: 0) {
            header(title, back: onBack)
            if let error {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(T.err).padding()
                    Button(L.retry()) { attempt += 1 }
                }
                Spacer()
            } else if let session {
                HostUiWebView(session: session, loading: $loading)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .task(id: "\(model.activeId ?? "")-\(attempt)-\(section ?? "")") {
            await open()
        }
    }

    private func open() async {
        session = nil
        error = nil
        loading = true
        guard model.isOnline, let profile = model.activeProfile, let client = model.clientOrNull() else {
            error = L.t("远程主机未连接，请连接后重试。", "Remote host disconnected; reconnect and retry.")
            loading = false
            return
        }
        guard model.ops.contains("ui.open") else {
            error = L.t("当前远程主机未提供插件 Web 界面，请更新并重新加载桌面端手机连接插件。", "This remote host does not expose plugin Web interfaces. Update and reload its phone-connection plugin.")
            loading = false
            return
        }
        do {
            let grant = try await client.uiOpen(section: section)
            let ticket = try grant["ticket"].requiredString("ticket")
            let origin = HostUiOrigin(scheme: "http", host: profile.host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")), port: profile.port)
            let path = grant["path"].str().flatMap { $0.isEmpty ? nil : $0 } ?? "/pocket-ui/open"
            let exchanged = try await Task.detached {
                try exchangeHostUiTicket(
                    http: URLSessionHostUiHTTP(),
                    origin: origin,
                    path: path,
                    ticket: ticket
                )
            }.value
            session = exchanged
        } catch {
            self.error = error.localizedDescription
            loading = false
        }
    }
}

private struct HostUiWebView: UIViewRepresentable {
    let session: HostUiSession
    @Binding var loading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(session: session, loading: $loading) }

    func makeUIView(context: Context) -> WKWebView {
        let store = WKWebsiteDataStore.nonPersistent()
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: session.cookie.name,
            .value: session.cookie.value,
            .path: session.cookie.path,
            .originURL: session.origin.url,
            .expires: Date().addingTimeInterval(900),
        ]
        if session.cookie.secure { properties[.secure] = true }
        if let cookie = HTTPCookie(properties: properties) {
            store.httpCookieStore.setCookie(cookie)
        }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = store
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: session.startURL))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let session: HostUiSession
        var loading: Binding<Bool>
        let policy: HostUiPolicy

        init(session: HostUiSession, loading: Binding<Bool>) {
            self.session = session
            self.loading = loading
            self.policy = HostUiPolicy(origin: session.origin)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(policy.allows(url.absoluteString) ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loading.wrappedValue = false
        }
    }
}
