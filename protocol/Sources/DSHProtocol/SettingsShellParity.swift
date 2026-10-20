import Foundation

/// Desktop `@deepseek-ai/dsh-client-ui-settings-general@0.2.1-alpha.5`
/// `SettingsRoot.module.css` (inlined in `lib/client.js` as `css$7`).
///
/// Phone settings root is a full-screen of the overlay **left nav** (not the
/// 800px two-pane dialog). Horizontal gutter stays the existing 16pt phone
/// inset; do not copy overlay `.nav` `12px` / `.options` `24px`.
///
/// Phone text uses the same semantic body/headline fonts as general settings;
/// desktop spacing remains the minimum layout budget.

/// `.nav` `gap: 18px` — title cluster to first nav cell / phone card.
public let settingsNavGapPoints: Double = 18
/// Desktop title line-height, used as a minimum to allow Dynamic Type.
public let settingsNavTitleLineHeightPoints: Double = 24
/// `.navCell` `height: 40px` with `box-sizing: border-box`.
public let settingsNavCellHeightPoints: Double = 40
/// `.navCell` `padding: 9px 16px 9px 12px`.
public let settingsNavCellPaddingTopPoints: Double = 9
public let settingsNavCellPaddingBottomPoints: Double = 9
public let settingsNavCellPaddingLeadingPoints: Double = 12
public let settingsNavCellPaddingTrailingPoints: Double = 16
/// `.navCell` `gap: 8px` (icon ↔ label).
public let settingsNavCellGapPoints: Double = 8
/// Desktop navigation line-height, used as a minimum to allow Dynamic Type.
public let settingsNavCellLineHeightPoints: Double = 22

/// Desktop `ui-theme` `base.css` `--dsw-radius-lg` (settings-card material).
/// Android `SettingsCard` uses `T.R16` citing this token. Overlay left nav is
/// not a card; phone wraps the list in the settings-card the way Android does.
public let dswRadiusLgPoints: Double = 16
public var settingsCardRadiusPoints: Double { dswRadiusLgPoints }
/// Desktop models `.rowCard` / iOS existing settings stroke: `.5px`.
public let settingsCardStrokeWidthPoints: Double = 0.5

/// Desktop `ui-theme` `base.css` `--dsw-alias-bg-base` / settings page fill.
public let dswAliasBgBaseLightHex: UInt32 = 0xFFFFFFFF
public let dswAliasBgBaseDarkHex: UInt32 = 0xFF151517
/// Desktop `ui-theme` `base.css` `--dsw-alias-settings-card` fill.
public let dswAliasSettingsCardFillLightHex: UInt32 = 0xFFFFFFFF
public let dswAliasSettingsCardFillDarkHex: UInt32 = 0xFF2C2C2E

public func dswAliasBgBaseHex(dark: Bool) -> UInt32 {
    dark ? dswAliasBgBaseDarkHex : dswAliasBgBaseLightHex
}

public func dswAliasSettingsCardFillHex(dark: Bool) -> UInt32 {
    dark ? dswAliasSettingsCardFillDarkHex : dswAliasSettingsCardFillLightHex
}

public func dswHexRed(_ hex: UInt32) -> Int { Int((hex >> 16) & 0xFF) }
public func dswHexGreen(_ hex: UInt32) -> Int { Int((hex >> 8) & 0xFF) }
public func dswHexBlue(_ hex: UInt32) -> Int { Int(hex & 0xFF) }

public func settingsShellHeaderIdentifier() -> String { "settingsShellHeader" }
public func settingsNavCardIdentifier() -> String { "settingsNavCard" }
public func settingsNavRowIdentifier(_ id: String) -> String { "settingsNavRow.\(id)" }

public enum SettingsNavRowId: String, Sendable {
    case general
    case models
    case presets
    case plugins
}
