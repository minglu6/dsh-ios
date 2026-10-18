import Foundation

/// Android `ConnectionsScreen.buildConnStatusLine`: `在线 · Tailscale · 当前`.
public func connectionsStatusLine(status: String, routeLabel: String, current: String?) -> String {
    var parts = [status]
    if !routeLabel.isEmpty { parts.append(routeLabel) }
    if let current, !current.isEmpty { parts.append(current) }
    return parts.joined(separator: " · ")
}

/// Phone Host list is a full-window page (Android `Screen.Connections` +
/// `drawer.close()`). Never a drawer remainder, trailing panel, or
/// `.presentationDetents(.medium)` sheet.
public let connectionsPageIsFullScreen = true
public let connectionsPageDismissesDrawer = true
public let connectionsPageUsesSheetPresentation = false
public let connectionsPageUsesDrawerPresentation = false
public let connectionsPageMinWidthRatio: Double = 0.98
public let connectionsPageMinHeightRatio: Double = 0.90

/// Controller page title. Desktop Settings `pocket` is Host-side
/// 「手机连接」QR — that copy stays off the phone.
public func connectionsPageTitle(english: Bool) -> String {
    english ? "Remote host" : "远程主机"
}
