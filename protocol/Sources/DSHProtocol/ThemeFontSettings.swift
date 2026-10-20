import Foundation

/// Desktop `ui-theme` independently configurable font roles.
public enum ThemeFontRole: String, CaseIterable, Sendable {
    case text
    case code
    case terminal
}

/// Desktop `FONT_SIZE_SPECS`: integer px, inclusive range, role default.
public struct ThemeFontSizeSpec: Equatable, Sendable {
    public let min: Int
    public let max: Int
    public let `default`: Int

    public var range: ClosedRange<Int> { min...max }
}

/// Desktop `ui-theme` `FONT_SIZE_SPECS`.
public func themeFontSizeSpec(_ role: ThemeFontRole) -> ThemeFontSizeSpec {
    switch role {
    case .text: return ThemeFontSizeSpec(min: 10, max: 22, default: 14)
    case .code: return ThemeFontSizeSpec(min: 10, max: 16, default: 11)
    case .terminal: return ThemeFontSizeSpec(min: 10, max: 20, default: 13)
    }
}

/// Phone-local defaults are larger than desktop without changing its settings contract.
/// An absent key means "use the current default"; reads must never persist that default.
/// Existing keys were written only by explicit local edits, including edits to the old default.
public enum PhoneFontPreferences {
    public static func defaultSize(_ role: ThemeFontRole) -> Int {
        switch role {
        case .text: return 16
        case .code: return 13
        case .terminal: return 14
        }
    }

    public static func size(_ role: ThemeFontRole, defaults: UserDefaults = .standard) -> Int {
        let value = defaults.object(forKey: key(role)) as? Int ?? defaultSize(role)
        let range = themeFontSizeSpec(role).range
        return min(max(value, range.lowerBound), range.upperBound)
    }

    public static func setSize(_ value: Int, for role: ThemeFontRole, defaults: UserDefaults = .standard) {
        let range = themeFontSizeSpec(role).range
        defaults.set(min(max(value, range.lowerBound), range.upperBound), forKey: key(role))
    }

    private static func key(_ role: ThemeFontRole) -> String {
        switch role {
        case .text: return "dsh.fontSize"
        case .code: return "dsh.codeFontSize"
        case .terminal: return "dsh.terminalFontSize"
        }
    }
}

/// Desktop `FontSettingsGroup` expanded region, in render order.
/// Collapsed on every mount (`useState(false)`).
public enum ThemeFontExpandedRow: String, CaseIterable, Sendable {
    case textFamily
    case codeFamily
    case codeSize
    case terminalFamily
    case terminalSize
}

public let themeFontSettingsStartCollapsed = true
public let themeFontFamilyMaxLength = 200
public let themeFontSizeUnit = "px"

public func themeFontSizeCanIncrease(_ role: ThemeFontRole, value: Int) -> Bool {
    value < themeFontSizeSpec(role).max
}

public func themeFontSizeCanDecrease(_ role: ThemeFontRole, value: Int) -> Bool {
    value > themeFontSizeSpec(role).min
}

public func themeFontSizeStepped(_ role: ThemeFontRole, value: Int, delta: Int) -> Int {
    let spec = themeFontSizeSpec(role)
    return min(max(value + delta, spec.min), spec.max)
}

/// Desktop `settings.theme` `fontSize.{role}.title`.
public func themeFontSizeTitle(_ role: ThemeFontRole, english: Bool) -> String {
    switch role {
    case .text: return english ? "Font size" : "字号大小"
    case .code: return english ? "Code font size" : "代码字号"
    case .terminal: return english ? "Terminal font size" : "终端字号"
    }
}

/// Desktop `settings.theme` `fontSize.{role}.description`.
public func themeFontSizeDescription(_ role: ThemeFontRole, english: Bool) -> String {
    switch role {
    case .text: return english ? "Only affects conversation content" : "仅影响会话内容的字号"
    case .code: return english ? "Used for code blocks, inline code, and tool output" : "用于代码块、行内代码与工具输出"
    case .terminal: return english ? "Used for the sidebar terminal" : "用于侧栏终端"
    }
}

/// Desktop `settings.theme` `fontSize.{role}.increase` / `.decrease`.
public func themeFontSizeStepLabel(_ role: ThemeFontRole, increase: Bool, english: Bool) -> String {
    switch (role, increase, english) {
    case (.text, true, false): return "增大字号"
    case (.text, true, true): return "Increase font size"
    case (.text, false, false): return "减小字号"
    case (.text, false, true): return "Decrease font size"
    case (.code, true, false): return "增大代码字号"
    case (.code, true, true): return "Increase code font size"
    case (.code, false, false): return "减小代码字号"
    case (.code, false, true): return "Decrease code font size"
    case (.terminal, true, false): return "增大终端字号"
    case (.terminal, true, true): return "Increase terminal font size"
    case (.terminal, false, false): return "减小终端字号"
    case (.terminal, false, true): return "Decrease terminal font size"
    }
}

/// Desktop `settings.theme` `fontFamily.{role}.title`.
public func themeFontFamilyTitle(_ role: ThemeFontRole, english: Bool) -> String {
    switch role {
    case .text: return english ? "Text font" : "正文字体"
    case .code: return english ? "Code font" : "代码字体"
    case .terminal: return english ? "Terminal font" : "终端字体"
    }
}

/// Desktop `settings.theme` `fontFamily.{role}.description`.
public func themeFontFamilyDescription(_ role: ThemeFontRole, english: Bool) -> String {
    switch role {
    case .text:
        return english
            ? "Used for the interface and conversation text. Separate fonts with commas; leave empty for the default"
            : "用于界面与会话正文。多个字体用逗号分隔，留空使用默认字体"
    case .code:
        return english
            ? "Used for code blocks, inline code, and tool output. Separate fonts with commas; leave empty for the default"
            : "用于代码块、行内代码与工具输出。多个字体用逗号分隔，留空使用默认字体"
    case .terminal:
        return english
            ? "Used for the sidebar terminal. Separate fonts with commas; leave empty for the default"
            : "用于侧栏终端。多个字体用逗号分隔，留空使用默认字体"
    }
}

public func themeFontFamilyPlaceholder(english: Bool) -> String {
    english ? "Default" : "默认"
}

public func themeFontSettingsMoreLabel(english: Bool) -> String {
    english ? "More font settings" : "更多字体设置"
}

public func themeFontFamilyFieldTag(_ role: ThemeFontRole) -> String {
    switch role {
    case .text: return "textFontFamily"
    case .code: return "codeFontFamily"
    case .terminal: return "terminalFontFamily"
    }
}

public func themeFontFamilyDraft(_ raw: String) -> String {
    if raw.count <= themeFontFamilyMaxLength { return raw }
    return String(raw.prefix(themeFontFamilyMaxLength))
}
