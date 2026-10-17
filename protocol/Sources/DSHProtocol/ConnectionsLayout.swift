import Foundation

/// Android `ConnectionsScreen.buildConnStatusLine`: `在线 · Tailscale · 当前`.
public func connectionsStatusLine(status: String, routeLabel: String, current: String?) -> String {
    var parts = [status]
    if !routeLabel.isEmpty { parts.append(routeLabel) }
    if let current, !current.isEmpty { parts.append(current) }
    return parts.joined(separator: " · ")
}
