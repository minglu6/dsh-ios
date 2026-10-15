import Foundation

public let trajectoryJsonMaxDepth = 128
private let jsonNumber = try! NSRegularExpression(pattern: #"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#)

public struct TrajectoryJsonDocument: Equatable, Sendable {
    public var source: String
    public var root: JSONValue?
    public var depthLimited: Bool

    public init(source: String, root: JSONValue?, depthLimited: Bool) {
        self.source = source
        self.root = root
        self.depthLimited = depthLimited
    }
}

public func trajectoryJsonDocument(_ source: String) -> TrajectoryJsonDocument {
    var depth = 0
    var quoted = false
    var escaped = false
    for char in source {
        if quoted {
            if escaped { escaped = false }
            else if char == "\\" { escaped = true }
            else if char == "\"" { quoted = false }
        } else {
            switch char {
            case "\"": quoted = true
            case "{", "[":
                depth += 1
                if depth > trajectoryJsonMaxDepth {
                    return TrajectoryJsonDocument(source: source, root: nil, depthLimited: true)
                }
            case "}", "]":
                depth -= 1
            default:
                break
            }
        }
    }
    let root = try? JSONValue.parse(source)
    if let root {
        var pending = [root]
        while let value = pending.popLast() {
            switch value {
            case .object(let object):
                pending.append(contentsOf: object.values)
            case .array(let array):
                pending.append(contentsOf: array)
            case .number(let number):
                let text = jsonNumberLiteral(number)
                let ns = text as NSString
                if jsonNumber.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) == nil {
                    return TrajectoryJsonDocument(source: source, root: nil, depthLimited: false)
                }
            case .bool, .null, .string:
                break
            }
        }
        if case .string = root, source.first != "\"" {
            return TrajectoryJsonDocument(source: source, root: nil, depthLimited: false)
        }
        if case .bool(let flag) = root, source != (flag ? "true" : "false") {
            return TrajectoryJsonDocument(source: source, root: nil, depthLimited: false)
        }
        if case .null = root, source != "null" {
            return TrajectoryJsonDocument(source: source, root: nil, depthLimited: false)
        }
    }
    return TrajectoryJsonDocument(source: source, root: root, depthLimited: false)
}

public struct TrajectoryJsonRow: Equatable, Sendable {
    public var path: String
    public var label: String?
    public var value: JSONValue
    public var depth: Int
    public var closing: Bool
    public var copyPath: String

    public init(
        path: String,
        label: String?,
        value: JSONValue,
        depth: Int,
        closing: Bool = false,
        copyPath: String = "$"
    ) {
        self.path = path
        self.label = label
        self.value = value
        self.depth = depth
        self.closing = closing
        self.copyPath = copyPath
    }

    public var expandable: Bool {
        switch value {
        case .object(let object): return !object.isEmpty
        case .array(let array): return !array.isEmpty
        default: return false
        }
    }
}

public func trajectoryJsonRows(_ root: JSONValue, expanded: Set<String>) -> [TrajectoryJsonRow] {
    var rows: [TrajectoryJsonRow] = []
    var pending = [TrajectoryJsonRow(path: "", label: nil, value: root, depth: 0)]
    while let row = pending.popLast() {
        rows.append(row)
        if row.closing || !row.expandable || !expanded.contains(row.path) { continue }
        pending.append(row.copy(label: nil, closing: true))
        switch row.value {
        case .object(let object):
            for (name, child) in object.reversed() {
                let segment = name.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
                pending.append(TrajectoryJsonRow(
                    path: "\(row.path)/\(segment)",
                    label: name.isEmpty ? "\"\"" : name,
                    value: child,
                    depth: row.depth + 1,
                    copyPath: trajectoryJsonPropertyPath(row.copyPath, name)
                ))
            }
        case .array(let array):
            for index in array.indices.reversed() {
                pending.append(TrajectoryJsonRow(
                    path: "\(row.path)/\(index)",
                    label: String(index),
                    value: array[index],
                    depth: row.depth + 1,
                    copyPath: "\(row.copyPath)[\(index)]"
                ))
            }
        default:
            break
        }
    }
    return rows
}

public func trajectoryJsonRowText(_ row: TrajectoryJsonRow, expanded: Bool) -> String {
    let value: String
    switch row.value {
    case .object(let object):
        if row.closing { value = "}" }
        else if object.isEmpty { value = "{}" }
        else if expanded { value = "{" }
        else { value = trajectoryJsonPreview(row.value) }
    case .array(let array):
        if row.closing { value = "]" }
        else if array.isEmpty { value = "[]" }
        else if expanded { value = "[" }
        else { value = trajectoryJsonPreview(row.value) }
    default:
        value = jsonEncoded(row.value, pretty: false)
    }
    if let label = row.label { return "\(label): \(value)" }
    return value
}

/// Desktop JsonTree previews four object fields / five array entries, to depth two.
public func trajectoryJsonPreview(_ value: JSONValue) -> String {
    func preview(_ element: JSONValue, depth: Int) -> String {
        switch element {
        case .object(let object):
            if depth >= 2 { return "{…}" }
            let entries = Array(object)
            let shown = entries.prefix(4).map { "\($0.key): \(preview($0.value, depth: depth + 1))" }
            let suffix = object.count > 4 ? ", …}" : "}"
            return "{" + shown.joined(separator: ", ") + suffix
        case .array(let array):
            if depth >= 2 { return "[…]" }
            let shown = array.prefix(5).map { preview($0, depth: depth + 1) }
            let suffix = array.count > 5 ? ", …]" : "]"
            return "[" + shown.joined(separator: ", ") + suffix
        default:
            return jsonEncoded(element, pretty: false)
        }
    }
    return preview(value, depth: 0)
}

private let jsonPathIdentifier = try! NSRegularExpression(pattern: #"^[A-Za-z_$][A-Za-z0-9_$]*$"#)

public func trajectoryJsonPropertyPath(_ parent: String, _ name: String) -> String {
    let ns = name as NSString
    if jsonPathIdentifier.firstMatch(in: name, range: NSRange(location: 0, length: ns.length)) != nil {
        return "\(parent).\(name)"
    }
    return "\(parent)[\(jsonEncoded(.string(name), pretty: false))]"
}

public enum TrajectoryJsonCopyMode: String, Equatable, Sendable, CaseIterable {
    case value = "复制值"
    case json = "复制 JSON"
    case path = "复制属性路径"
    case prettyJson = "复制格式化 JSON"
    case compactJson = "复制紧凑 JSON"

    public var label: String { rawValue }
}

public func trajectoryJsonCopyModes(_ value: JSONValue) -> [TrajectoryJsonCopyMode] {
    switch value {
    case .object, .array: return [.prettyJson, .compactJson, .path]
    default: return [.value, .json, .path]
    }
}

public func trajectoryJsonCopyText(_ value: JSONValue, path: String, mode: TrajectoryJsonCopyMode) -> String {
    switch mode {
    case .path: return path
    case .prettyJson: return jsonEncoded(value, pretty: true)
    case .value:
        if case .string(let text) = value { return text }
        return jsonEncoded(value, pretty: false)
    case .json, .compactJson:
        return jsonEncoded(value, pretty: false)
    }
}

private func jsonNumberLiteral(_ value: Double) -> String {
    if value.isFinite, value.rounded() == value, let asInt = Int64(exactly: value) {
        return String(asInt)
    }
    return String(value)
}

public func jsonEncoded(_ value: JSONValue, pretty: Bool) -> String {
    func encode(_ element: JSONValue, indent: Int) -> String {
        let pad = pretty ? String(repeating: "  ", count: indent) : ""
        let inner = pretty ? String(repeating: "  ", count: indent + 1) : ""
        let colon = pretty ? ": " : ":"
        let comma = pretty ? ",\n" : ","
        switch element {
        case .null: return "null"
        case .bool(let flag): return flag ? "true" : "false"
        case .number(let number): return jsonNumberLiteral(number)
        case .string(let text): return jsonStringLiteral(text)
        case .array(let array):
            if array.isEmpty { return "[]" }
            if pretty {
                let body = array.map { "\(inner)\(encode($0, indent: indent + 1))" }.joined(separator: comma)
                return "[\n\(body)\n\(pad)]"
            }
            return "[\(array.map { encode($0, indent: 0) }.joined(separator: ","))]"
        case .object(let object):
            if object.isEmpty { return "{}" }
            if pretty {
                let body = object.map { "\(inner)\(jsonStringLiteral($0.key))\(colon)\(encode($0.value, indent: indent + 1))" }
                    .joined(separator: comma)
                return "{\n\(body)\n\(pad)}"
            }
            return "{\(object.map { "\(jsonStringLiteral($0.key)):\(encode($0.value, indent: 0))" }.joined(separator: ","))}"
        }
    }
    return encode(value, indent: 0)
}

private func jsonStringLiteral(_ value: String) -> String {
    var out = "\""
    for scalar in value.unicodeScalars {
        switch scalar {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        default:
            if scalar.value < 0x20 {
                out += String(format: "\\u%04x", scalar.value)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
    }
    out += "\""
    return out
}

private extension TrajectoryJsonRow {
    func copy(label: String?, closing: Bool) -> TrajectoryJsonRow {
        TrajectoryJsonRow(path: path, label: label, value: value, depth: depth, closing: closing, copyPath: copyPath)
    }
}
