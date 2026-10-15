import Foundation

public let maxBrowserURLLength = 16 * 1024

public enum BrowserAddressFailure: String, Sendable, Equatable {
    case empty, invalid, protocolKind, credentials, applicationOrigin
}

public enum BrowserAddressResult: Sendable, Equatable {
    case target(url: String, title: String)
    case rejected(BrowserAddressFailure)
}

/// HTTP(S) origin matching is deliberately not a DNS / private-network firewall.
public struct BrowserOrigin: Hashable, Sendable {
    public var scheme: String
    public var host: String
    public var port: Int

    public init(scheme: String, host: String, port: Int) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }
}

public struct BrowserPolicy: Sendable {
    private let blockedOrigins: Set<BrowserOrigin>

    public init(applicationOrigins: [String] = []) {
        blockedOrigins = Set(applicationOrigins.compactMap(Self.origin(from:)))
    }

    public func parse(_ input: String, allowShorthand: Bool = true) -> BrowserAddressResult {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .rejected(.empty) }
        if text.count > maxBrowserURLLength || text.contains(where: { $0 <= " " || $0 == "\\" || $0 == "\u{007f}" }) {
            return .rejected(.invalid)
        }
        let prefix = String(text.prefix(while: { $0 != ":" })).lowercased()
        let hostPort = hostPortPattern(text) && !Self.reservedSchemes.contains(prefix)
        let explicitScheme = schemePattern(text) && !hostPort
        if !explicitScheme && !allowShorthand { return .rejected(.protocolKind) }
        if explicitScheme && prefix != "http" && prefix != "https" { return .rejected(.protocolKind) }
        let candidate = explicitScheme ? text : "https://\(text)"
        guard let parsed = HTTPURLParts.parse(candidate) else { return .rejected(.invalid) }
        let scheme = parsed.scheme.lowercased()
        if scheme != "http" && scheme != "https" { return .rejected(.protocolKind) }
        if parsed.hasUserInfo { return .rejected(.credentials) }
        if parsed.rawAuthority.contains("%") || parsed.rawAuthority.hasSuffix(":") { return .rejected(.invalid) }
        guard let host = Self.canonicalHost(parsed) else { return .rejected(.invalid) }
        if let port = parsed.port, !(1...65535).contains(port) { return .rejected(.invalid) }
        let canonicalAuthority = host + (parsed.port.map { ":\($0)" } ?? "")
        let path = parsed.path.isEmpty ? "/" : parsed.path
        guard let encodedPath = asciiPath(path) else { return .rejected(.invalid) }
        var url = "\(scheme)://\(canonicalAuthority)\(encodedPath)"
        if let query = parsed.query {
            guard let encoded = asciiQueryOrFragment(query, delimiter: "?") else { return .rejected(.invalid) }
            url += encoded
        }
        if let fragment = parsed.fragment {
            guard let encoded = asciiQueryOrFragment(fragment, delimiter: "#") else { return .rejected(.invalid) }
            url += encoded
        }
        let originPort = parsed.port ?? Self.defaultPort(scheme)
        if blockedOrigins.contains(BrowserOrigin(scheme: scheme, host: host, port: originPort)) {
            return .rejected(.applicationOrigin)
        }
        let title = host.hasPrefix("[") && host.hasSuffix("]")
            ? String(host.dropFirst().dropLast())
            : host
        return .target(url: url, title: title)
    }

    private static let reservedSchemes: Set<String> = [
        "http", "https", "file", "content", "data", "javascript", "blob", "about", "intent",
        "chrome", "ftp", "ws", "wss", "mailto", "tel",
    ]

    private static func defaultPort(_ scheme: String) -> Int { scheme == "https" ? 443 : 80 }

    private static func canonicalHost(_ uri: HTTPURLParts) -> String? {
        let raw = uri.host
        if raw.isEmpty { return nil }
        if raw.hasPrefix("[") {
            guard raw.hasSuffix("]"), raw.count > 2 else { return nil }
            return raw.lowercased()
        }
        if raw.contains("%") { return nil }
        guard let ascii = idnaASCII(raw) else { return nil }
        var trimmed = ascii.lowercased()
        while trimmed.hasSuffix(".") { trimmed.removeLast() }
        if trimmed.isEmpty { return nil }
        let labels = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        if labels.contains(where: { $0.isEmpty }) { return nil }
        return trimmed
    }

    private static func origin(from value: String) -> BrowserOrigin? {
        guard let uri = HTTPURLParts.parse(value) else { return nil }
        let scheme = uri.scheme.lowercased()
        guard scheme == "http" || scheme == "https" else { return nil }
        guard let host = canonicalHost(uri) else { return nil }
        return BrowserOrigin(scheme: scheme, host: host, port: uri.port ?? defaultPort(scheme))
    }
}

private struct HTTPURLParts {
    var scheme: String
    var rawAuthority: String
    var host: String
    var port: Int?
    var path: String
    var query: String?
    var fragment: String?
    var hasUserInfo: Bool

    static func parse(_ candidate: String) -> HTTPURLParts? {
        guard let schemeEnd = candidate.range(of: "://") else { return nil }
        let scheme = String(candidate[..<schemeEnd.lowerBound])
        guard !scheme.isEmpty else { return nil }
        let rest = candidate[schemeEnd.upperBound...]
        let authorityEnd = rest.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? rest.endIndex
        let rawAuthority = String(rest[..<authorityEnd])
        if rawAuthority.isEmpty { return nil }
        var remainder = rest[authorityEnd...]
        var path = ""
        var query: String?
        var fragment: String?
        if remainder.first == "/" {
            let pathEnd = remainder.firstIndex(where: { $0 == "?" || $0 == "#" }) ?? remainder.endIndex
            path = String(remainder[..<pathEnd])
            remainder = remainder[pathEnd...]
        }
        if remainder.first == "?" {
            remainder = remainder.dropFirst()
            let queryEnd = remainder.firstIndex(of: "#") ?? remainder.endIndex
            query = String(remainder[..<queryEnd])
            remainder = remainder[queryEnd...]
        }
        if remainder.first == "#" {
            fragment = String(remainder.dropFirst())
        } else if !remainder.isEmpty {
            return nil
        }
        if rawAuthority.contains("@") {
            return HTTPURLParts(
                scheme: scheme, rawAuthority: rawAuthority, host: "", port: nil,
                path: path, query: query, fragment: fragment, hasUserInfo: true
            )
        }
        let host: String
        let port: Int?
        if rawAuthority.hasPrefix("[") {
            guard let close = rawAuthority.firstIndex(of: "]") else { return nil }
            host = String(rawAuthority[...close])
            let after = rawAuthority[rawAuthority.index(after: close)...]
            if after.isEmpty {
                port = nil
            } else if after.first == ":" {
                let portText = String(after.dropFirst())
                if portText.isEmpty { return nil }
                guard let parsed = Int(portText), String(parsed) == portText else { return nil }
                port = parsed
            } else {
                return nil
            }
        } else if let colon = rawAuthority.lastIndex(of: ":") {
            let portText = String(rawAuthority[rawAuthority.index(after: colon)...])
            host = String(rawAuthority[..<colon])
            if portText.isEmpty { return nil }
            guard let parsed = Int(portText), String(parsed) == portText else { return nil }
            port = parsed
        } else {
            host = rawAuthority
            port = nil
        }
        if host.isEmpty { return nil }
        return HTTPURLParts(
            scheme: scheme, rawAuthority: rawAuthority, host: host, port: port,
            path: path, query: query, fragment: fragment, hasUserInfo: false
        )
    }
}

private func schemePattern(_ text: String) -> Bool {
    guard let colon = text.firstIndex(of: ":") else { return false }
    let prefix = text[..<colon]
    guard let first = prefix.first, first.isLetter else { return false }
    return prefix.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "." || $0 == "-" }
}

private func hostPortPattern(_ text: String) -> Bool {
    guard let colon = text.firstIndex(of: ":") else { return false }
    let host = text[..<colon]
    guard !host.isEmpty, host.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }) else { return false }
    let rest = text[text.index(after: colon)...]
    var digits = 0
    for ch in rest {
        if ch.isNumber { digits += 1; continue }
        return digits > 0 && (ch == "/" || ch == "?" || ch == "#")
    }
    return digits > 0
}

private func asciiPath(_ path: String) -> String? {
    percentEncode(path, extraUnreserved: "/:@-._~!$&'()*+,;=")
}

private func asciiQueryOrFragment(_ value: String, delimiter: String) -> String? {
    guard let encoded = percentEncode(value, extraUnreserved: "/?:@-._~!$&'()*+,;=") else { return nil }
    return delimiter + encoded
}

private func percentEncode(_ value: String, extraUnreserved: String) -> String? {
    var out = ""
    var index = value.startIndex
    while index < value.endIndex {
        let ch = value[index]
        if ch == "%" {
            // offset 3 from "%" lands after the two hex digits (`%20b` → index of `b`).
            guard let hexEnd = value.index(index, offsetBy: 3, limitedBy: value.endIndex) else { return nil }
            let hex = value[value.index(after: index)..<hexEnd]
            guard hex.count == 2, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
            out += "%" + hex.uppercased()
            index = hexEnd
            continue
        }
        if ch.asciiValue != nil, extraUnreserved.contains(ch) || ch.isLetter || ch.isNumber {
            out.append(ch)
            index = value.index(after: index)
            continue
        }
        let utf8 = String(ch).utf8
        for byte in utf8 {
            out += String(format: "%%%02X", byte)
        }
        index = value.index(after: index)
    }
    return out
}

private func idnaASCII(_ host: String) -> String? {
    if host.allSatisfy({ $0.isASCII && $0 != " " }) {
        if host.hasPrefix("-") { return nil }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        var last = labels.count
        while last > 0 && labels[last - 1].isEmpty { last -= 1 }
        if last == 0 { return nil }
        for i in 0..<last {
            let label = labels[i]
            if label.isEmpty { return nil }
            if label.hasPrefix("-") || label.hasSuffix("-") { return nil }
            if !label.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) { return nil }
        }
        return host
    }
    var components = URLComponents()
    components.scheme = "https"
    components.host = host
    if let encoded = components.percentEncodedHost, !encoded.isEmpty, !encoded.contains("%") {
        return encoded
    }
    if let ascii = components.url?.host, !ascii.isEmpty {
        return ascii
    }
    return nil
}
