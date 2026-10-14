import Foundation

public struct HandshakeVersions: Sendable, Equatable {
    public var proto: Int
    public var pluginVersion: String
    public var minimumAppVersion: String
    public init(proto: Int, pluginVersion: String, minimumAppVersion: String) {
        self.proto = proto
        self.pluginVersion = pluginVersion
        self.minimumAppVersion = minimumAppVersion
    }
}

public enum CompatibilityIssueKind: Sendable {
    case appTooOld
    case pluginTooOld
    case protocolUnsupported
}

public struct CompatibilityIssue: Sendable, Equatable {
    public var kind: CompatibilityIssueKind
    public var requiredVersion: String?
    public init(kind: CompatibilityIssueKind, requiredVersion: String? = nil) {
        self.kind = kind
        self.requiredVersion = requiredVersion
    }
}

public enum VersionCompatibility {
    public static let proto = 1
    public static let minimumPluginVersion = "0.1.0"
    public static let minimumAppVersion = "0.1.0"

    public static func evaluate(appVersion: String, handshake: HandshakeVersions) -> CompatibilityIssue? {
        if handshake.proto != proto {
            return CompatibilityIssue(kind: .protocolUnsupported)
        }
        if parse(appVersion) == nil || parse(handshake.pluginVersion) == nil || parse(handshake.minimumAppVersion) == nil {
            return CompatibilityIssue(kind: .protocolUnsupported)
        }
        if compareVersions(appVersion, handshake.minimumAppVersion) < 0 {
            return CompatibilityIssue(kind: .appTooOld, requiredVersion: handshake.minimumAppVersion)
        }
        if compareVersions(handshake.pluginVersion, minimumPluginVersion) < 0 {
            return CompatibilityIssue(kind: .pluginTooOld, requiredVersion: minimumPluginVersion)
        }
        return nil
    }

    public static func compareVersions(_ left: String, _ right: String) -> Int {
        guard let leftParts = parse(left) else { return -1 }
        guard let rightParts = parse(right) else { return 1 }
        for index in 0..<3 {
            if leftParts[index] < rightParts[index] { return -1 }
            if leftParts[index] > rightParts[index] { return 1 }
        }
        return 0
    }

    private static func parse(_ value: String) -> [Int]? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let core = trimmed.split(whereSeparator: { $0 == "-" || $0 == "+" }).first.map(String.init) ?? trimmed
        let parts = core.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2]) else { return nil }
        return [major, minor, patch]
    }
}
