import Foundation

public let hiddenProfileBundles: Set<String> = [
    "@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "@deepseek-ai/dsh-headless",
    "@deepseek-ai/dsh-sdk-app", "@deepseek-ai/dsh-acp-app", "@deepseek-ai/dsh-sdk-minimal",
]

public let primaryOptionalBundles = [
    "@deepseek-ai/dsh-experimental-agent-team-profile",
    "@deepseek-ai/dsh-experimental-voice-input-bundle",
    "@deepseek-ai/dsh-experimental-auto-review",
    "@deepseek-ai/dsh-experimental-inspector-profile",
]
public let moreOptionalBundles = [
    "@deepseek-ai/dsh-experimental-tool-worktree",
    "@deepseek-ai/dsh-experimental-cot-translation-bundle",
    "@deepseek-ai/dsh-experimental-terminal-bundle",
    "@deepseek-ai/dsh-experimental-session-search",
    "@deepseek-ai/dsh-experimental-session-titles-bundle",
    "@deepseek-ai/dsh-experimental-badge-skill-bundle",
    "@deepseek-ai/dsh-experimental-ralph-bundle",
    "@deepseek-ai/dsh-subagent-codex",
    "@deepseek-ai/dsh-subagent-claude-code",
]

public func pluginOptionalVisible(name: String?, expanded: Bool) -> Bool {
    expanded || name.map { !moreOptionalBundles.contains($0) } ?? true
}

public func pluginOptionalRank(_ name: String?) -> Int {
    if let name, let index = primaryOptionalBundles.firstIndex(of: name) { return index }
    if let name, let index = moreOptionalBundles.firstIndex(of: name) {
        return primaryOptionalBundles.count + 1 + index
    }
    return primaryOptionalBundles.count
}

public func pluginMarketVisible(_ bundle: JSONValue) -> Bool {
    bundle["installed"].bool() == true || bundle["official"].bool() == true || !bundle["error"].isNull
}

public struct PluginMarketGroups: Equatable, Sendable {
    public var official: [JSONValue]
    public var installed: [JSONValue]
}

/// Desktop plugin manager: one 「官方 N」 catalog, then third-party installed rows. Host order is kept.
public func pluginMarketGroups(_ bundles: [JSONValue]) -> PluginMarketGroups {
    let visible = bundles.filter(pluginMarketVisible)
    return PluginMarketGroups(
        official: visible.filter { $0["official"].bool() == true },
        installed: visible.filter { $0["official"].bool() != true }
    )
}

public func pluginExperimental(_ bundle: JSONValue) -> Bool {
    if bundle["official"].bool() == true { return true }
    if bundle["optional"].bool() == true { return true }
    guard let name = bundle["name"].str() else { return false }
    if name.contains("experimental") { return true }
    return primaryOptionalBundles.contains(name) || moreOptionalBundles.contains(name)
}

public func pluginTitle(_ value: JSONValue, english: Bool) -> String {
    pluginLocalized(value["meta"]["title"], english: english)
        ?? value["name"].str()
        ?? value["rowId"].str()
        ?? value["moduleName"].str()
        ?? ""
}

public func pluginDescription(_ value: JSONValue, english: Bool) -> String {
    pluginLocalized(value["meta"]["description"], english: english)
        ?? value["description"].str()
        ?? ""
}

public func pluginNeedsInstallToEnable(_ bundle: JSONValue) -> Bool {
    bundle["availability"].str() == "missing" && bundle["installTarget"]["spec"].str() != nil
}

/// Bundle declarations are not runtime state: only the entryId join can authorize a row switch.
public func pluginLiveRow(_ row: JSONValue, plugins: [JSONValue]) -> JSONValue? {
    guard let id = row["entryId"].str() else { return nil }
    return plugins.first { $0["entryId"].str() == id }
}

public struct PluginParts: Equatable, Sendable {
    public var total: Int
    public var running: Int
    public var off: Int
    public var failed: Int
}

public func pluginParts(rows: [JSONValue], plugins: [JSONValue]) -> PluginParts {
    var running = 0
    var off = 0
    var failed = 0
    for row in rows {
        let live = pluginLiveRow(row, plugins: plugins)
        if live?["enabled"].bool() != true { off += 1 }
        else if live?["fiberPhase"].str() == "active" { running += 1 }
        if live?["fiberPhase"].str() == "failed" { failed += 1 }
    }
    return PluginParts(total: rows.count, running: running, off: off, failed: failed)
}

public func pluginSettingsReplacesSecret(path: [String], secrets: [[String]]) -> Bool {
    secrets.contains { secret in path.count < secret.count && Array(secret.prefix(path.count)) == path }
}

public struct PluginSchemaField: Equatable, Sendable {
    public var path: [String]
    public var type: String
    public var schema: JSONValue
    public var choices: [JSONValue]
}

/// Schemastery serializes a reference graph, not an inline JSON-schema object.
public func pluginSchemaFields(_ envelope: JSONValue?) -> [PluginSchemaField] {
    let refs = envelope?["refs"].obj()
    func resolve(_ node: JSONValue?) -> JSONValue? {
        if let id = node?.refId(), let refs, let resolved = refs[id] { return resolved }
        return node
    }
    var fields: [PluginSchemaField] = []
    var seenPaths = Set<[String]>()
    func visit(_ raw: JSONValue?, path: [String], ancestors: Set<String>) {
        guard let node = resolve(raw) else { return }
        // Ref uids are the graph identity. encodeString() key order is not stable, so it
        // cannot detect a cycle (Android compares JsonElement structurally).
        let identity = raw?.refId() ?? node.refId() ?? schemaNodeIdentity(node)
        if ancestors.contains(identity) { return }
        let type = node["type"].str() ?? ""
        switch type {
        case "object":
            for (key, child) in node["dict"].obj() ?? [:] {
                visit(child, path: path + [key], ancestors: ancestors.union([identity]))
            }
        case "intersect":
            for child in node["list"].arr() ?? [] {
                visit(child, path: path, ancestors: ancestors.union([identity]))
            }
        case "union":
            let choices = (node["list"].arr() ?? []).compactMap(resolve).filter { $0["type"].str() == "const" }.compactMap { $0["value"].isNull ? nil : $0["value"] }
            if !path.isEmpty && !choices.isEmpty {
                let field = PluginSchemaField(path: path, type: "enum", schema: node, choices: choices)
                if seenPaths.insert(path).inserted { fields.append(field) }
            }
        case "boolean", "number", "string":
            if !path.isEmpty {
                let field = PluginSchemaField(path: path, type: type, schema: node, choices: [])
                if seenPaths.insert(path).inserted { fields.append(field) }
            }
        default:
            break
        }
    }
    visit(envelope, path: [], ancestors: [])
    return fields
}

private func schemaNodeIdentity(_ node: JSONValue) -> String {
    guard let object = try? node.nsObject(),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed, .sortedKeys]),
          let text = String(data: data, encoding: .utf8) else {
        return UUID().uuidString
    }
    return text
}

public func pluginLocalized(_ value: JSONValue?, english: Bool) -> String? {
    value?.str() ?? value?[english ? "en" : "zh"].str() ?? value?["en"].str()
}

public func inventoryTitle(_ row: JSONValue, english: Bool) -> String {
    let title = row["meta"]["title"]
    if title.obj() != nil { return pluginLocalized(title, english: english) ?? "" }
    var name = title.str() ?? row["moduleName"].str() ?? ""
    if name.hasPrefix("@") { name = name.split(separator: "/").dropFirst().joined(separator: "/") }
    for prefix in ["cordis:", "cordis-plugin-"] {
        if name.hasPrefix(prefix) { name = String(name.dropFirst(prefix.count)) }
    }
    if let match = name.range(of: #"^dsh-(?:host-|client-)?"#, options: .regularExpression) {
        name = String(name[match.upperBound...])
    }
    return name
}

public func inventoryMatches(_ row: JSONValue, query: String, english: Bool) -> Bool {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if q.isEmpty { return true }
    return [
        row["moduleName"].str(),
        row["entryId"].str(),
        inventoryTitle(row, english: english),
        pluginLocalized(row["meta"]["description"], english: english),
    ].contains { $0?.localizedCaseInsensitiveContains(q) == true }
}

public func inventorySelectedPreset(_ presets: [JSONValue], selectedId: String?) -> JSONValue? {
    presets.first { $0["id"].str() == selectedId }
        ?? presets.first { $0["isDefault"].bool() == true }
        ?? presets.first
}

/// Preset declarations must never be presented as a global runtime or as a mutable profile row.
public func inventoryProviders(entry: JSONValue, presets: [JSONValue]) -> [JSONValue] {
    if entry["enabled"].bool() == true || entry["fiberPhase"].str() == "failed" { return [] }
    return presets.filter { preset in
        (preset["rows"].arr() ?? []).contains {
            $0["moduleName"].str() == entry["moduleName"].str() && $0["enabled"].bool() == true
        }
    }
}

public func inventoryEnablement(_ row: JSONValue, viaPresets: Bool = false) -> String {
    if row["fiberPhase"].str() == "failed" { return "failed" }
    if viaPresets { return "preset" }
    if row["enabled"].str() == "conditional" { return "conditional" }
    if row["enabled"].bool() == true { return "enabled" }
    return "disabled"
}

public func configurationArtwork(_ ns: String) -> String {
    switch ns {
    case "subagent": return "subagent"
    case "web-search-deepseek": return "search"
    case "agent-loop": return "loop"
    case "bash-sandbox", "pwsh-sandbox": return "terminal"
    default: return "default"
    }
}

public let pluginSvgMaxBytes = 256 * 1024
private let pluginSvgDeclaration = try! NSRegularExpression(pattern: "<!\\s*(?:DOCTYPE|ENTITY)\\b", options: [.caseInsensitive])
private let pluginSvgCssUrl = try! NSRegularExpression(pattern: "url\\s*\\(([^)]*)\\)", options: [.caseInsensitive])
private let pluginSvgUnsupported = Set([
    "script", "foreignobject", "image", "iframe", "object", "embed",
    "animate", "animatetransform", "animatemotion", "set", "filter",
])

public func pluginMetadataSVG(_ icon: String?) -> String? {
    guard let icon, icon.count <= pluginSvgMaxBytes * 3 + 64 else { return nil }
    let xml: String
    if icon.lowercased().hasPrefix("data:image/svg+xml;base64,") {
        guard let comma = icon.firstIndex(of: ","),
              let data = Data(base64Encoded: String(icon[icon.index(after: comma)...])),
              data.count <= pluginSvgMaxBytes,
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        xml = text
    } else if icon.lowercased().hasPrefix("data:image/svg+xml,") {
        guard let comma = icon.firstIndex(of: ",") else { return nil }
        let payload = String(icon[icon.index(after: comma)...]).replacingOccurrences(of: "+", with: "%2B")
        xml = payload.removingPercentEncoding ?? payload
    } else {
        return nil
    }
    guard xml.lengthOfBytes(using: .utf8) <= pluginSvgMaxBytes, isSupportedPluginSvg(xml) else { return nil }
    return xml
}

public func isSupportedPluginSvg(_ xml: String) -> Bool {
    let ns = xml as NSString
    if pluginSvgDeclaration.firstMatch(in: xml, range: NSRange(location: 0, length: ns.length)) != nil { return false }
    var i = xml.startIndex
    var elements = 0
    var depth = 0
    while i < xml.endIndex {
        guard xml[i] == "<" else {
            i = xml.index(after: i)
            continue
        }
        let next = xml.index(after: i)
        if next < xml.endIndex && (xml[next] == "?" || xml[next] == "!") { return false }
        let closing = next < xml.endIndex && xml[next] == "/"
        let nameStart = closing ? xml.index(after: next) : next
        var nameEnd = nameStart
        while nameEnd < xml.endIndex && xml[nameEnd].isLetter { nameEnd = xml.index(after: nameEnd) }
        let name = xml[nameStart..<nameEnd].lowercased()
        if closing {
            depth -= 1
            if let close = xml[i...].firstIndex(of: ">") { i = xml.index(after: close) } else { return false }
            continue
        }
        elements += 1
        depth += 1
        if elements > 8192 || depth > 64 { return false }
        if elements == 1 && name != "svg" { return false }
        if pluginSvgUnsupported.contains(name) { return false }
        guard let tagEnd = xml[nameEnd...].firstIndex(of: ">") else { return false }
        let attrs = String(xml[nameEnd..<tagEnd])
        if !pluginSvgAttributesSafe(attrs) { return false }
        if attrs.trimmingCharacters(in: .whitespaces).hasSuffix("/") { depth -= 1 }
        i = xml.index(after: tagEnd)
    }
    return elements > 0
}

private func pluginSvgAttributesSafe(_ raw: String) -> Bool {
    if raw.contains("\\") || raw.lowercased().contains("@import") { return false }
    var rest = raw
    while let eq = rest.firstIndex(of: "=") {
        let name = rest[..<eq].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        rest = String(rest[rest.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        guard let quote = rest.first, quote == "\"" || quote == "'" else { return false }
        rest.removeFirst()
        guard let end = rest.firstIndex(of: quote) else { return false }
        let value = String(rest[..<end]).trimmingCharacters(in: .whitespaces)
        rest = String(rest[rest.index(after: end)...])
        if name.hasPrefix("on") { return false }
        if name == "href" && !value.hasPrefix("#") { return false }
        if !isLocalPluginSvgCss(value) { return false }
    }
    return true
}

private func isLocalPluginSvgCss(_ value: String) -> Bool {
    if value.contains("\\") || value.lowercased().contains("@import") { return false }
    let ns = value as NSString
    let matches = pluginSvgCssUrl.matches(in: value, range: NSRange(location: 0, length: ns.length))
    return matches.allSatisfy { match in
        guard match.numberOfRanges > 1 else { return false }
        let inner = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        return inner.hasPrefix("#")
    }
}

public func pluginChangeText(_ result: JSONValue, en: Bool) -> String {
    switch result["application"].str() {
    case "applied": return en ? "Change applied" : "更改已生效"
    case "restart-required": return en ? "Saved; takes effect after the remote host restarts" : "更改已保存，将在远程主机下次启动生效"
    case "overridden": return en ? "Saved, but overridden by higher-priority configuration" : "更改已保存，但被更高优先级配置覆盖，当前未生效"
    case "cancelled": return en ? "Installation cancelled" : "已取消安装"
    case "failed": return en ? "Operation failed" : "操作失败"
    default: return en ? "Application outcome unknown; refresh to check" : "未收到明确的应用结果，请刷新核对"
    }
}
