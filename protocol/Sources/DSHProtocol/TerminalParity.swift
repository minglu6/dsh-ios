import Foundation

/// Desktop `ui-sidebar-terminal` `TerminalBody` / `_UE8Aa_*` and
/// `ui-primitives` `Button.module.css` `.sm` / `.outline` / `.primary`.
/// Phone key-bar sizes come from Android `TerminalView.kt` `TerminalKey`.

public let terminalBodyFontSizePoints: Double = 13
public let terminalStatusGapPoints: Double = 8
public let terminalStatusPaddingXPoints: Double = 12
public let terminalStatusPaddingYPoints: Double = 5
public let terminalErrorPaddingXPoints: Double = 12
public let terminalErrorPaddingYPoints: Double = 10
public let terminalEmptyGapPoints: Double = 16
public let terminalEmptyPaddingPoints: Double = 24
public let terminalEmptyMessageMaxCh: Double = 28
public let terminalEmptyMessageLineHeight: Double = 1.6

public let dswButtonSmHeightPoints: Double = 28
public let dswButtonSmFontSizePoints: Double = 12
public let dswButtonSmLineHeightPoints: Double = 18
public let dswButtonSmHorizontalPaddingPoints: Double = 10
public let dswButtonRadiusSmPoints: Double = 6
public let dswButtonIconGapPoints: Double = 4
public let dswButtonMdHorizontalPaddingPoints: Double = 14

/// Desktop missing-terminal artwork: 36×36, `viewBox="0 0 28 28"`.
public let terminalMissingArtSizePoints: Double = 36
public let terminalMissingArtViewBox: Double = 28
public let terminalMissingArtFillHex: UInt32 = 0xFF17191D
public let terminalMissingArtStrokeHex: UInt32 = 0xFFFFFFFF
public let terminalMissingArtStrokeWidth: Double = 1.7
public let terminalMissingArtPromptPath = "m8 10 4 4-4 4M15 18h5"
public let terminalMissingArtRectX: Double = 3
public let terminalMissingArtRectY: Double = 5
public let terminalMissingArtRectWidth: Double = 22
public let terminalMissingArtRectHeight: Double = 19
public let terminalMissingArtRectRadius: Double = 3

/// Android `TerminalKey` icon `20.dp`, touch `heightIn(min = 48.dp)`.
public let terminalKeyGlyphSizePoints: Double = 20
public let terminalKeyMinHeightPoints: Double = 48

public let terminalMissingIdentityCode = "terminal/unavailable"

/// Android keys the attach effect on `online`; do not attach after an explicit exit.
public func terminalShouldAttachOnOnline(isOnline: Bool, exited: Bool) -> Bool {
    isOnline && !exited
}

/// Disconnect keeps `TerminalMeta` so the last screen stays a real `state.info`.
/// `closeTerminalFollow` after an explicit close must drop meta (main behavior).
public func terminalResetKeepsMeta(keepMeta: Bool) -> Bool {
    keepMeta
}

/// Header chip / key bar are live only while the attachment is still running.
public func terminalPanelIsRunning(
    isOnline: Bool,
    opening: Bool,
    terminating: Bool,
    exited: Bool,
    state: String?
) -> Bool {
    isOnline && !opening && !terminating && !exited && state == "running"
}

/// Desktop: reconnect when `state.info` exists, otherwise retry
/// (`client.terminal.js` 13353-13367). Disconnected uses reconnect.
public func terminalRetryLabel(hasScreenInfo: Bool, disconnected: Bool, english: Bool) -> String {
    if hasScreenInfo || disconnected {
        return english ? "Reconnect" : "重新连接"
    }
    return english ? "Retry" : "重试"
}

public func terminalDisconnectedCopy(english: Bool) -> String {
    english ? "Disconnected." : "连接已断开。"
}

public func terminalConnectingCopy(english: Bool) -> String {
    english ? "Connecting…" : "正在连接…"
}

public func terminalFailureCopy(message: String, english: Bool) -> String {
    english ? "Terminal error: \(message)" : "终端错误：\(message)"
}

public func terminalMissingCopy(english: Bool) -> String {
    english ? "This terminal no longer exists. Open a new terminal." : "此终端已不存在，请新建终端。"
}

public func terminalExitedCopy(code: String, english: Bool) -> String {
    english ? "Process exited (\(code))" : "进程已退出（\(code)）"
}

/// Keycaps stay English on every locale (Android `TerminalView.kt` 217-223).
public func terminalKeyPasteLabel(platform: String?) -> String {
    platform == "darwin" ? "Cmd+V" : "Ctrl+V"
}

public func terminalKeyCopyLabel(platform: String?) -> String {
    platform == "darwin" ? "Cmd+C" : "Copy"
}

/// Desktop `ui-sidebar-terminal` `TerminalTitle` (`client.js` TerminalTitle):
/// `state?.info?.title ?? state?.title ?? tab.title`. Create writes
/// `title: shell.name` (`api-terminal-controller` `index.js` spawn 997-1006).
/// Duplicate shells keep the same string — dockkit chips do not append an
/// index, cwd, or process. `cwd` / `shell` stay on `WebTerminalInfo` but are
/// not painted on the chip or the primitives `Menu` selected row.
///
/// Host never updates `info.title` after create from OSC 0/2, cwd, or the
/// foreground process. `BrowserTerminal.output` (`types/terminal.js` 228-235)
/// writes `@xterm/headless` only to serialize the screen, then broadcasts
/// `{type:output}`; it does not call `rename`. `consume` (208-226) patches
/// `state` / `exitCode` / `error` only. The sole post-create title mutation
/// is `rename(title)` (`types/terminal.js` 160-167, JSDoc “validated user
/// title”; controller `index.js` 898-901). Client `TerminalScreen`
/// (`client.terminal.js` 13425-13427) subscribes `xterm.onData` only —
/// bundled xterm OSC 0 `setTitle` / `onTitleChange` (3131, 3771-3772,
/// 12815-12816) is never wired to Host. `WebTerminalInfo.cwd` is “Initial
/// working directory; shell directory changes do not update this field”
/// (`types.d.ts` 46-47). There is no process field. Plugin `extra-ops.js`
/// exposes list/create/write/resize/close/follow (384-422), not
/// `terminal.rename` or a title event.
///
/// Two default zsh sessions therefore stay identical 「zsh」 on desktop
/// chips and Menu; only `.tabActive` / the Menu check distinguishes them.
/// iOS must not invent an OSC / cwd / process label. If Host later sends a
/// renamed `info.title` on `list` / `state` / `snapshot`, paint that string
/// (`AppModel.applyTerminalFrame`).
public let terminalTitleFollowsOscCwdOrProcess = false

public func terminalSwitcherTitle(title: String?, shellName: String?) -> String {
    let named = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !named.isEmpty { return named }
    return terminalTabTitle(shellName)
}

public func terminalSwitcherTitle(_ entry: TerminalSessionEntry) -> String {
    terminalSwitcherTitle(title: entry.title, shellName: entry.shellName)
}

/// Host `list()` returns Map insertion order (create order). Do not sort.
public func terminalSwitcherLabels(_ entries: [TerminalSessionEntry]) -> [String] {
    entries.map(terminalSwitcherTitle)
}

public func terminalSwitcherIsCurrent(
    entry: TerminalSessionEntry,
    currentSessionId: String?,
    currentId: String?
) -> Bool {
    currentSessionId == entry.sessionId && currentId == entry.id
}

/// Desktop close is `sidebarRight.registerCloseHandler` → `webTerminals.close`
/// with no Modal (`ui-sidebar-terminal` `client.js` apply). Tab chip close is
/// the same intent (`dockkit` `onCloseTab`).
public let terminalCloseAsksConfirmation = false

/// Title chevron opens a primitives `Menu` / `MenuSurface`, never UIKit Menu.
public let terminalSwitcherUsesSystemMenu = false

/// Desktop `ui-primitives` `Menu.module.css` `.list`.
public let terminalSwitcherMenuPaddingPoints: Double = 4
public let terminalSwitcherMenuMinWidthPoints: Double = 144
public let terminalSwitcherMenuMaxWidthPoints: Double = 360
/// `MenuSurface.module.css` `.surface` `--dsw-radius-lg` (same 12 as mention).
public let terminalSwitcherMenuRadiusPoints: Double = 12
/// `.item` `min-height: 34px; padding: 6px 8px; gap: 6px; font-size: 13px;
/// line-height: 20px; border-radius: var(--dsw-radius-md)`.
public let terminalSwitcherRowMinHeightPoints: Double = 34
public let terminalSwitcherRowPaddingYPoints: Double = 6
public let terminalSwitcherRowPaddingXPoints: Double = 8
public let terminalSwitcherRowGapPoints: Double = 6
public let terminalSwitcherRowFontSizePoints: Double = 13
public let terminalSwitcherRowLineHeightPoints: Double = 20
public let terminalSwitcherRowRadiusPoints: Double = 12
/// `.label` `padding: 6px 8px; font-size: 11px; line-height: 15px`.
public let terminalSwitcherSectionFontSizePoints: Double = 11
public let terminalSwitcherSectionLineHeightPoints: Double = 15
public let terminalSwitcherSectionPaddingYPoints: Double = 6
public let terminalSwitcherSectionPaddingXPoints: Double = 8
/// `.separator` `height: 0.5px; margin: 3px 2px`.
public let terminalSwitcherSeparatorHeightPoints: Double = 0.5
public let terminalSwitcherSeparatorMarginYPoints: Double = 3
public let terminalSwitcherSeparatorMarginXPoints: Double = 2
/// `.footer` `margin-top: 3px; padding-top: 3px`.
public let terminalSwitcherFooterGapPoints: Double = 3
/// `.itemIcon` / `.check` 14×14. Tab chip `TerminalIcon` is 16; the switcher
/// is a Menu, so the row uses the Menu icon size.
public let terminalSwitcherIconSizePoints: Double = 14
/// `ui-sidebar-terminal` `TerminalIcon` `width/height` 16, `viewBox 0 0 16 16`.
public let terminalTabIconSizePoints: Double = 16
public let terminalTabIconPromptPath = "M3 4L7 8L3 12"
public let terminalTabIconCursorPath = "M9 12H13"

public func terminalSwitcherMenuIdentifier() -> String { "terminalSwitcherMenu" }
public func terminalSwitcherButtonIdentifier() -> String { "terminalSwitcherButton" }
public func terminalSwitcherRowIdentifier(id: String) -> String { "terminalSwitcher.row.\(id)" }
public func terminalTabIconSymbol() -> String { "official.terminalTab" }

public func isForbiddenTerminalSwitcherSystemSymbol(_ name: String) -> Bool {
    name == "terminal" || name == "checkmark" || name == "plus" || name == "xmark"
}

public func terminalGridIsBlank(_ grid: TerminalGrid) -> Bool {
    for r in 0..<grid.rows {
        var c = 0
        while c < grid.cols {
            let cell = grid.cell(r, c)
            if cell.spacer {
                c += 1
                continue
            }
            if cell.ch != " ", !cell.ch.isEmpty { return false }
            c += cell.wide ? 2 : 1
        }
    }
    return true
}
