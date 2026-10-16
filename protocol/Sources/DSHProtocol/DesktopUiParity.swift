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
    case "sidebar": return english ? "In-App Sidebar" : "应用内侧边栏"
    case "new-tab": return english ? "Default Browser" : "默认浏览器"
    default:
        return value
    }
}

public let linkOpeningValues = ["sidebar", "new-tab"]

public func linkOpeningTitle(english: Bool) -> String {
    english ? "Open chat links in" : "网页链接默认打开方式"
}

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
    english ? "Choose where to open web links" : "对话中网页链接的打开位置"
}

public func composerPlaceholderText(planMode: Bool, english: Bool, hero: Bool = false) -> String {
    if planMode {
        return english ? "describe your task to generate plan" : "描述你的任务以生成计划"
    }
    if hero {
        return english
            ? "Describe what you want to build, / commands, @ files or sessions"
            : "描述你想要构建的内容, / 调用指令, @ 文件或对话"
    }
    return english
        ? "Message or run a task, / commands, @ files or sessions"
        : "发消息或创建任务, / 调用指令, @ 文件或对话"
}

/// Desktop `conversation` `hero.headline`.
public func landingHeadline(english: Bool) -> String {
    english ? "Into the Unknown" : "探索未至之境"
}

/// Desktop `conversation` `hero.preview`.
public func landingPreviewBadge(english: Bool) -> String {
    english ? "Preview" : "预览版"
}

/// Space above the composer (already keyboard-avoided) minus a hairline margin.
/// Never invent a floor taller than the remaining viewport — that is what
/// squeezed the slash list into a 3-page scroller under the iOS keyboard.
public func commandMenuAvailableHeight(containerHeight: Double, margin: Double = 8) -> Double {
    max(0, containerHeight - margin)
}

public func composerModelFallback(english: Bool) -> String {
    english ? "Select model" : "请选择模型"
}

public func loadOlderLabel(loading: Bool, english: Bool) -> String {
    if loading { return english ? "Loading…" : "加载中…" }
    return english ? "Load earlier" : "加载更早"
}

public func formatRunDuration(elapsedMs: Int64, english: Bool) -> String {
    let total = max(0, elapsedMs / 1000)
    let hours = total / 3600
    let minutes = (total / 60) % 60
    let seconds = total % 60
    if english {
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h ") }
        if total >= 60 { parts.append("\(minutes)m ") }
        parts.append("\(seconds)s")
        return parts.joined()
    }
    var parts: [String] = []
    if hours > 0 { parts.append("\(hours)小时") }
    if total >= 60 { parts.append("\(minutes)分") }
    parts.append("\(seconds)秒")
    return parts.joined()
}

public func deepDivingLabel(startedAtMs: Int64?, nowMs: Int64, english: Bool) -> String {
    guard let startedAtMs else {
        return english ? "Deep diving" : "深度求索中"
    }
    let duration = formatRunDuration(elapsedMs: max(1000, nowMs - startedAtMs), english: english)
    return english
        ? "Deep diving for \(duration) ···"
        : "深度求索中，用时 \(duration) ···"
}

public func jobOutputGap(english: Bool) -> String {
    english ? "… earlier output dropped …" : "……较早的输出已丢弃……"
}

public func askRowTitle(english: Bool) -> String {
    english ? "Ask question" : "提问"
}

public func askReopenLabel(english: Bool) -> String {
    english ? "Answer" : "回答"
}

public func askPendingDetail(english: Bool) -> String {
    english
        ? "These pending questions remain answerable from the composer."
        : "等待中的问题仍可在输入框中回答"
}

public func planChipTitle(english: Bool) -> String {
    english
        ? "Plan mode on — click to turn off (/plan off)"
        : "计划模式已开启 — 点击关闭（/plan off）"
}

public func pendingAttachmentsLabel(english: Bool) -> String {
    english ? "Pending attachments" : "待发送附件"
}

public func pluginsEmptyLabel(english: Bool) -> String {
    english ? "No plugins are installed yet." : "还没有安装任何插件。"
}

public func messageFeedbackHint(english: Bool) -> String {
    english
        ? "Add details to help us improve. Your submission will include the current conversation log."
        : "填写详情以帮助我们改进体验，提交内容会包括当前对话的日志"
}

public func commandAttachmentsUnsupportedNotice(command: String, english: Bool) -> String {
    english
        ? "/\(command) does not accept attachments; remove them first"
        : "/\(command) 不接受附件，请先移除附件"
}

public func slashCommandName(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("/") else { return nil }
    let token = trimmed.dropFirst().split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    return token.isEmpty ? nil : token
}

/// Desktop `ui-commands`: only a Host command that declares `input.attachments` may submit with files.
public func commandRefusesAttachments(name: String, catalogRow: JSONValue?) -> Bool {
    if let catalogRow, catalogRow["name"].str() == name {
        return catalogRow["input"]["attachments"].bool() != true
    }
    switch name {
    case "file": return false
    case "goal", "plan", "feedback", "compact", "permission", "model", "export":
        return true
    default:
        return false
    }
}

/// Desktop terminal tab title: shell name only, never a truncated id.
public func terminalTabTitle(_ title: String?) -> String {
    let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? "Terminal" : trimmed
}

/// Desktop slash-menu glyphs, mapped to SF Symbols on iOS.
public func autoRefreshLabel(english: Bool) -> String {
    english ? "Auto refresh" : "自动刷新"
}

public func autoRefreshEnableLabel(english: Bool) -> String {
    english ? "Enable auto refresh" : "开启自动刷新"
}

public func autoRefreshDisableLabel(english: Bool) -> String {
    english ? "Disable auto refresh" : "关闭自动刷新"
}

public func queueImageLabel(english: Bool) -> String {
    english ? "Queued message image" : "排队消息图片"
}

public func queueFileLabel(name: String, english: Bool) -> String {
    english ? "Queued file \(name)" : "排队文件 \(name)"
}

/// Desktop `fileSizeText`: 1024-based, one fractional digit after 1 KiB.
public func fileSizeText(_ bytes: Int) -> String {
    let value = Double(max(0, bytes))
    if value < 1024 { return "\(max(0, bytes)) B" }
    let units = ["KB", "MB", "GB", "TB"]
    var size = value / 1024
    var unit = 0
    while size >= 1024 && unit < units.count - 1 {
        size /= 1024
        unit += 1
    }
    let rounded = (size * 10).rounded() / 10
    if rounded == rounded.rounded() {
        return "\(Int(rounded)) \(units[unit])"
    }
    return String(format: "%.1f \(units[unit])", rounded)
}

/// Desktop InputBar claimed-command hint: blank args after `/goal` or `/plan`.
public func claimedComposerHint(text: String, catalog: [JSONValue] = [], hasGoal: Bool, english: Bool) -> String? {
    guard let token = slashCommandName(text) else { return nil }
    let afterSlash = text.trimmingCharacters(in: .whitespacesAndNewlines).dropFirst()
    let rest = afterSlash.drop(while: { !$0.isWhitespace }).trimmingCharacters(in: .whitespacesAndNewlines)
    guard rest.isEmpty else { return nil }
    let row = catalog.first { $0["name"].str() == token }
    let name = builtinCommandName(row?["definitionId"].str()) ?? token
    switch name {
    case "goal":
        if hasGoal {
            return english
                ? "goal active — edit / pause / resume / clear"
                : "当前目标进行中。可输入 edit 修改 / pause 暂停 / resume 继续 / clear 清除"
        }
        return english
            ? "describe the objective for a long-running task"
            : "输入目标，智能体将持续执行"
    case "plan":
        return composerPlaceholderText(planMode: true, english: english)
    default:
        return row?["input"]["hint"].str()
    }
}

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
