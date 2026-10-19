import Foundation

/// Desktop `@deepseek-ai/dsh-client-ui-settings-general@0.2.1-alpha.5`
/// `SettingsRoot.module.css` (inlined in `lib/client.js` as `css$7`).
///
/// Phone settings root is a full-screen of the overlay **left nav** (not the
/// 800px two-pane dialog). Horizontal gutter stays the existing 16pt phone
/// inset; do not copy overlay `.nav` `12px` / `.options` `24px`.
///
/// Android `SettingsNavRow` (`48 / 15 / 18 / 12 / 16sp / 20`) is invented
/// touch chrome — desktop wins.

/// `.nav` `gap: 18px` — title cluster to first nav cell / phone card.
public let settingsNavGapPoints: Double = 18
/// `.navTitle` `font-size: 16px; font-weight: 500; line-height: 24px`.
public let settingsNavTitleFontSizePoints: Double = 16
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
/// `.navCell` `font-size: 14px; font-weight: 400; line-height: 22px`.
public let settingsNavCellFontSizePoints: Double = 14
public let settingsNavCellLineHeightPoints: Double = 22

/// Desktop `ui-theme` `base.css` `--dsw-radius-lg` (settings-card material).
/// Android `SettingsCard` uses `T.R16` citing this token. Overlay left nav is
/// not a card; phone wraps the list in the settings-card the way Android does.
public let dswRadiusLgPoints: Double = 16
public var settingsCardRadiusPoints: Double { dswRadiusLgPoints }
/// Desktop models `.rowCard` / iOS existing settings stroke: `.5px`.
public let settingsCardStrokeWidthPoints: Double = 0.5

public func settingsShellHeaderIdentifier() -> String { "settingsShellHeader" }
public func settingsNavCardIdentifier() -> String { "settingsNavCard" }
public func settingsNavRowIdentifier(_ id: String) -> String { "settingsNavRow.\(id)" }

public enum SettingsNavRowId: String, Sendable {
    case general
    case models
    case presets
    case plugins
}
