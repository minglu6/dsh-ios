import Foundation

/// Pure `dshpocket://` pairing URI policy shared with the plugin via `contract/pairing-uri-cases.json`.
/// Happy path: `dshpocket://pair?h=<host:port>&c=<6-digit>`
/// Legacy iroh forms (`n=` / `nodeId#code`) are rejected.
public enum PairingUriPolicy {
    public static func parse(_ text: String) -> PairingLink? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("dshpocket://pair") else { return nil }
        let query = trimmed.split(separator: "?", maxSplits: 1).dropFirst().first.map(String.init) ?? ""
        var fields: [String: String] = [:]
        for part in query.split(separator: "&") where !part.isEmpty {
            let pieces = part.split(separator: "=", maxSplits: 1)
            let key = String(pieces[0])
            let raw = pieces.count > 1 ? String(pieces[1]) : ""
            // Android `PairingUriPolicy`: unfinished percent-escapes (e.g. `h=mac%`)
            // must fail closed. Do not fall back to the raw fragment.
            guard let value = raw.removingPercentEncoding else { return nil }
            fields[key] = value
        }
        guard let code = fields["c"], code.count == 6, code.allSatisfy(\.isNumber) else { return nil }
        if let node = fields["n"], !node.isEmpty { return nil }
        guard let hostField = fields["h"], !hostField.isEmpty, let parsed = parseHostPort(hostField) else {
            return nil
        }
        return PairingLink(host: parsed.0, port: parsed.1, code: code)
    }
}
