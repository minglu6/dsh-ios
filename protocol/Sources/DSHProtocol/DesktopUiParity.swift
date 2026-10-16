import Foundation

/// Desktop chat `MessageIconActions` as captured on the Chinese locale main thread.
/// Branch is a session-level ⋯ action, not a message-row icon.
public enum MessageActionKind: String, Equatable, CaseIterable, Sendable {
    case copy
    case like
    case dislike
    case share
}

public enum MessageActionPolicy {
    public static var assistantRow: [MessageActionKind] { [.copy, .like, .dislike, .share] }
    public static var userRow: [MessageActionKind] { [.copy] }
    public static var includesBranch: Bool { false }
}

/// Desktop right-hand Start / Guide body: workspace files + new terminal only.
public enum StartPanelEntry: String, Equatable, Hashable, Sendable {
    case workspaceFiles
    case newTerminal
}

public enum StartPanelPolicy {
    public static func entries(files: Bool, terminal: Bool) -> [StartPanelEntry] {
        var result: [StartPanelEntry] = []
        if files { result.append(.workspaceFiles) }
        if terminal { result.append(.newTerminal) }
        return result
    }

    public static var includesBrowser: Bool { false }
    public static var includesSessionInspector: Bool { false }

    /// Desktop Start labels still use these; the phone controller must not render them.
    public static func desktopShortcut(_ entry: StartPanelEntry) -> String? {
        switch entry {
        case .workspaceFiles: return "⌘P"
        case .newTerminal: return nil
        }
    }

    /// Touch Start rows never append desktop chords (⌘P / ⌥⌘P / ^`).
    public static func shortcut(_: StartPanelEntry) -> String? { nil }

    public static func showsChevron(_ entry: StartPanelEntry) -> Bool {
        entry == .newTerminal
    }
}

/// Composer shows a concrete model name. "选择模型" is a prompt, not a model.
public func composerModelDisplayName(choiceName: String?, catalog: ModelCatalog?) -> String? {
    if let name = choiceName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
        return name
    }
    guard let catalog else { return nil }
    if let info = catalog.find(provider: catalog.defaultProvider, model: catalog.defaultModel) {
        return info.name
    }
    if let id = catalog.defaultModel?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
        return id
    }
    return nil
}

/// Desktop conversation header has no session ⋯ overflow. Export / feedback live
/// on `/` and `+`. Rename / fork stay on the session row menu.
public enum ConversationHeaderPolicy {
    public static var includesOverflowMenu: Bool { false }
}

/// Same title as the workspace row: the current blank session is 新会话,
/// every other missing title is 未命名 / Untitled.
public func conversationHeaderTitle(
    sessionId: String?,
    title: String?,
    blank: Bool,
    newSession: String,
    untitled: String
) -> String {
    guard let sessionId else { return newSession }
    return drawerSessionTitle(
        SessionSummary(sessionId: sessionId, title: title, blank: blank),
        current: sessionId,
        newSession: newSession,
        untitled: untitled
    )
}

public enum ConversationFontSize {
    public static let min = 10
    public static let max = 22
    public static var range: ClosedRange<Int> { min...max }
}

public func conversationFontSizeLabel(_ size: Int) -> String {
    "\(size) px"
}

public func pairingCodeFieldLabel(english: Bool) -> String {
    english ? "Verification code" : "验证码"
}

public func downloadSessionLogLabel(english: Bool) -> String {
    english ? "Download session log" : "下载会话日志"
}

public func sessionLogUploadLabel(english: Bool) -> String {
    english
        ? "Upload session log when using the official model API"
        : "在使用官方模型 API 时上传会话日志"
}

/// Official `ui-settings-models` locales.ts (`deepseek-ai/deepseek-harness`).
public func modelsSettingsIntro(english: Bool) -> String {
    english
        ? "Enter your API keys to use models from the following providers."
        : "填入各提供商的 API 密钥即可使用其模型。"
}

/// Desktop `ui-settings` / `ui-chat` locales for General.
public func transcriptViewLabel(_ mode: TranscriptView, english: Bool) -> String {
    switch mode {
    case .compact: return english ? "Compact" : "简洁"
    case .standard: return english ? "Standard" : "标准"
    case .detailed: return english ? "Detailed" : "详细"
    case .verbose: return english ? "Verbose" : "完全展开"
    }
}

public func collapseTimingLabel(_ mode: CollapseTiming, english: Bool) -> String {
    switch mode {
    case .completion: return english ? "On completion" : "回答结束后"
    case .nextInput: return english ? "On next message" : "下次有新消息时"
    }
}

public func performanceUsageLabel(detailed: Bool, english: Bool) -> String {
    if detailed { return english ? "Detailed" : "详细" }
    return english ? "Compact" : "简洁"
}

public func linkOpeningLabel(_ value: String, english: Bool) -> String {
    switch value {
    case "sidebar": return english ? "Sidebar" : "侧栏"
    case "in-app": return english ? "In-app" : "应用内"
    case "system": return english ? "System browser" : "系统浏览器"
    default:
        preconditionFailure("unlocalized linkOpening value: \(value)")
    }
}

public let linkOpeningValues = ["sidebar", "in-app", "system"]

public func workDetailsDescription(english: Bool) -> String {
    english ? "Choose how much detail to show for tool calls" : "选择希望看到多少工具调用细节"
}

public func collapseTimingDescription(english: Bool) -> String {
    english ? "Choose when to automatically collapse work details" : "选择何时自动收起工作步骤"
}

public func permissionDefaultDescription(english: Bool) -> String {
    english ? "Choose the default permission mode for new sessions" : "选择新会话的默认权限模式"
}

public func performanceUsageDescription(english: Bool) -> String {
    english
        ? "Choose how much performance and usage information to show"
        : "选择性能与用量信息展示的详细程度"
}

public func busySendDescription(english: Bool) -> String {
    english
        ? "What Enter and the Send button do while the agent is running; Cmd/Ctrl+Enter uses the other behavior"
        : "智能体运行时 Enter 键和发送按钮的行为；Cmd/Ctrl+Enter 使用另一行为"
}

public func linkOpeningDescription(english: Bool) -> String {
    english ? "Choose where links open" : "选择在哪里打开链接"
}

/// Desktop terminal tab title: shell name only, never a truncated id.
public func terminalTabTitle(_ title: String?) -> String {
    let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? "Terminal" : trimmed
}

/// Desktop slash-menu glyphs, mapped to SF Symbols on iOS.
public func commandMenuIconSymbol(_ kind: String?) -> String {
    switch kind {
    case "file": return "paperclip"
    case "model": return "cylinder.split.1x2"
    case "goal": return "target"
    case "plan": return "doc.text"
    case "feedback": return "paperplane"
    case "compact": return "circle.circle"
    case "permission": return "shield"
    case "export": return "square.and.arrow.down"
    default: return "chevron.left.forwardslash.chevron.right"
    }
}
