/// Reachability observations apply only to the authorization that requested them.
/// Port of Android `PairedDeviceStatusPolicy`.
public struct PairedDeviceIdentity: Sendable, Equatable {
    public var id: String
    public var host: String
    public var port: Int
    public var instanceId: String
    public var deviceId: String?
    public var needsRepair: Bool

    public init(
        id: String,
        host: String,
        port: Int,
        instanceId: String,
        deviceId: String? = nil,
        needsRepair: Bool = false
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.instanceId = instanceId
        self.deviceId = deviceId
        self.needsRepair = needsRepair
    }
}

public enum PairedDeviceStatusPolicy {
    public static func beginCheck(current: ConnectionDot?) -> ConnectionDot {
        current == .unauthorized ? .unauthorized : .connecting
    }

    public static func mayApplyResult(current: PairedDeviceIdentity, requested: PairedDeviceIdentity) -> Bool {
        statusOf(current) != .unauthorized
            && current.id == requested.id
            && current.host == requested.host
            && current.port == requested.port
            && current.instanceId == requested.instanceId
            && (requested.deviceId?.isEmpty != false || current.deviceId == requested.deviceId)
    }

    public static func applyProbe(
        currentDot: ConnectionDot?,
        current: PairedDeviceIdentity,
        requested: PairedDeviceIdentity,
        reachable: Bool,
        revoked: Bool
    ) -> ConnectionDot {
        guard mayApplyResult(current: current, requested: requested) else {
            return currentDot ?? .offline
        }
        if revoked { return .unauthorized }
        return reachable ? .online : .offline
    }

    private static func statusOf(_ device: PairedDeviceIdentity) -> ConnectionDot {
        device.needsRepair ? .unauthorized : .offline
    }
}
