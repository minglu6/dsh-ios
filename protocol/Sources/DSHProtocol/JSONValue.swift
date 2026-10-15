import Foundation

/// Loose JSON tree matching Android `kotlinx.serialization.json.JsonElement` accessors.
public enum JSONValue: Sendable, Equatable, CustomStringConvertible {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public var description: String {
        (try? encodeString()) ?? "null"
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public subscript(_ key: String) -> JSONValue {
        if case .object(let object) = self { return object[key] ?? .null }
        return .null
    }

    public func obj() -> [String: JSONValue]? {
        if case .object(let object) = self { return object }
        return nil
    }

    public func arr() -> [JSONValue]? {
        if case .array(let array) = self { return array }
        return nil
    }

    public func str() -> String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public func bool() -> Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public func double() -> Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    public func long() -> Int64? {
        switch self {
        case .number(let value):
            if value.isFinite, value.rounded() == value,
               value >= Double(Int64.min), value <= Double(Int64.max) {
                return Int64(value)
            }
            return nil
        case .string(let value):
            return Int64(value)
        default:
            return nil
        }
    }

    public func int() -> Int? {
        guard let value = long(), value >= Int64(Int.min), value <= Int64(Int.max) else { return nil }
        return Int(value)
    }

    public static func parse(_ text: String) throws -> JSONValue {
        var parser = StrictJSONParser(text)
        return try parser.parseDocument()
    }

    public static func parse(_ data: Data) throws -> JSONValue {
        guard let text = String(data: data, encoding: .utf8) else {
            throw PocketError(code: "invalid-json", message: "json is not utf-8")
        }
        return try parse(text)
    }

    public func encodeString() throws -> String {
        let data = try JSONSerialization.data(withJSONObject: nsObject(), options: [.fragmentsAllowed])
        guard let text = String(data: data, encoding: .utf8) else {
            throw PocketError(code: "internal", message: "json encode failed")
        }
        return text
    }

    public func prettyString() -> String? {
        guard let object = try? nsObject() else { return nil }
        guard JSONSerialization.isValidJSONObject(object) || object is NSNumber || object is String || object is NSNull else {
            return nil
        }
        let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .fragmentsAllowed, .sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    public static func from(_ raw: Any) -> JSONValue {
        switch raw {
        case let dictionary as [String: Any]:
            return .object(dictionary.mapValues { from($0) })
        case let array as [Any]:
            return .array(array.map { from($0) })
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        case is NSNull:
            return .null
        default:
            return .null
        }
    }

    public func nsObject() throws -> Any {
        switch self {
        case .object(let object):
            return Dictionary(uniqueKeysWithValues: try object.map { ($0.key, try $0.value.nsObject()) })
        case .array(let array):
            return try array.map { try $0.nsObject() }
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded() == value, let asInt = long() {
                return NSNumber(value: asInt)
            }
            return NSNumber(value: value)
        case .bool(let value):
            return NSNumber(value: value)
        case .null:
            return NSNull()
        }
    }
}

public func jsonObject(_ pairs: [String: JSONValue?]) -> JSONValue {
    var object: [String: JSONValue] = [:]
    for (key, value) in pairs {
        guard let value, !value.isNull else { continue }
        object[key] = value
    }
    return .object(object)
}

public func jsonObjectKeeping(_ pairs: [String: JSONValue]) -> JSONValue {
    .object(pairs)
}

public extension JSONValue {
    func at(_ path: [String]) -> JSONValue {
        path.reduce(self) { $0[$1] }
    }

    func requiredString(_ field: String) throws -> String {
        guard let value = str(), !value.isEmpty else {
            throw PocketError(code: "invalid-response", message: "\(field) must be a non-empty string")
        }
        return value
    }

    /// Schemastery and pocket JSON may name a graph node as a string or a number uid.
    func refId() -> String? {
        if let value = str() { return value }
        if let value = long() { return String(value) }
        if let value = self["uid"].str() { return value }
        if let value = self["uid"].long() { return String(value) }
        return nil
    }
}

public extension JSONValue {
    static func stringOrNull(_ value: String?) -> JSONValue {
        value.map { .string($0) } ?? .null
    }
}

/// RFC 8259 parser with fragments. Rejects trailing commas and leading zeros the way
/// kotlinx.serialization `Json.parseToJsonElement` does — Foundation `JSONSerialization` does not.
private struct StrictJSONParser {
    let scalars: [Unicode.Scalar]
    var i = 0

    init(_ text: String) {
        scalars = Array(text.unicodeScalars)
    }

    mutating func parseDocument() throws -> JSONValue {
        skip()
        let value = try parseValue()
        skip()
        guard i >= scalars.count else { throw invalid() }
        return value
    }

    mutating func parseValue() throws -> JSONValue {
        skip()
        guard let c = peek() else { throw invalid() }
        switch c {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"": return .string(try parseString())
        case "t": return try parseLiteral("true", .bool(true))
        case "f": return try parseLiteral("false", .bool(false))
        case "n": return try parseLiteral("null", .null)
        default:
            if c == "-" || c.isJSONDigit { return .number(try parseNumber()) }
            throw invalid()
        }
    }

    mutating func parseObject() throws -> JSONValue {
        try expect("{")
        skip()
        var object: [String: JSONValue] = [:]
        if peek() == "}" {
            i += 1
            return .object(object)
        }
        while true {
            skip()
            guard peek() == "\"" else { throw invalid() }
            let key = try parseString()
            skip()
            try expect(":")
            object[key] = try parseValue()
            skip()
            if peek() == "}" {
                i += 1
                return .object(object)
            }
            try expect(",")
            skip()
            if peek() == "}" { throw invalid() }
        }
    }

    mutating func parseArray() throws -> JSONValue {
        try expect("[")
        skip()
        var array: [JSONValue] = []
        if peek() == "]" {
            i += 1
            return .array(array)
        }
        while true {
            array.append(try parseValue())
            skip()
            if peek() == "]" {
                i += 1
                return .array(array)
            }
            try expect(",")
            skip()
            if peek() == "]" { throw invalid() }
        }
    }

    mutating func parseString() throws -> String {
        try expect("\"")
        var result = ""
        while let c = peek() {
            if c == "\"" {
                i += 1
                return result
            }
            if c == "\\" {
                i += 1
                result.append(try parseEscape())
                continue
            }
            if c.value < 0x20 { throw invalid() }
            result.unicodeScalars.append(c)
            i += 1
        }
        throw invalid()
    }

    mutating func parseEscape() throws -> String {
        guard let c = peek() else { throw invalid() }
        i += 1
        switch c {
        case "\"": return "\""
        case "\\": return "\\"
        case "/": return "/"
        case "b": return "\u{8}"
        case "f": return "\u{c}"
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"
        case "u":
            let unit = try parseHex4()
            if (0xD800...0xDBFF).contains(unit) {
                guard peek() == "\\" else { throw invalid() }
                i += 1
                guard peek() == "u" else { throw invalid() }
                i += 1
                let low = try parseHex4()
                guard (0xDC00...0xDFFF).contains(low) else { throw invalid() }
                let scalar = 0x10000 + (Int(unit) - 0xD800) * 0x400 + (Int(low) - 0xDC00)
                guard let unicode = Unicode.Scalar(scalar) else { throw invalid() }
                return String(unicode)
            }
            if (0xDC00...0xDFFF).contains(unit) { throw invalid() }
            guard let unicode = Unicode.Scalar(unit) else { throw invalid() }
            return String(unicode)
        default:
            throw invalid()
        }
    }

    mutating func parseHex4() throws -> UInt16 {
        var value: UInt16 = 0
        for _ in 0..<4 {
            guard let c = peek(), let digit = hexDigit(c) else { throw invalid() }
            i += 1
            value = value << 4 | digit
        }
        return value
    }

    mutating func parseNumber() throws -> Double {
        let start = i
        if peek() == "-" { i += 1 }
        guard let first = peek(), first.isJSONDigit else { throw invalid() }
        if first == "0" {
            i += 1
            if let next = peek(), next.isJSONDigit { throw invalid() }
        } else {
            while let c = peek(), c.isJSONDigit { i += 1 }
        }
        if peek() == "." {
            i += 1
            guard let c = peek(), c.isJSONDigit else { throw invalid() }
            while let d = peek(), d.isJSONDigit { i += 1 }
        }
        if peek() == "e" || peek() == "E" {
            i += 1
            if peek() == "+" || peek() == "-" { i += 1 }
            guard let c = peek(), c.isJSONDigit else { throw invalid() }
            while let d = peek(), d.isJSONDigit { i += 1 }
        }
        let literal = String(String.UnicodeScalarView(scalars[start..<i]))
        guard let value = Double(literal), value.isFinite else { throw invalid() }
        return value
    }

    mutating func parseLiteral(_ expected: String, _ value: JSONValue) throws -> JSONValue {
        for scalar in expected.unicodeScalars {
            guard peek() == scalar else { throw invalid() }
            i += 1
        }
        if let c = peek(), isTokenContinue(c) { throw invalid() }
        return value
    }

    mutating func expect(_ scalar: Unicode.Scalar) throws {
        guard peek() == scalar else { throw invalid() }
        i += 1
    }

    mutating func skip() {
        while let c = peek(), c == " " || c == "\t" || c == "\n" || c == "\r" { i += 1 }
    }

    func peek() -> Unicode.Scalar? {
        i < scalars.count ? scalars[i] : nil
    }

    func invalid() -> PocketError {
        PocketError(code: "invalid-json", message: "invalid json")
    }
}

private extension Unicode.Scalar {
    var isJSONDigit: Bool { self >= "0" && self <= "9" }
}

private func hexDigit(_ c: Unicode.Scalar) -> UInt16? {
    if c >= "0" && c <= "9" { return UInt16(c.value - Unicode.Scalar("0").value) }
    if c >= "a" && c <= "f" { return UInt16(c.value - Unicode.Scalar("a").value + 10) }
    if c >= "A" && c <= "F" { return UInt16(c.value - Unicode.Scalar("A").value + 10) }
    return nil
}

private func isTokenContinue(_ c: Unicode.Scalar) -> Bool {
    (c >= "0" && c <= "9") || (c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c == "_"
}
