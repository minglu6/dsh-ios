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
    english ? "This terminal no longer exists. Create a new one." : "此终端已不存在，请新建终端。"
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
