import Foundation

/// iOS background WS keep-alive and resume. Not a ForegroundService equivalent.
/// `beginBackgroundTask` is typically ~30s; ping often enough to use that window
/// without a chatty timer. BGAppRefresh is a later lightweight reconnect/refresh.
public enum BackgroundKeepAlivePolicy {
    public static let taskIdentifier = "dev.dsh.pocket.ios.refresh"
    public static let pingIntervalMs: Int64 = 10_000
    public static let pingTimeoutMs: Int64 = 5_000
    public static let refreshEarliestBeginSeconds: TimeInterval = 15 * 60

    public enum ResumeWork: Equatable, Sendable {
        /// Offline, stuck connecting, or a zombie Online socket.
        case reconnect
        /// Live Online socket: refresh unread / jobs / current follow.
        case refreshLive
        /// No active profile, or auth must be repaired.
        case none
    }

    public enum PingResult: Equatable, Sendable {
        case skipped
        case ok
        case failed
    }

    /// Detect the socket instead of trusting a stale Online dot.
    /// A live Online socket is never torn down.
    public static func resumeWork(dot: ConnectionDot?, socketOpen: Bool) -> ResumeWork {
        switch dot {
        case .unauthorized, nil:
            return .none
        case .offline, .connecting:
            return .reconnect
        case .online:
            return socketOpen ? .refreshLive : .reconnect
        }
    }
}
