/// Phone WS reconnect gate. Port of Android `ConnectionRestorePolicy`.
/// A network-available signal must never tear down a live Online socket.
public enum ConnectionDot: String, Sendable {
    case online, connecting, offline, unauthorized
}

public enum ConnectionRestorePolicy {
    public static func shouldReconnect(_ dot: ConnectionDot?) -> Bool {
        switch dot {
        case .offline, .connecting: return true
        case .online, .unauthorized, nil: return false
        }
    }
}
