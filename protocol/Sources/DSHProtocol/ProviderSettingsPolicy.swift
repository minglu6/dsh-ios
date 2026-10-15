import Foundation

public struct ProviderAddOptions: Equatable, Sendable {
    public var catalog: [JSONValue]
    public var customNamespace: JSONValue?
    public var catalogOffered: Bool

    public var offered: Bool { catalogOffered || customNamespace != nil }

    public func enabled(protocols: [String]) -> Bool {
        !catalog.isEmpty || (customNamespace != nil && !protocols.isEmpty)
    }
}

/// Catalog adoption does not depend on the adapter that owns custom API routes.
public func providerAddOptions(rows: [JSONValue], namespaces: [JSONValue]) -> ProviderAddOptions {
    let registered = Set(namespaces.compactMap { $0["ns"].str() })
    let configurable = rows.filter { row in
        guard let ns = row["settingsNs"].str() else { return false }
        return registered.contains(ns)
    }
    return ProviderAddOptions(
        catalog: configurable.filter { $0["configured"].bool() == false },
        customNamespace: namespaces.first { $0["ns"].str() == "llm-pi-ai" },
        catalogOffered: !configurable.isEmpty
    )
}

public func providerTakenRoutes(rows: [JSONValue], namespace: JSONValue?) -> Set<String> {
    var taken = Set(rows.compactMap { $0["provider"].str() })
    for layer in ["user", "value"] {
        if let providers = namespace?[layer]["providers"].obj() {
            for (route, profile) in providers where !profile.isNull {
                taken.insert(route)
            }
        }
    }
    return taken
}

public func providerRouteFailure(_ route: String, taken: Set<String>, en: Bool = false) -> String? {
    let pattern = try! NSRegularExpression(pattern: #"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"#)
    if route.isEmpty { return en ? "Enter a Provider ID" : "请填写 Provider ID" }
    let ns = route as NSString
    if pattern.firstMatch(in: route, range: NSRange(location: 0, length: ns.length)) == nil {
        return en
            ? "Use a lowercase Provider ID beginning with a letter"
            : "Provider ID 以字母开头，仅含小写字母、数字与连字符"
    }
    if taken.contains(route) { return en ? "This Provider ID is already in use" : "该 Provider ID 已被占用" }
    return nil
}

public func providerEndpointValid(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else {
        return false
    }
    return scheme == "http" || scheme == "https"
}

public struct ProviderRemovalProgress: Equatable, Sendable {
    public var configurationRemoved: Bool
    public var credentialRemoved: Bool

    public init(configurationRemoved: Bool = false, credentialRemoved: Bool = false) {
        self.configurationRemoved = configurationRemoved
        self.credentialRemoved = credentialRemoved
    }
}

/// A rejected configuration CAS must never remove a still-live provider's key.
public func removeProviderSafely(
    progress: ProviderRemovalProgress,
    onProgress: (ProviderRemovalProgress) -> Void,
    removeConfiguration: () async throws -> Void,
    confirmRemoval: () async throws -> Void,
    clearManagedCredential: () async throws -> Void
) async throws {
    var current = progress
    if !current.configurationRemoved {
        try await removeConfiguration()
        current.configurationRemoved = true
        onProgress(current)
    }
    try await confirmRemoval()
    if !current.credentialRemoved {
        try await clearManagedCredential()
        current.credentialRemoved = true
        onProgress(current)
    }
}

public struct ProviderCreationBaseline: Equatable, Sendable {
    public var namespace: JSONValue
    public var revision: Int64
    public var taken: Set<String>
}

/// Refresh only conflict metadata; editable provider and secret drafts remain owned by the form.
public func providerCreationBaseline(_ listed: JSONValue, ns: String) throws -> ProviderCreationBaseline {
    guard let namespace = listed["namespaces"].arr()?.first(where: { $0["ns"].str() == ns }) else {
        throw PocketError(code: "invalid-response", message: "Missing provider namespace: \(ns)")
    }
    guard let revision = namespace["revision"].long(), revision >= 0 else {
        throw PocketError(code: "invalid-response", message: "Missing provider configuration revision")
    }
    return ProviderCreationBaseline(
        namespace: namespace,
        revision: revision,
        taken: providerTakenRoutes(listed["rows"].arr() ?? [], namespace: namespace)
    )
}

public func providerKeyFailure(_ draft: String) -> String? {
    if draft.isEmpty { return nil }
    let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty { return "keyBlank" }
    let envAssign = try! NSRegularExpression(pattern: #"^[A-Z][A-Z0-9_]*=[^=]"#)
    let ns = value as NSString
    let illegalScalar = value.unicodeScalars.contains { $0.value < 33 || $0.value > 126 }
    let quoted = value.count > 1 && ["\"", "'", "`"].contains(String(value.first!)) && value.last == value.first
    if illegalScalar || envAssign.firstMatch(in: value, range: NSRange(location: 0, length: ns.length)) != nil || quoted {
        return "keyIllegalCharacters"
    }
    return nil
}

public func providerKeyRef(_ route: String) -> String {
    let upper = route.uppercased()
    let cleaned = upper.replacingOccurrences(of: #"[^A-Z0-9]+"#, with: "_", options: .regularExpression)
    return "\(cleaned)_API_KEY"
}

/// Name only fields owned by this form; never replace a secret-bearing parent.
public func providerFieldOps(path: [String], before: JSONValue?, after: [String: JSONValue]) -> [JSONValue] {
    after.compactMap { key, value in
        let previous = before?[key] ?? .null
        if previous == value || (previous.isNull && value.isNull) { return nil }
        if value.isNull {
            return jsonObjectKeeping([
                "op": .string("unset"),
                "path": .array((path + [key]).map { .string($0) }),
            ])
        }
        return jsonObjectKeeping([
            "op": .string("set"),
            "path": .array((path + [key]).map { .string($0) }),
            "value": value,
        ])
    }
}

public func validateProviderModels(_ models: [JSONValue]) -> String? {
    var ids = Set<String>()
    for (index, model) in models.enumerated() {
        let id = model["id"].str()?.trimmingCharacters(in: .whitespacesAndNewlines)
        if id == nil || id?.isEmpty == true { return "Model \(index + 1): id" }
        if !ids.insert(id!).inserted { return "Model \(index + 1): duplicate id" }
        if !model["name"].isNull, model["name"].str()?.isEmpty != false {
            return "Model \(index + 1): name"
        }
        for field in ["contextWindow", "maxTokens"] {
            let value = model[field]
            if value.isNull { continue }
            guard let number = value.long(), number > 0, value.str() == nil else {
                return "Model \(index + 1): \(field)"
            }
        }
    }
    return nil
}

public func providerProtocolChoices(_ envelope: JSONValue?) -> [String] {
    let refs = envelope?["refs"].obj()
    func resolve(_ raw: JSONValue?) -> JSONValue? {
        if let id = raw?.refId(), let refs, let resolved = refs[id] { return resolved }
        return raw
    }
    func at(_ raw: JSONValue?, path: [String], visited: Set<String>) -> [JSONValue] {
        guard let node = resolve(raw) else { return [] }
        let identity = (try? node.encodeString()) ?? UUID().uuidString
        if visited.contains(identity) { return [] }
        if path.isEmpty { return [node] }
        switch node["type"].str() {
        case "object":
            return at(node["dict"][path[0]], path: Array(path.dropFirst()), visited: visited.union([identity]))
        case "dict":
            return at(node["inner"], path: Array(path.dropFirst()), visited: visited.union([identity]))
        case "intersect", "union":
            return (node["list"].arr() ?? []).flatMap { at($0, path: path, visited: visited.union([identity])) }
        default:
            return []
        }
    }
    var seen = Set<String>()
    var out: [String] = []
    for node in at(envelope, path: ["providers", "__probe__", "api"], visited: []) {
        for value in node["list"].arr() ?? [] {
            if let text = resolve(value)?["value"].str(), seen.insert(text).inserted {
                out.append(text)
            }
        }
    }
    return out
}

public func protocolLabel(_ protocolName: String) -> String {
    switch protocolName {
    case "openai-completions": return "OpenAI Chat Completions"
    case "openai-responses": return "OpenAI Responses"
    case "anthropic-messages": return "Anthropic Messages"
    default: return protocolName
    }
}

public func providerOptionLabel(row: JSONValue?, route: String) -> String {
    row?["displayName"].str() ?? route
}
