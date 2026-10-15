import Foundation

/// Host presentation is authoritative, including names outside the built-in presets.
public struct PermissionOption: Equatable, Sendable {
    public var value: String
    public var name: String
    public var description: String?

    public init(value: String, name: String, description: String? = nil) {
        self.value = value
        self.name = name
        self.description = description
    }
}

/// Live options and persistent-default eligibility are separate Host capabilities.
public struct PermissionCatalog: Equatable, Sendable {
    public var options: [PermissionOption]
    public var defaultOptions: [PermissionOption]
    public var defaultPreset: String

    public init(options: [PermissionOption], defaultOptions: [PermissionOption], defaultPreset: String) {
        self.options = options
        self.defaultOptions = defaultOptions
        self.defaultPreset = defaultPreset
    }

    public func find(_ value: String) -> PermissionOption? {
        options.first { $0.value == value }
    }

    public func allowsDefault(_ value: String) -> Bool {
        defaultOptions.contains { $0.value == value }
    }

    /// Reject incomplete responses rather than silently manufacturing a supported roster.
    public static func parse(_ value: JSONValue?) throws -> PermissionCatalog {
        guard let object = value?.obj() else { throw malformed("catalog must be an object") }
        let options = try optionList(object["options"] ?? .null, field: "options")
        let defaults = try optionList(object["defaultOptions"] ?? .null, field: "defaultOptions")
        let defaultPreset = try requiredString(object["defaultPreset"] ?? .null, field: "defaultPreset")
        if options.contains(where: { $0.value == "custom" }) { throw malformed("custom is not selectable") }
        if defaults.contains(where: { $0.value == "auto" || $0.value == "custom" }) {
            throw malformed("current-session permissions cannot be defaults")
        }
        let values = Set(options.map(\.value))
        if defaults.contains(where: { !values.contains($0.value) }) {
            throw malformed("defaultOptions must be selectable")
        }
        if !defaults.contains(where: { $0.value == defaultPreset }) {
            throw malformed("defaultPreset must be eligible")
        }
        return PermissionCatalog(options: options, defaultOptions: defaults, defaultPreset: defaultPreset)
    }
}

/// Typed selection carried by pocket's existing `current` response envelope.
public struct PermissionSelection: Equatable, Sendable {
    public var currentValue: String

    public static func parse(_ value: JSONValue?) throws -> PermissionSelection {
        guard let object = value?.obj() else { throw malformed("selection must be an object") }
        return PermissionSelection(currentValue: try requiredString(object["current"] ?? .null, field: "current"))
    }
}

private func optionList(_ value: JSONValue, field: String) throws -> [PermissionOption] {
    guard let array = value.arr() else { throw malformed("\(field) must be an array") }
    var seen = Set<String>()
    return try array.enumerated().map { index, element in
        guard let object = element.obj() else { throw malformed("\(field)[\(index)] must be an object") }
        let id = try requiredString(object["value"] ?? .null, field: "\(field)[\(index)].value")
        if !seen.insert(id).inserted { throw malformed("\(field) contains duplicate value \(id)") }
        let name = try stringValue(object["name"] ?? .null, field: "\(field)[\(index)].name")
        let description: String?
        if object.keys.contains("description") {
            description = try stringValue(object["description"] ?? .null, field: "\(field)[\(index)].description")
        } else {
            description = nil
        }
        return PermissionOption(value: id, name: name, description: description)
    }
}

private func stringValue(_ value: JSONValue, field: String) throws -> String {
    guard let text = value.str() else { throw malformed("\(field) must be a string") }
    return text
}

private func requiredString(_ value: JSONValue, field: String) throws -> String {
    let text = try stringValue(value, field: field)
    if text.isEmpty { throw malformed("\(field) must not be empty") }
    return text
}

private func malformed(_ message: String) -> PocketError {
    PocketError(code: "invalid-response", message: "permissions: \(message)")
}
