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

/// Android `ConnectionsScreen` action-card order after 9aa43c4 / 33b97b2:
/// 扫码 → 配对链接 → 输入地址.
public enum ConnectionsAction: String, Equatable, Sendable, CaseIterable {
    case scan
    case pairingLink
    case enterAddress
}

public func connectionsActionTitle(_ action: ConnectionsAction, english: Bool) -> String {
    switch action {
    case .scan: return english ? "Scan" : "扫码"
    case .pairingLink: return english ? "Pairing link" : "配对链接"
    case .enterAddress: return english ? "Enter address" : "输入地址"
    }
}

public func connectionsPairingLinkHint(english: Bool) -> String {
    english
        ? "Copy the pairing link from Phone connection in desktop settings, then paste it here."
        : "在电脑「设置 → 手机连接」复制配对链接，然后粘贴到这里。"
}

public func connectionsPastePairingLink(english: Bool) -> String {
    english ? "Paste link" : "粘贴链接"
}

public func connectionsReviewPairingLink(english: Bool) -> String {
    english ? "Continue" : "下一步"
}

public func connectionsInvalidPairingLink(english: Bool) -> String {
    english
        ? "Enter a valid dshpocket://pair link with a host address and six-digit code."
        : "请输入有效的 dshpocket://pair 链接，需包含主机地址和六位配对码。"
}

public let connectionsPairingLinkFieldHint = "dshpocket://pair?h=…&c=…"

/// Pairing-link row uses desktop `IconLinkOutlineRegular`. Enter-address uses
/// Android `Icons.Outlined.Keyboard` (Material 24×24, not ui-primitives).
public func connectionsPairingLinkSymbol() -> String { "official.linkOutline" }
public func connectionsEnterAddressSymbol() -> String { "connections.keyboard" }

public func connectionsActionRowIdentifier(_ action: ConnectionsAction) -> String {
    "connectionsAction.\(action.rawValue)"
}

public func connectionsPairLinkSheetIdentifier() -> String { "connectionsPairLinkSheet" }
public func connectionsPairingLinkFieldIdentifier() -> String { "connectionsPairingLinkField" }
public func connectionsPastePairingLinkIdentifier() -> String { "connectionsPastePairingLink" }
public func connectionsReviewPairingLinkIdentifier() -> String { "connectionsReviewPairingLink" }
public func connectionsInvalidPairingLinkIdentifier() -> String { "connectionsInvalidPairingLink" }
public func connectionsAddressFieldIdentifier() -> String { "connectionsAddressField" }
public func connectionsCodeFieldIdentifier() -> String { "connectionsCodeField" }

public func isForbiddenConnectionsEnterAddressSymbol(_ name: String) -> Bool {
    name == "keyboard" || name == "keyboard.fill"
}

/// Google Material Icons Outlined Keyboard, 24×24 view box — Android 33b97b2.
public let connectionsKeyboardFramePath =
    "M20 5H4C2.9 5 2.01 5.9 2.01 7L2 17C2 18.1 2.9 19 4 19H20C21.1 19 22 18.1 22 17V7C22 5.9 21.1 5 20 5ZM20 17H4V7H20V17Z"
public let connectionsKeyboardKeyPaths = [
    "M5 8H7V10H5V8Z",
    "M5 11H7V13H5V11Z",
    "M8 8H10V10H8V8Z",
    "M8 11H10V13H8V11Z",
    "M11 8H13V10H11V8Z",
    "M11 11H13V13H11V11Z",
    "M14 8H16V10H14V8Z",
    "M14 11H16V13H14V11Z",
    "M17 8H19V10H17V8Z",
    "M17 11H19V13H17V11Z",
    "M6 14H14V16H6V14Z",
]
public let connectionsKeyboardViewBox: Double = 24

public func connectionsShowsInvalidPairingLink(text: String, pasted: Bool, parsed: Bool) -> Bool {
    !parsed && (pasted || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
}
