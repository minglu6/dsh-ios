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
        let data = Data(text.utf8)
        let raw = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return from(raw)
    }

    public static func parse(_ data: Data) throws -> JSONValue {
        let raw = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return from(raw)
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
