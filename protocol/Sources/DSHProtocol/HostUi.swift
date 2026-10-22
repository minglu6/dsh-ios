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

    public static func fromWebSocket(_ url: URL) -> HostUiOrigin? {
        guard let scheme = url.scheme?.lowercased(), scheme == "ws" || scheme == "wss",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.fragment == nil, (1...65535).contains(url.port ?? 80) else { return nil }
        return HostUiOrigin(scheme: scheme == "wss" ? "https" : "http", host: host,
                            port: url.port ?? (scheme == "wss" ? 443 : 80))
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

    public var cookieHeader: String { cookie.header }
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
    public var expiresAt: Date
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
        return headers.filter { $0.key.lowercased() == key }.flatMap(\.value)
    }
}

public protocol HostUiHTTPClient: Sendable {
    func post(url: URL, body: Data) async throws -> HostUiHTTPResponse
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
) async throws -> HostUiSession {
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
    let encoded = ticket.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"))!
    let body = Data("ticket=\(encoded)".utf8)
    let response = try await http.post(url: url, body: body)
    guard response.status == 303 else {
        throw PocketError(code: "host-ui", message: "Host UI authentication failed (\(response.status))")
    }
    let locations = response.headers("Location")
    guard locations.count == 1, let location = locations.first,
          !location.contains("\\"), !location.unicodeScalars.contains(where: { $0.value <= 0x20 || $0.value == 0x7F }) else {
        throw PocketError(code: "host-ui", message: "Host UI redirect missing")
    }
    guard let target = URL(string: location, relativeTo: origin.url)?.absoluteURL else {
        throw PocketError(code: "host-ui", message: "Invalid Host UI redirect")
    }
    let policy = HostUiPolicy(origin: origin)
    let queryItems = URLComponents(url: target, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let names = queryItems.map { $0.name.lowercased() }
    guard policy.allows(target.absoluteString),
          target.path == "/" || target.path.isEmpty,
          queryItems.first(where: { $0.name == "pocket-ui" })?.value == "1",
          Set(names).count == names.count,
          names.allSatisfy({ $0 == "pocket-ui" || $0 == "section" }),
          target.fragment == nil
    else {
        throw PocketError(code: "host-ui", message: "Unsafe Host UI redirect")
    }
    let issuedCookies = response.headers("Set-Cookie")
    guard issuedCookies.count == 1,
          let cookie = parseHostUiCookie(issuedCookies[0], origin: origin),
          cookie.name == "dsh-pocket-web" else {
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

public func parseHostUiCookie(_ header: String, origin: HostUiOrigin, now: Date = Date()) -> HostUiCookie? {
    guard !header.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) else { return nil }
    let parts = header.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
    guard let first = parts.first, let eq = first.firstIndex(of: "=") else { return nil }
    let name = String(first[..<eq])
    let value = String(first[first.index(after: eq)...])
    let cookieCharacters = CharacterSet(charactersIn: "!#$%&'()*+-./:<=>?@[]^_`{|}~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    guard !name.isEmpty, !value.isEmpty, value.unicodeScalars.allSatisfy(cookieCharacters.contains) else { return nil }
    var attributes: [String: String] = [:]
    for attr in parts.dropFirst() {
        let pair = attr.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        let key = pair[0].lowercased()
        guard attributes[key] == nil else { return nil }
        attributes[key] = pair.count == 2 ? String(pair[1]) : ""
    }
    guard attributes["domain"] == nil, attributes["path"] == "/",
          attributes["httponly"] == "", attributes["samesite"]?.lowercased() == "strict",
          (attributes["secure"] == nil || attributes["secure"] == ""),
          (origin.scheme != "https" || attributes["secure"] == "") else { return nil }
    let expiresAt: Date
    if let maxAge = attributes["max-age"] {
        guard !maxAge.isEmpty, maxAge.utf8.allSatisfy({ (48...57).contains($0) }),
              let seconds = Int64(maxAge), seconds > 0 else { return nil }
        expiresAt = now.addingTimeInterval(TimeInterval(seconds))
    } else if let expires = attributes["expires"] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.isLenient = false
        guard let date = formatter.date(from: expires) else { return nil }
        expiresAt = date
    } else {
        return nil
    }
    guard expiresAt > now else { return nil }
    return HostUiCookie(name: name, value: value, path: "/", domain: origin.host,
                        httpOnly: true, secure: attributes["secure"] != nil, hostOnly: true,
                        header: header, expiresAt: expiresAt)
}

public struct URLSessionHostUiHTTP: HostUiHTTPClient {
    public init() {}

    public func post(url: URL, body: Data) async throws -> HostUiHTTPResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        let session = URLSession(configuration: config, delegate: HostUiRedirectDeny(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw PocketError(code: "host-ui", message: "Host UI authentication failed")
            }
            var headers: [String: [String]] = [:]
            for (key, value) in http.allHeaderFields {
                guard let name = key as? String else { continue }
                headers[name] = name.lowercased() == "set-cookie"
                    ? splitSetCookie(String(describing: value)) : [String(describing: value)]
            }
            return HostUiHTTPResponse(status: http.statusCode, headers: headers, body: data)
        } onCancel: {
            session.invalidateAndCancel()
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
            let candidate = rest.prefix { $0 != ";" && $0 != "," }
            if let equals = candidate.firstIndex(of: "="),
               !candidate[..<equals].trimmingCharacters(in: .whitespaces).contains(" ") {
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
