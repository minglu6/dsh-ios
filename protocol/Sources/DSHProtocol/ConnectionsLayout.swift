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

/// Android `Card` / `SettingsCard` (`Screens.kt` / `SettingsPages.kt`):
/// `padding(horizontal = 18.dp, vertical = 6.dp)` around desktop settings-card
/// fill + stroke. The 6pt is **outer** margin, so two stacked cards sit
/// 12pt apart. Desktop `ui-theme` `base.css` only publishes the material
/// aliases + `--dsw-radius-lg`; the gap token is the phone card chrome.
public let connectionsCardVerticalPaddingPoints: Double = 6
public let connectionsCardStackGapPoints: Double = connectionsCardVerticalPaddingPoints * 2

/// Android `ConnSectionTitle` (`Screens.kt`): 14sp / `lineHeight` 20sp,
/// `padding(start/end = 22.dp, top = 16.dp, bottom = 4.dp)`.
public let connectionsSectionTitleFontSizePoints: Double = 14
public let connectionsSectionTitleLineHeightPoints: Double = 20
public let connectionsSectionTitlePaddingTopPoints: Double = 16
public let connectionsSectionTitlePaddingBottomPoints: Double = 4

/// Paired card → nearby card: Card 6 + ConnSectionTitle 16+20+4 + Card 6.
/// Adjacent action cards stay on `connectionsCardStackGapPoints` (12).
public let connectionsPairedNearbyGapPoints: Double =
    connectionsCardVerticalPaddingPoints
    + connectionsSectionTitlePaddingTopPoints
    + connectionsSectionTitleLineHeightPoints
    + connectionsSectionTitlePaddingBottomPoints
    + connectionsCardVerticalPaddingPoints

/// Android `PocketSheet` dragHandle (`Sheets.kt`):
/// `padding(top = 10.dp, bottom = 14.dp).size(40.dp, 4.dp)`.
public let connectionsSheetDragHandleTopPoints: Double = 10
public let connectionsSheetDragHandleHeightPoints: Double = 4
public let connectionsSheetDragHandleBottomPoints: Double = 14
public let connectionsSheetDragHandleAreaPoints: Double =
    connectionsSheetDragHandleTopPoints
    + connectionsSheetDragHandleHeightPoints
    + connectionsSheetDragHandleBottomPoints

/// Phone dismiss control on ConnSheet. Android swipes the sheet; iOS still
/// needs a ghost「取消」. Hit height is the same 44pt as
/// `sidebarFooterHitMinHeightPoints`.
public let connectionsSheetCancelMinHeightPoints: Double = sidebarFooterHitMinHeightPoints

/// Desktop `ui-primitives` `Button.module.css`: 14/22, `--dsw-radius-md` 12,
/// `.button:disabled { opacity: 0.4 }`, outline `0.5px` stroke.
/// Android `PrimaryColors` `disabledContainerColor = Caption` is **not**
/// desktop — desktop wins.
public let dswButtonFontSizePoints: Double = 14
public let dswButtonLineHeightPoints: Double = 22
public let dswButtonRadiusMdPoints: Double = 12
public let dswButtonDisabledOpacity: Double = 0.4
public let dswButtonOutlineWidthPoints: Double = 0.5
public let dswButtonMdHeightPoints: Double = 36

/// Android `PairLinkSheet` / `ConnField` (9aa43c4 / 33b97b2): phone touch
/// height 48, field 14pt / pad 14×12 / radius-md 12. Sheet title 18
/// semibold; hint 13 tertiary.
public let connectionsPairLinkButtonHeightPoints: Double = 48
public let connectionsFieldFontSizePoints: Double = 14
public let connectionsFieldLabelFontSizePoints: Double = 12
public let connectionsFieldRadiusPoints: Double = dswButtonRadiusMdPoints
public let connectionsFieldHorizontalPaddingPoints: Double = 14
public let connectionsFieldVerticalPaddingPoints: Double = 12
public let connectionsSheetTitleFontSizePoints: Double = 18
public let connectionsSheetHintFontSizePoints: Double = 13

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
/// Nearby leading icon is Android `Icons.Outlined.Computer` (Material 24×24);
/// `ui-primitives@0.2.1-alpha.5` has no IconComputer.
public func connectionsPairingLinkSymbol() -> String { "official.linkOutline" }
public func connectionsEnterAddressSymbol() -> String { "connections.keyboard" }
public func connectionsNearbyComputerSymbol() -> String { "connections.computer" }

/// ProfileManageSheet actions: desktop `IconRefreshOutlineRegular` /
/// `IconEditOutlineRegular` / `IconTrashOutlineRegular` (Android `D.refresh` /
/// `D.edit` / `D.trash`). OptionRow tints them `T.Ink`, not a destructive red.
public func connectionsManageRepairSymbol() -> String { "official.refreshOutline" }
public func connectionsManageRenameSymbol() -> String { "official.editOutline" }
public func connectionsManageTrashSymbol() -> String { "official.trashOutline" }

public func connectionsActionRowIdentifier(_ action: ConnectionsAction) -> String {
    "connectionsAction.\(action.rawValue)"
}

public func connectionsPairedCardIdentifier() -> String { "connectionsPairedCard" }
public func connectionsNearbyCardIdentifier() -> String { "connectionsNearbyCard" }
public func connectionsPairedRowIdentifier() -> String { "connectionsPairedRow" }
public func connectionsNearbyRowIdentifier() -> String { "connectionsNearbyRow" }
public func connectionsActionsCardIdentifier() -> String { "connectionsActionsCard" }
public func connectionsPairLinkSheetIdentifier() -> String { "connectionsPairLinkSheet" }
public func connectionsPairLinkCancelIdentifier() -> String { "connectionsPairLinkCancel" }
public func connectionsPairingLinkFieldIdentifier() -> String { "connectionsPairingLinkField" }
public func connectionsPastePairingLinkIdentifier() -> String { "connectionsPastePairingLink" }
public func connectionsReviewPairingLinkIdentifier() -> String { "connectionsReviewPairingLink" }
public func connectionsInvalidPairingLinkIdentifier() -> String { "connectionsInvalidPairingLink" }
public func connectionsAddressFieldIdentifier() -> String { "connectionsAddressField" }
public func connectionsCodeFieldIdentifier() -> String { "connectionsCodeField" }
public func connectionsManageSheetIdentifier() -> String { "connectionsManageSheet" }
public func connectionsManageCancelIdentifier() -> String { "connectionsManageCancel" }
public func connectionsManageRepairIdentifier() -> String { "connectionsManageRepair" }
public func connectionsManageRenameIdentifier() -> String { "connectionsManageRename" }
public func connectionsManageDeleteIdentifier() -> String { "connectionsManageDelete" }

public func isForbiddenConnectionsEnterAddressSymbol(_ name: String) -> Bool {
    name == "keyboard" || name == "keyboard.fill"
}

public func isForbiddenConnectionsNearbySymbol(_ name: String) -> Bool {
    name == "desktopcomputer"
}

public func isForbiddenConnectionsManageSymbol(_ name: String) -> Bool {
    name == "trash" || name == "arrow.clockwise" || name == "pencil"
}

/// Google Material Icons Outlined Keyboard, 24×24 view box — Android 33b97b2.
public let connectionsKeyboardFramePath =
    "M20 5H4C2.9 5 2.01 5.9 2.01 7L2 17C2 18.1 2.9 19 4 19H20C21.1 19 22 18.1 22 17V7C22 5.9 21.1 5 20 5ZM20 17H4V7H20V17Z"
/// Material Outlined Keyboard space bar (centered, x 8–16).
public let connectionsKeyboardSpacePath = "M8 14H16V16H8V14Z"
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
    connectionsKeyboardSpacePath,
]
public let connectionsKeyboardViewBox: Double = 24

/// Google Material Icons Outlined Computer, 24×24 view box — Android
/// `ConnectionsScreen` nearby row (`Icons.Outlined.Computer`, tint `T.Accent`).
public let connectionsComputerPath =
    "M20 18c1.1 0 1.99-.9 1.99-2L22 6c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2H0v2h24v-2h-4zM4 6h16v10H4V6z"
public let connectionsComputerViewBox: Double = 24

public func connectionsShowsInvalidPairingLink(text: String, pasted: Bool, parsed: Bool) -> Bool {
    !parsed && (pasted || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
}
