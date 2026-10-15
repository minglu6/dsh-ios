import Foundation

/// Origin of the Host HTTP listener. Userinfo is never allowed.
public struct HostUiOrigin: Equatable, Sendable {
    public var scheme: String
    public var host: String
    public var port: Int

    public init(scheme: String, host: String, port: Int) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    public init(url: URL) throws {
        guard let scheme = url.scheme, let host = url.host, host.isEmpty == false else {
            throw PocketError(code: "host-ui", message: "Invalid Host UI origin")
        }
        guard url.user == nil, url.password == nil else {
            throw PocketError(code: "host-ui", message: "Host UI origin must not include credentials")
        }
        let path = url.path.isEmpty ? "/" : url.path
        guard path == "/", url.query == nil, url.fragment == nil else {
            throw PocketError(code: "host-ui", message: "Host UI origin must be scheme://host:port/")
        }
        self.scheme = scheme
        self.host = host
        self.port = url.port ?? (scheme == "https" ? 443 : 80)
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        components.path = "/"
        return components.url!
    }
}

/// No phone bearer or Host process credential is ever handed to the WebView.
public struct HostUiSession: Equatable, Sendable {
    public var origin: HostUiOrigin
    public var startURL: URL
    public var cookie: HostUiCookie

    public var cookieHeader: String { cookie.header + "; SameSite=Strict" }
}

public struct HostUiCookie: Equatable, Sendable {
    public var name: String
    public var value: String
    public var path: String
    public var domain: String
    public var httpOnly: Bool
    public var secure: Bool
    public var hostOnly: Bool
    public var header: String
}

public struct HostUiHTTPResponse: Sendable {
    public var status: Int
    public var headers: [String: [String]]
    public var body: Data

    public init(status: Int, headers: [String: [String]], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public func header(_ name: String) -> String? {
        let key = name.lowercased()
        return headers.first { $0.key.lowercased() == key }?.value.first
    }

    public func headers(_ name: String) -> [String] {
        let key = name.lowercased()
        return headers.first { $0.key.lowercased() == key }?.value ?? []
    }
}

public protocol HostUiHTTPClient: Sendable {
    func post(url: URL, body: Data) throws -> HostUiHTTPResponse
}

public struct HostUiPolicy: Sendable {
    public let origin: HostUiOrigin

    public init(origin: HostUiOrigin) {
        self.origin = origin
    }

    public func allows(_ url: String) -> Bool {
        if url.contains("\\") { return false }
        if url.contains("\n") || url.contains("\r") || url.contains("\t") { return false }
        if url.unicodeScalars.contains(where: { $0.value <= 0x20 || $0.value == 0x7F }) { return false }
        guard let target = URL(string: url), let scheme = target.scheme, let host = target.host else { return false }
        if target.user != nil || target.password != nil { return false }
        let port = target.port ?? (scheme == "https" ? 443 : 80)
        return scheme == origin.scheme && host == origin.host && port == origin.port
    }
}

/// Exchanges one short-lived grant in native networking, without following a credential-bearing redirect.
public func exchangeHostUiTicket(
    http: HostUiHTTPClient,
    origin: HostUiOrigin,
    path: String,
    ticket: String
) throws -> HostUiSession {
    guard origin.scheme == "http" || origin.scheme == "https" else {
        throw PocketError(code: "host-ui", message: "Invalid Host UI origin")
    }
    guard path == "/pocket-ui/open", !ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw PocketError(code: "host-ui", message: "Invalid Host UI ticket")
    }
    var components = URLComponents()
    components.scheme = origin.scheme
    components.host = origin.host
    components.port = origin.port
    components.path = path
    guard let url = components.url else {
        throw PocketError(code: "host-ui", message: "Invalid Host UI origin")
    }
    let encoded = ticket.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
        .replacingOccurrences(of: "+", with: "%2B") ?? ticket
    let body = Data("ticket=\(encoded)".utf8)
    let response = try http.post(url: url, body: body)
    guard response.status == 303 else {
        throw PocketError(code: "host-ui", message: "Host UI authentication failed (\(response.status))")
    }
    guard let location = response.header("Location") else {
        throw PocketError(code: "host-ui", message: "Host UI redirect missing")
    }
    guard let target = URL(string: location, relativeTo: origin.url)?.absoluteURL else {
        throw PocketError(code: "host-ui", message: "Invalid Host UI redirect")
    }
    let policy = HostUiPolicy(origin: origin)
    let queryItems = URLComponents(url: target, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let pocketUi = queryItems.first { $0.name == "pocket-ui" }?.value
    let hasToken = queryItems.contains { $0.name == "token" }
    let hasTicket = queryItems.contains { $0.name == "ticket" }
    guard policy.allows(target.absoluteString),
          target.path == "/" || target.path.isEmpty,
          pocketUi == "1",
          !hasToken,
          !hasTicket,
          target.fragment == nil
    else {
        throw PocketError(code: "host-ui", message: "Unsafe Host UI redirect")
    }
    let cookies = response.headers("Set-Cookie").compactMap { parseHostUiCookie($0, origin: origin) }
    guard let cookie = cookies.first(where: { $0.name == "dsh-pocket-web" }), cookies.filter({ $0.name == "dsh-pocket-web" }).count == 1 else {
        throw PocketError(code: "host-ui", message: "Host UI session cookie missing")
    }
    guard cookie.httpOnly,
          cookie.hostOnly,
          cookie.domain == origin.host,
          cookie.path == "/",
          (origin.scheme != "https" || cookie.secure)
    else {
        throw PocketError(code: "host-ui", message: "Unsafe Host UI cookie")
    }
    return HostUiSession(origin: origin, startURL: target, cookie: cookie)
}

public func parseHostUiCookie(_ header: String, origin: HostUiOrigin) -> HostUiCookie? {
    let parts = header.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
    guard let first = parts.first, let eq = first.firstIndex(of: "=") else { return nil }
    let name = String(first[..<eq])
    let value = String(first[first.index(after: eq)...])
    guard !name.isEmpty else { return nil }
    var path = "/"
    var domain: String?
    var httpOnly = false
    var secure = false
    for attr in parts.dropFirst() {
        let lower = attr.lowercased()
        if lower == "httponly" { httpOnly = true; continue }
        if lower == "secure" { secure = true; continue }
        if lower.hasPrefix("path=") {
            path = String(attr.dropFirst(5))
            continue
        }
        if lower.hasPrefix("domain=") {
            domain = String(attr.dropFirst(7)).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
    }
    let hostOnly = domain == nil
    return HostUiCookie(
        name: name,
        value: value,
        path: path,
        domain: domain ?? origin.host,
        httpOnly: httpOnly,
        secure: secure,
        hostOnly: hostOnly,
        header: header
    )
}

public struct URLSessionHostUiHTTP: HostUiHTTPClient {
    public init() {}

    public func post(url: URL, body: Data) throws -> HostUiHTTPResponse {
        let semaphore = DispatchSemaphore(value: 0)
        var captured: Result<HostUiHTTPResponse, Error>?
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        // Do not follow the grant redirect; the ticket must stay off the WebView URL.
        let session = URLSession(configuration: config, delegate: HostUiRedirectDeny(), delegateQueue: nil)
        session.dataTask(with: request) { data, response, error in
            if let error {
                captured = .failure(error)
            } else if let http = response as? HTTPURLResponse {
                var headers: [String: [String]] = [:]
                for (key, value) in http.allHeaderFields {
                    guard let name = key as? String else { continue }
                    let text: String
                    if let string = value as? String {
                        text = string
                    } else {
                        text = String(describing: value)
                    }
                    headers[name, default: []].append(text)
                }
                if let cookies = http.value(forHTTPHeaderField: "Set-Cookie") {
                    headers["Set-Cookie"] = splitSetCookie(cookies)
                }
                captured = .success(HostUiHTTPResponse(status: http.statusCode, headers: headers, body: data ?? Data()))
            } else {
                captured = .failure(PocketError(code: "host-ui", message: "Host UI authentication failed"))
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        switch captured {
        case .success(let value): return value
        case .failure(let error): throw error
        case nil: throw PocketError(code: "host-ui", message: "Host UI authentication failed")
        }
    }
}

private final class HostUiRedirectDeny: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private func splitSetCookie(_ value: String) -> [String] {
    // URLSession may join multiple Set-Cookie headers with commas. Keep cookie-pairs intact.
    var out: [String] = []
    var current = ""
    var index = value.startIndex
    while index < value.endIndex {
        let ch = value[index]
        if ch == "," {
            let rest = value[value.index(after: index)...]
            let trimmed = rest.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("="), !trimmed.lowercased().hasPrefix("expires=") {
                out.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                index = value.index(after: index)
                continue
            }
        }
        current.append(ch)
        index = value.index(after: index)
    }
    let last = current.trimmingCharacters(in: .whitespaces)
    if !last.isEmpty { out.append(last) }
    return out
}
