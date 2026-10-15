import Foundation

/// `_dshpocket._tcp` TXT / announcement parsing. Port of Android `NsdDiscovery` + `LanDiscovery`.
public enum LanDiscoveryPolicy {
    public static let serviceType = "_dshpocket._tcp"
    public static let instanceIdPattern = "^[a-f0-9]{64}$"
    public static let allowedAnnouncementKeys: Set<String> = [
        "deviceName", "host", "port", "protocol", "instanceId",
    ]

    public static func parseTxt(
        deviceName: String?,
        host: String?,
        port: Int?,
        protocolValue: Int?,
        instanceId: String?
    ) -> DiscoveredHost? {
        guard protocolValue == 1 else { return nil }
        guard let instanceId, instanceId.range(of: instanceIdPattern, options: .regularExpression) != nil else {
            return nil
        }
        let name = deviceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty, name.count <= 63 else { return nil }
        let address = host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !address.isEmpty, let port, (1...65535).contains(port) else { return nil }
        return DiscoveredHost(instanceId: instanceId, host: address, port: port, deviceName: name)
    }

    /// Reject secret-bearing payloads: only the five public discovery keys are allowed.
    public static func parseAnnouncement(_ source: String, remoteAddress: String?) -> DiscoveredHost? {
        guard let parsed = try? JSONValue.parse(source), let object = parsed.obj() else { return nil }
        guard Set(object.keys) == allowedAnnouncementKeys else { return nil }
        guard parsed["protocol"].int() == 1 else { return nil }
        let host = parsed["host"].str() ?? ""
        guard let remoteAddress, host == remoteAddress else { return nil }
        return parseTxt(
            deviceName: parsed["deviceName"].str(),
            host: host,
            port: parsed["port"].int(),
            protocolValue: parsed["protocol"].int(),
            instanceId: parsed["instanceId"].str()
        )
    }

    public static func mergeByInstance(_ found: [DiscoveredHost]) -> [DiscoveredHost] {
        var entries: [String: DiscoveredHost] = [:]
        var order: [String] = []
        for host in found {
            if entries[host.instanceId] == nil {
                entries[host.instanceId] = host
                order.append(host.instanceId)
            }
        }
        return order.compactMap { entries[$0] }
    }

    public static func unpairedNearby(
        found: [DiscoveredHost],
        paired: [(instanceId: String, host: String, port: Int, needsRepair: Bool)]
    ) -> [DiscoveredHost] {
        found.filter { disc in
            paired.allSatisfy { profile in
                !((!profile.instanceId.isEmpty && profile.instanceId == disc.instanceId)
                    || (!profile.needsRepair && profile.host == disc.host && profile.port == disc.port))
            }
        }
    }

    public static func applyAddressUpdate(
        instanceId: String,
        host: String,
        port: Int,
        discovered: DiscoveredHost
    ) -> (host: String, port: Int)? {
        if instanceId.isEmpty || instanceId != discovered.instanceId { return nil }
        if host == discovered.host && port == discovered.port { return nil }
        if discovered.host.isEmpty || !(1...65535).contains(discovered.port) { return nil }
        return (discovered.host, discovered.port)
    }
}
