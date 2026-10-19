import Foundation

/// Desktop `ui-chat` `MessageIconActions`: copy → extraActions (like / dislike
/// from `ui-message-feedback`) → branch → usage → clock. User rows omit
/// `onBranch`. There is no share control — desktop extraActions is only the
/// feedback pair; Android `MessageActions` matches. Session-row fork remains
/// (`ui-workspace` `menu.fork`) for last-completed-turn branching without a seq.
public enum MessageActionKind: String, Equatable, CaseIterable, Sendable {
    case copy
    case like
    case dislike
    case branch
}

public enum MessageActionPolicy {
    public static var assistantRow: [MessageActionKind] { [.copy, .like, .dislike, .branch] }
    /// Desktop `UserMessageNodeView` has no persistent copy control; mobile
    /// only shows the start clock. Phone must not render a standalone copy
    /// icon under the user bubble.
    public static var userRow: [MessageActionKind] { [] }
    public static var includesBranch: Bool { true }
    public static var includesShare: Bool { false }
}

/// User bubbles never grow a permanent copy button (desktop has none).
public let userMessageShowsPersistentCopy = false

/// Desktop `ui-chat` `ChatView.module.css` `.column` `--dsh-chat-content-width`
/// default in `UserMessageNodeView` / `MessageItem.module.css` `.userStack`.
public let chatContentWidthPoints: Double = 748

/// Desktop `MessageItem.module.css` `.userStack`
/// `max-width: min(calc(var(--dsh-chat-content-width,748px) * .702), 82%)`.
public let userMessageStackMaxWidthFactor: Double = 0.702
public let userMessageStackMaxWidthFraction: Double = 0.82

public var userMessageStackAbsoluteMaxWidthPoints: Double {
    chatContentWidthPoints * userMessageStackMaxWidthFactor
}

public func userMessageStackMaxWidth(columnWidth: Double) -> Double {
    min(userMessageStackAbsoluteMaxWidthPoints, columnWidth * userMessageStackMaxWidthFraction)
}

/// Desktop `MessageItem.module.css` `.bubble` `padding: 10px 16px`.
public let userMessageBubblePaddingVerticalPoints: Double = 10
public let userMessageBubblePaddingHorizontalPoints: Double = 16

/// Desktop `MessageItem.module.css` `.bubble` `border-radius: var(--dsw-radius-xl)`.
public var userMessageBubbleRadiusPoints: Double { dswRadiusXlPoints }

/// Desktop `MessageItem.module.css` `.userRow` `align-items: flex-end; gap: 6px`.
public let userMessageRowGapPoints: Double = 6
public let userMessageBubbleAlignsTrailing = true

/// Desktop `MessageItem.module.css` `.userStack` `gap: 8px`.
public let userMessageStackGapPoints: Double = 8

/// Desktop `user-text.module.css` runs flow start-aligned inside the hugging bubble.
public let userMessageBubbleTextAlignsLeading = true

public func userMessageBubbleIdentifier() -> String { "userMessageBubble" }

/// Desktop `TurnTailNodeView` branch control. `onBranch` is omitted when
/// `session/fork` / `sessions.fork` is not allowed. The icon stays visible but
/// inert when the turn has no closing `endSeq` (desktop `branchUnavailable`,
/// Android `missingTurnBoundaryCannotFallBackToForkingLatestTurn`).
public struct MessageBranchChrome: Equatable, Sendable {
    public var atSeq: Int64?
    public var unavailable: Bool

    public var enabled: Bool { !unavailable && atSeq != nil }

    public init(atSeq: Int64?, unavailable: Bool) {
        self.atSeq = atSeq
        self.unavailable = unavailable
    }
}

public func messageBranchChrome(canFork: Bool, turnEndSeq: Int64?) -> MessageBranchChrome? {
    guard canFork else { return nil }
    return MessageBranchChrome(atSeq: turnEndSeq, unavailable: turnEndSeq == nil)
}

/// Desktop `message.branch` / `message.branchUnavailable`.
public func messageBranchLabel(unavailable: Bool, english: Bool) -> String {
    if unavailable {
        return english
            ? "Available only on the last message of a completed turn"
            : "仅可从已完成轮次的最后一条消息分支"
    }
    return english ? "Branch into a new conversation" : "在新对话中分支"
}

/// Desktop `ISessions.fork({ increaseTitle: true })` (`dsh-client-runtime`
/// `increasedForkTitle`). Both the session-row menu and `TurnTailNodeView`
/// `forkAt` pass this flag. The Host fork request still has only `sessionId`
/// and optional `atSeq`; the client renames the **child** from the source
/// session's persisted list title. Missing title skips rename.
public func forkChildTitle(sourcePersistedTitle: String?) -> String? {
    guard let sourcePersistedTitle else { return nil }
    return increasedForkTitle(sourcePersistedTitle)
}

/// Increment a trailing fork number while preserving half-width or full-width
/// parentheses; an unnumbered title starts with ` (1)`.
/// Desktop: `/^(.*?)\((\d+)\)$/u` then `/^(.*?)（(\d+)）$/u`, else `` `${title} (1)` ``.
public func increasedForkTitle(_ title: String) -> String {
    if let next = incrementTrailingParentheticalCount(title, open: "(", close: ")") {
        return next
    }
    if let next = incrementTrailingParentheticalCount(title, open: "（", close: "）") {
        return next
    }
    return "\(title) (1)"
}

private func incrementTrailingParentheticalCount(_ title: String, open: Character, close: Character) -> String? {
    guard title.last == close else { return nil }
    let body = title.dropLast()
    guard let openIndex = body.lastIndex(of: open) else { return nil }
    let digits = body[body.index(after: openIndex)...]
    guard !digits.isEmpty, digits.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
    let prefix = String(body[..<openIndex])
    return "\(prefix)\(open)\(incrementDecimalDigits(String(digits)))\(close)"
}

/// Desktop `BigInt(digits) + 1n` stringified — leading zeros do not survive.
private func incrementDecimalDigits(_ digits: String) -> String {
    let significant = digits.drop(while: { $0 == "0" })
    var chars = Array(significant.isEmpty ? "0" : String(significant))
    var index = chars.count - 1
    var carry = 1
    while index >= 0 && carry > 0 {
        guard let current = chars[index].wholeNumberValue, current <= 9 else {
            fatalError("increasedForkTitle: non-decimal digit")
        }
        let sum = current + carry
        chars[index] = Character(String(sum % 10))
        carry = sum / 10
        index -= 1
    }
    if carry > 0 { return "1" + String(chars) }
    return String(chars)
}

/// Desktop right-hand Start / Guide cards from `ui-sidebar-files` /
/// `ui-sidebar-terminal` / `ui-sidebar-browser` (`order` 10 / 20 / 30), plus
/// optional `@deepseek-ai/dsh-experimental-session-inspector@0.2.1-alpha.5`
/// (`session-inspector-log` guide order 60). Desktop shows it as an
/// optional-bundle Guide card; `ui-sidebar-right` `guide()` does not filter
/// by session (locale: 会话数据诊断 / Session diagnostics).
public enum StartPanelEntry: String, Equatable, Hashable, Sendable {
    case workspaceFiles
    case newTerminal
    case browser
    case sessionInspector
}

public enum StartPanelPolicy {
    public static func entries(files: Bool, terminal: Bool, browser: Bool = true, inspector: Bool = true) -> [StartPanelEntry] {
        var result: [StartPanelEntry] = []
        if files { result.append(.workspaceFiles) }
        if terminal { result.append(.newTerminal) }
        if browser { result.append(.browser) }
        if inspector { result.append(.sessionInspector) }
        return result
    }

    public static var includesBrowser: Bool { true }
    public static var includesSessionInspector: Bool { true }
    public static var desktopGuideIncludesSessionInspector: Bool {
        DesktopSidebarInventory.desktopGuideIncludesSessionInspector
    }

    /// Desktop Start labels still use these; the phone controller must not render them.
    public static func desktopShortcut(_ entry: StartPanelEntry) -> String? {
        switch entry {
        case .workspaceFiles: return "⌘P"
        case .newTerminal: return nil
        case .browser: return nil
        case .sessionInspector: return nil
        }
    }

    /// Touch Start rows never append desktop chords (⌘P / ⌥⌘P / ^`).
    public static func shortcut(_: StartPanelEntry) -> String? { nil }

    public static func showsChevron(_ entry: StartPanelEntry) -> Bool {
        entry == .newTerminal
    }

    /// Desktop Guide is the right-sidebar default page, never a grabber sheet.
    public static var usesSystemSheet: Bool { false }
    /// Desktop Guide cards have no ornamental globe above the list.
    public static var hasDecorativeGlobe: Bool { false }
}

/// Phone Start / Browser / Inspector follow desktop header-menu / sidebar
/// chrome: a full-screen page (or full-height sidebar panel) with a back
/// control. Never a system sheet with a grabber.
public enum HostSurfacePresentation {
    public static var startUsesSystemSheet: Bool { false }
    public static var browserUsesSystemSheet: Bool { false }
    public static var inspectorUsesSystemSheet: Bool { false }
    public static var settingsPermissionUsesSystemSheet: Bool { false }
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

/// Host titles a session asynchronously after the first turn. Android
/// `refreshTitles` reloads `sessions.list` on status, then again 4s after stop.
public let sessionTitleRefreshDelayNanoseconds: UInt64 = 4_000_000_000

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
    public static var min: Int { themeFontSizeSpec(.text).min }
    public static var max: Int { themeFontSizeSpec(.text).max }
    public static var range: ClosedRange<Int> { themeFontSizeSpec(.text).range }
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

/// Desktop `conversation` placeholder keys, including Cmd/Ctrl+Enter hints.
public enum ComposerPlaceholderKind: String, Equatable, Sendable {
    case parentOffline
    case unavailable
    case workspace
    case steerQueue
    case plan
    case hero
    case defaultMessage
}

/// Desktop InputBar order: parentOffline → unavailable → workspace (inert hero)
/// → steerQueue → plan → hero/default.
public func composerPlaceholderKind(
    parentOffline: Bool,
    unavailable: Bool,
    canSteerQueue: Bool,
    planMode: Bool,
    needsWorkspace: Bool,
    hero: Bool
) -> ComposerPlaceholderKind {
    if parentOffline { return .parentOffline }
    if unavailable { return .unavailable }
    if needsWorkspace { return .workspace }
    if canSteerQueue { return .steerQueue }
    if planMode { return .plan }
    if hero { return .hero }
    return .defaultMessage
}

public func composerPlaceholderText(kind: ComposerPlaceholderKind, english: Bool) -> String {
    switch kind {
    case .parentOffline:
        return english
            ? "Parent session offline; sending is unavailable but you can still stop the run"
            : "父会话已离线，无法继续发送；仍可停止当前运行"
    case .unavailable:
        return english ? "Session unavailable" : "会话不可用"
    case .workspace:
        return composerWorkspacePlaceholder(english: english)
    case .steerQueue:
        return english
            ? "Cmd/Ctrl+Enter steers all queued messages"
            : "Cmd/Ctrl+Enter 插话发送全部排队消息"
    case .plan:
        return english ? "describe your task to generate plan" : "描述你的任务以生成计划"
    case .hero:
        return english
            ? "Describe what you want to build, / commands, @ files or sessions"
            : "描述你想要构建的内容, / 调用指令, @ 文件或对话"
    case .defaultMessage:
        return english
            ? "Message or run a task, / commands, @ files or sessions"
            : "发消息或创建任务, / 调用指令, @ 文件或对话"
    }
}

public func composerPlaceholderText(planMode: Bool, english: Bool, hero: Bool = false, needsWorkspace: Bool = false) -> String {
    composerPlaceholderText(
        kind: composerPlaceholderKind(
            parentOffline: false,
            unavailable: false,
            canSteerQueue: false,
            planMode: planMode,
            needsWorkspace: needsWorkspace,
            hero: hero
        ),
        english: english
    )
}

/// Desktop `conversation` `placeholder.workspace` when the hero chip has no title.
public func composerWorkspacePlaceholder(english: Bool) -> String {
    english ? "Choose a workspace to start" : "选择一个工作区开始"
}

/// Desktop `ui-workspace` `draft.workspaceRequired`.
public func landingWorkspaceRequired(english: Bool) -> String {
    english ? "Choose a workspace first." : "请先选择工作区"
}

/// Desktop hero composer is inert until the workspace chip has a title.
public func landingComposerNeedsWorkspace(selectedWorkspaceId: String?, workspaceCount: Int) -> Bool {
    selectedWorkspaceId == nil && workspaceCount == 0
}

/// Desktop `conversation` `input.stop`.
public func composerStopLabel(english: Bool) -> String {
    english ? "Stop generating" : "停止生成"
}

/// Desktop `ui-conversation` `resolveSubmitMode`.
public enum ComposerSubmitGesture: String, Equatable, Sendable {
    case enter
    case chord
}

public func resolveSubmitMode(
    preferred: String,
    running: Bool,
    gesture: ComposerSubmitGesture,
    steeringAvailable: Bool
) -> String {
    if !running || !steeringAvailable { return "queue" }
    if gesture == .enter { return preferred }
    return preferred == "queue" ? "steer" : "queue"
}

/// Desktop `conversation` `hero.chooseWorkspace`.
public func landingChooseWorkspace(english: Bool) -> String {
    english ? "Choose workspace" : "选择工作区"
}

/// Desktop `ui-plugin-manager` `infoLabel` / `infoDescription`.
public func pluginInfoLabel(english: Bool) -> String {
    english ? "About plugins" : "插件说明"
}

public func pluginInfoDescription(english: Bool) -> String {
    english
        ? "Configure official plugins and install or manage other plugins here. View the built-in plugin list and runtime status in Settings → Built-in plugins."
        : "在这里配置官方插件，安装和管理其他插件。内置插件列表及运行状态可在「设置 → 内置插件」中查看"
}

/// Desktop `ui-primitives` `Tooltip.module.css`: floating bubble, not a
/// system popover / alert / sheet. `--dsw-alias-tooltip-bg` +
/// `--dsw-static-neutral-bluish-00` text, `--dsw-radius-sm` 6px,
/// 13/20 type, `.bubble` `padding: 3px 7px`; PluginManagerPage passes
/// `maxWidth: 300`, `side: "bottom"`, default `gap = 8`, `openOnClick`.
public let pluginInfoTooltipGapPoints: Double = 8
public let pluginInfoTooltipUsesSystemPopover = false
public let pluginInfoTooltipMaxWidthPoints: Double = 300
public let pluginInfoTooltipFontSizePoints: Double = 13
public let pluginInfoTooltipLineHeightPoints: Double = 20
public let pluginInfoTooltipRadiusPoints: Double = 6
public let pluginInfoTooltipPaddingHorizontalPoints: Double = 7
public let pluginInfoTooltipPaddingVerticalPoints: Double = 3
public let pluginInfoTooltipScreenInsetPoints: Double = 16
public let pluginInfoTooltipTextHex: UInt32 = 0xFFFFFFFF
/// Desktop `PluginManagerPage` toolbar `IconInfoOutlineRegular` size 11.
public let pluginInfoIconSizePoints: Double = 11
/// Desktop `IconInfoOutlineArtwork` 14×14 view box.
public let pluginInfoIconViewBox: Double = 14
public let pluginInfoOutlineRingPath =
    "M12.5757 7.00012C12.5757 3.92085 10.0794 1.42463 7.00012 1.42456C3.9208 1.42456 1.42456 3.9208 1.42456 7.00012C1.42463 10.0794 3.92085 12.5757 7.00012 12.5757C10.0793 12.5756 12.5756 10.0793 12.5757 7.00012ZM13.8002 7.00012C13.8001 10.7559 10.7559 13.8001 7.00012 13.8002C3.2443 13.8002 0.199291 10.7559 0.199219 7.00012C0.199219 3.24426 3.24426 0.199219 7.00012 0.199219C10.7559 0.199291 13.8002 3.2443 13.8002 7.00012Z"
public let pluginInfoOutlineDotPath = "M7.6127 3.18921V4.55986H6.38735V3.18921H7.6127Z"
public let pluginInfoOutlineStemPath = "M7.6127 5.68921V10.8109H6.38735V5.68921H7.6127Z"

/// Desktop `IconRefreshOutlineArtwork` Regular, 16×16.
public let pluginRefreshOutlineArcPath =
    "M14.5001 8C14.5 9.28552 14.1188 10.5422 13.4045 11.611C12.6903 12.6799 11.6752 13.5129 10.4875 14.0049C9.29982 14.4968 7.99295 14.6255 6.73212 14.3747C5.4713 14.124 4.31314 13.505 3.4041 12.596C2.49514 11.687 1.87614 10.5288 1.62537 9.26798C1.37459 8.00716 1.50331 6.70028 1.99525 5.51261C2.48719 4.32494 3.32025 3.30981 4.3891 2.59557C5.45795 1.88134 6.71458 1.50008 8.0001 1.5C9.9001 1.5 11.7001 2.3 13.0001 3.6L14.5001 5.1"
public let pluginRefreshOutlineHeadPath = "M14.4999 1.5V5.1H10.8999"

/// Desktop `ui-primitives` `IconTrashOutlineArtwork` Regular, 16×16,
/// `ICON_REGULAR_STROKE` 1. Android `dsh_trash.xml` is the same path set.
public let iconTrashOutlineLidPath = "M1.28149 3.88831H14.7187"
public let iconTrashOutlineHandlePath =
    "M5.41602 3.88833V2.47962C5.41602 2.29282 5.52492 2.11366 5.71876 1.98157C5.9126 1.84948 6.17551 1.77527 6.44964 1.77527H9.55053C9.82466 1.77527 10.0876 1.84948 10.2814 1.98157C10.4753 2.11366 10.5842 2.29282 10.5842 2.47962V3.88833"
public let iconTrashOutlineBodyPath =
    "M2.57349 3.88831L3.19366 13.2943C3.21937 13.5502 3.33952 13.7872 3.53065 13.9593C3.72178 14.1313 3.97016 14.2259 4.22729 14.2246H11.7728C12.0299 14.2259 12.2783 14.1313 12.4694 13.9593C12.6605 13.7872 12.7807 13.5502 12.8064 13.2943L13.4266 3.88831"
public let iconTrashOutlineLeftRibPath = "M6.44946 6.98926V11.1238"
public let iconTrashOutlineRightRibPath = "M9.55054 6.98926V11.1238"

/// Desktop `IconDataOutlineArtwork` Medium (`ICON_MEDIUM_STROKE` 1.3). Android
/// settings shell models row is `D.dataMedium`. Fill is the cylinder; stroke
/// is the overlay gear (`stroke-miterlimit: 10`).
public func settingsModelsSymbol() -> String { "official.dataOutline" }
public func settingsGeneralSymbol() -> String { "official.settingsOutlineRegular" }
public func settingsPresetsSymbol() -> String { "official.agentPreset" }
public func isForbiddenSettingsShellSymbol(_ name: String) -> Bool {
    name == "cpu" || name == "slider.horizontal.3" || name == "person.crop.circle"
}
public let settingsNavIconSizePoints: Double = 16
public let settingsDataOutlineFillPath =
    "M7.8667 0.349609C8.96906 0.349634 10.0601 0.481272 11.0317 0.735352C11.9973 0.987845 12.8453 1.362 13.4644 1.84766C14.0744 2.32629 14.507 2.95539 14.5161 3.69336H14.5171V8.53516C14.0843 8.32076 13.6108 8.17679 13.1108 8.11816C13.1831 7.96848 13.2162 7.82856 13.2163 7.70312V5.76758C12.6269 6.16618 11.8739 6.47995 11.0317 6.7002C10.0602 6.95423 8.96896 7.08494 7.8667 7.08496C6.76461 7.08493 5.67411 6.95415 4.70264 6.7002C3.85994 6.48006 3.10694 6.1662 2.51709 5.76758V7.70312L2.521 7.78418C2.56374 8.19554 2.93361 8.74414 3.91357 9.23145C4.9281 9.73585 6.35004 10.0371 7.8667 10.0371C8.26373 10.0371 8.6543 10.0141 9.03271 9.97461C8.75596 10.3799 8.54664 10.8349 8.42041 11.3232C8.23666 11.3313 8.0518 11.3369 7.8667 11.3369C6.20108 11.3369 4.57025 11.01 3.33447 10.3955C3.04163 10.2499 2.76658 10.0836 2.51709 9.90039V11.6738C2.51728 12.1379 2.88589 12.7556 3.92236 13.292C4.93457 13.8157 6.35342 14.1289 7.8667 14.1289C8.12318 14.1289 8.37694 14.1161 8.62646 14.0986C8.82021 14.5535 9.08999 14.9682 9.41943 15.3271C8.91285 15.3934 8.39149 15.4287 7.8667 15.4287C6.19761 15.4287 4.56379 15.0869 3.32568 14.4463C2.11244 13.8185 1.21649 12.8562 1.21631 11.6738V3.76367C1.21595 3.74853 1.21438 3.733 1.21436 3.71777C1.21436 2.96917 1.65103 2.33053 2.26807 1.84668C2.88747 1.36112 3.73675 0.987685 4.70264 0.735352C5.67413 0.481376 6.76457 0.349636 7.8667 0.349609ZM7.8667 1.65039C6.86269 1.65042 5.88326 1.77028 5.03076 1.99316C4.17183 2.2176 3.50421 2.52956 3.06982 2.87012C2.65043 3.19909 2.52622 3.48898 2.51709 3.69336V3.74414C2.52719 3.94845 2.65185 4.23772 3.06982 4.56543C3.50425 4.90601 4.17172 5.21795 5.03076 5.44238C5.88326 5.66527 6.8627 5.78513 7.8667 5.78516C8.8707 5.78513 9.85015 5.66525 10.7026 5.44238C11.5611 5.21787 12.2286 4.9049 12.6626 4.56445C13.0982 4.22252 13.2163 3.9231 13.2163 3.71777L13.2104 3.63574C13.1818 3.43623 13.044 3.16941 12.6626 2.87012C12.2286 2.52957 11.5614 2.21773 10.7026 1.99316C9.85009 1.77025 8.8708 1.65041 7.8667 1.65039Z"
public let settingsDataOutlineGearPath =
    "M12.8936 10.0361L13.2061 10.5566C13.2296 10.5959 13.2651 10.6562 13.3027 10.707C13.3469 10.7666 13.4148 10.8431 13.5195 10.9023C13.6244 10.9617 13.725 10.9801 13.7988 10.9873C13.8619 10.9934 13.9318 10.9932 13.9775 10.9932H14.6162L14.8896 11.4502L14.5947 11.9443C14.5698 11.9859 14.5312 12.0483 14.5029 12.1084C14.4781 12.1611 14.4514 12.2312 14.4395 12.3164L14.4326 12.4072L14.4395 12.4971C14.4514 12.5825 14.4781 12.6532 14.5029 12.7061C14.5312 12.7661 14.5689 12.8287 14.5938 12.8701L14.8896 13.3633L14.6162 13.8213H13.9775C13.9318 13.8213 13.8619 13.821 13.7988 13.8271C13.7433 13.8326 13.6728 13.8442 13.5967 13.875L13.5195 13.9121C13.4148 13.9714 13.3469 14.0478 13.3027 14.1074C13.265 14.1583 13.2296 14.2186 13.2061 14.2578L12.8936 14.7783H12.3115L11.999 14.2578C11.9755 14.2186 11.9401 14.1583 11.9023 14.1074C11.8693 14.0628 11.823 14.0083 11.7578 13.959L11.6855 13.9121L11.6074 13.875C11.5316 13.8445 11.4615 13.8325 11.4062 13.8271C11.3432 13.821 11.2733 13.8213 11.2275 13.8213H10.5889L10.3135 13.3633L10.6104 12.8701C10.6352 12.8287 10.6739 12.7661 10.7021 12.7061C10.7352 12.6357 10.7724 12.534 10.7725 12.4072C10.7724 12.2804 10.7352 12.1788 10.7021 12.1084C10.6739 12.0483 10.6353 11.9859 10.6104 11.9443L10.3135 11.4502L10.5889 10.9932H11.2275C11.2733 10.9932 11.3432 10.9934 11.4062 10.9873C11.4801 10.9801 11.5808 10.9616 11.6855 10.9023C11.7903 10.843 11.8582 10.7666 11.9023 10.707C11.94 10.6562 11.9755 10.5959 11.999 10.5566L12.3115 10.0361H12.8936Z"

/// Desktop `ui-theme` AppearanceRow cubes: `IconLightOutlineMedium` /
/// `IconDarkOutlineMedium` / `IconFollowsystemOutlineMedium` (`ICON_MEDIUM_STROKE` 1.3).
public let appearanceCubeIconStrokeWidth: Double = 1.3
public let appearanceLightCorePath =
    "M8.00007 11.8117C10.1052 11.8117 11.8117 10.1052 11.8117 8.00007C11.8117 5.89499 10.1052 4.18848 8.00007 4.18848C5.89499 4.18848 4.18848 5.89499 4.18848 8.00007C4.18848 10.1052 5.89499 11.8117 8.00007 11.8117Z"
public let appearanceLightRayPaths = [
    "M13.3899 8H15.1499",
    "M11.8115 11.8115L13.0556 13.0556",
    "M8 13.3901V15.1501",
    "M4.18868 11.8115L2.94458 13.0556",
    "M2.6101 8H0.850098",
    "M4.18868 4.18856L2.94458 2.94446",
    "M8 2.6101V0.850098",
    "M11.8115 4.18856L13.0556 2.94446",
]
public let appearanceDarkPath =
    "M14.1127 8.70663C14.2576 8.60602 14.4627 8.71355 14.4386 8.88834C14.2901 9.96567 13.8731 10.9912 13.2229 11.8692C12.479 12.8735 11.4613 13.6421 10.2917 14.0829C9.1222 14.5236 7.85038 14.6179 6.62865 14.3543C5.40692 14.0907 4.28709 13.4805 3.40332 12.5967C2.51955 11.7129 1.90931 10.5931 1.64572 9.37135C1.38212 8.14962 1.47635 6.87779 1.91711 5.70825C2.35787 4.5387 3.12647 3.52103 4.13083 2.77714C5.00878 2.12689 6.03433 1.70994 7.11166 1.5614C7.28645 1.5373 7.39397 1.74238 7.29337 1.88734C6.68703 2.76099 6.37885 3.81241 6.42313 4.88345C6.47392 6.11194 6.98471 7.27645 7.85413 8.14587C8.72355 9.01529 9.88805 9.52608 11.1166 9.57687C12.1876 9.62114 13.239 9.31296 14.1127 8.70663Z"
public let appearanceFollowSystemScreenPath =
    "M13.5 2.5H2.5C1.94772 2.5 1.5 2.94772 1.5 3.5V11.5C1.5 12.0523 1.94772 12.5 2.5 12.5H13.5C14.0523 12.5 14.5 12.0523 14.5 11.5V3.5C14.5 2.94772 14.0523 2.5 13.5 2.5Z"
public let appearanceFollowSystemStandPath = "M5 14.5H11"

public func appearanceLightSymbol() -> String { "official.appearanceLight" }
public func appearanceDarkSymbol() -> String { "official.appearanceDark" }
public func appearanceFollowSystemSymbol() -> String { "official.appearanceFollowSystem" }

public func isForbiddenSystemAppearanceSymbol(_ name: String) -> Bool {
    name == "sun.max" || name == "moon" || name == "desktopcomputer"
}

/// Desktop slash-menu description clamp (`InputBar.module.css` line-clamp: 2).
public let commandMenuDescriptionLineLimit = 2

/// Desktop `ui-chat` `RunningWhaleTail` rest silhouette (16×16 viewBox).
public let runningWhaleRestPath = "M8.844 13.742C8.967 12.328 8.45 10.4 8.45 9.65C8.45 8.94 8.88 8.43 9.6 8.43C11.285 8.43 12.106 8.281 12.685 8.104C13.71 7.791 14.585 6.768 15.055 5.945C15.137 5.803 14.99 5.641 14.829 5.671C13.829 5.86 12.828 5.376 11.827 4.978C10.659 4.514 9.491 4.707 8.935 4.876C8.805 4.915 8.658 4.819 8.636 4.686C8.468 3.643 7.405 2.615 5.498 2.238C4.54 2.048 3.748 1.574 3.347 1.202C3.252 1.113 3.088 1.125 3.03 1.242C2.628 2.059 2.168 3.82 5.248 6.115C5.82 6.494 6.31 6.785 6.574 7.637C6.72 8.104 6.157 9.168 6.061 9.368C5.157 11.27 5.089 12.19 4.926 13.742"

/// Subagent whose parent row is missing or marked offline cannot send.
public func composerParentOffline(origin: String?, parentSessionId: String?, parentListed: Bool, parentOffline: Bool) -> Bool {
    guard origin == "subagent", let parentSessionId, !parentSessionId.isEmpty else { return false }
    return !parentListed || parentOffline
}

/// Chat HTTP(S) links follow Host `ui-chat.linkOpening` (`sidebar` | `new-tab`).
public enum ChatLinkDestination: String, Equatable, Sendable {
    case sidebar
    case newTab = "new-tab"
}

public func chatLinkDestination(_ raw: String?) -> ChatLinkDestination {
    raw == ChatLinkDestination.newTab.rawValue ? .newTab : .sidebar
}

public func isChatWebLink(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https"
}

/// Always-present fetch identity so SwiftUI `.task` is not tied to a summary Group.
public func changesCardFetchIdentity(hostId: String?, sessionId: String, seq: Int64?, hasSummaryOp: Bool) -> String {
    "\(hostId ?? "")-\(sessionId)-\(seq.map(String.init) ?? "")-\(hasSummaryOp)"
}

public func changesCardShouldFetch(seq: Int64?, hasSummaryOp: Bool) -> Bool {
    seq != nil && hasSummaryOp
}

/// Non-zero layout so a `LazyVStack` mounts the card and runs `.task` before a
/// summary exists. Zero-height `Color.clear` / empty `Group` is skipped (R5 P1).
public let changesCardFetchAnchorPoints: Double = 1

/// Mount the fetch host whenever the transcript would show the card — even if
/// `workspaceChanges.summary` has not returned yet.
public func changesCardMountsFetch(
    seq: Int64?,
    turnClosed: Bool,
    codeWork: Bool,
    hasSummaryOp: Bool
) -> Bool {
    turnClosed && codeWork && changesCardShouldFetch(seq: seq, hasSummaryOp: hasSummaryOp)
}

/// Desktop InputBar sizes (`InputBar.module.css`): 28 add, 34 send, 36/52 text.
public let composerAddButtonPoints: Double = 28
public let composerSendButtonPoints: Double = 34
public let composerChipHeightPoints: Double = 28
public let composerTextMinHeightPoints: Double = 36
public let composerHeroTextMinHeightPoints: Double = 52
public let composerTextMaxHeightPoints: Double = 132
/// Card chrome around the text+toolbar (desktop InputBar padding).
public let composerCardPaddingTopPoints: Double = 6
public let composerCardPaddingBottomPoints: Double = 4
public let composerCardPaddingHorizontalPoints: Double = 8
public let composerInnerSpacingPoints: Double = 4

/// Empty / short text uses the desktop floor, never the 132pt max. Growing to
/// the cap is what left a tall blank field and squeezed the slash list to ~3 rows.
public func composerTextFittedHeight(contentHeight: Double, hero: Bool) -> Double {
    let floor = hero ? composerHeroTextMinHeightPoints : composerTextMinHeightPoints
    return min(composerTextMaxHeightPoints, max(floor, contentHeight))
}

public func composerTextShouldScroll(fittedHeight: Double) -> Bool {
    fittedHeight >= composerTextMaxHeightPoints
}

/// Desktop `ui-chat` turn-trigger kinds (`turn-trigger.ts`).
public func isTurnTriggerKind(_ kind: String?) -> Bool {
    guard let kind, !kind.isEmpty, kind != "user", kind != "runtime-context" else { return false }
    return true
}

/// Desktop `ui-chat` `inbox.ts` claim after one `agent/inbox/spliced`.
/// A non-canceled removal **replaces** `currentClaimed`; it does not accumulate.
public struct InboxClaimState: Equatable, Sendable {
    public var currentClaimed: Set<String>
    public var claimSeq: Int64
    public var claimedHuman: Bool

    public static let empty = InboxClaimState(currentClaimed: [], claimSeq: -1, claimedHuman: false)

    public init(currentClaimed: Set<String> = [], claimSeq: Int64 = -1, claimedHuman: Bool = false) {
        self.currentClaimed = currentClaimed
        self.claimSeq = claimSeq
        self.claimedHuman = claimedHuman
    }
}

public struct InboxClaimIdentity: Equatable, Sendable {
    public var id: String
    public var sourceKind: String?

    public init(id: String, sourceKind: String? = nil) {
        self.id = id
        self.sourceKind = sourceKind
    }
}

/// Desktop `inbox.ts` `applySplice`: claim batch is the removed ids, or the
/// previous claim minus any re-inserted ids.
public func applyInboxClaim(
    previous: InboxClaimState,
    removed: [InboxClaimIdentity],
    insertedIds: [String],
    outcome: String?,
    seq: Int64
) -> InboxClaimState {
    if !removed.isEmpty && outcome != "canceled" {
        return InboxClaimState(
            currentClaimed: Set(removed.map(\.id)),
            claimSeq: seq,
            claimedHuman: removed.contains { $0.sourceKind == "user" }
        )
    }
    var claimed = previous.currentClaimed
    for id in insertedIds { claimed.remove(id) }
    return InboxClaimState(
        currentClaimed: claimed,
        claimSeq: previous.claimSeq,
        claimedHuman: previous.claimedHuman
    )
}

/// Desktop `ui-chat` `message.ts` (compiled client.js ~10360–10491).
/// `waking` is `inbox-next-turn.currentClaimed.has(id)` or an idle steer:
/// step 1, next-step claim after `turn/start`, no later next-turn claim,
/// `claimedHuman == false`.
public func isWakingTurnTrigger(
    sourceKind: String?,
    messageId: String?,
    nextTurn: InboxClaimState,
    nextStep: InboxClaimState,
    step: Int?,
    turnStartSeq: Int64?
) -> Bool {
    guard let kind = sourceKind, !kind.isEmpty, kind != "user" else { return false }
    guard let messageId, !messageId.isEmpty else { return false }
    if nextTurn.currentClaimed.contains(messageId) { return true }
    guard step == 1, let turnStart = turnStartSeq else { return false }
    return nextStep.claimSeq > turnStart
        && nextTurn.claimSeq < turnStart
        && nextStep.claimedHuman == false
        && nextStep.currentClaimed.contains(messageId)
}

/// Desktop `JobListAction` anchors the list below the chip (`arrowEdge: .top`).
public let jobsPopoverArrowPointsDown = true

/// Desktop `MenuSurface` sizes to the roster, not a fixed 320×420 sheet.
public let jobsPopoverSizesToContent = true
/// Desktop portals one `MenuSurface` identity. `ViewThatFits` remounting
/// `jobList` ↔ `ScrollView { jobList }` drops the first 「已结束」 press.
public let jobsPopoverKeepsRosterIdentity = true
public let jobsPopoverWidthPoints: Double = 320
public let jobsPopoverMaxHeightPoints: Double = 360
/// Settled `detail` (`signal: SIGTERM; cancelled by the user`) is never ellipsized.
public let jobsPopoverSettledDetailWraps = true

public func jobsPopoverWidth(screenWidth: Double) -> Double {
    min(max(jobsPopoverWidthPoints, screenWidth - 24), 520)
}

/// Desktop statistics row uses `tok`, not `tokens`.
public let composerStatisticsTokenUnit = "tok"

/// Desktop `@deepseek-ai/dsh-client-ui-conversation@0.2.1-alpha.5`
/// `InputBar.module.css` `.dock` (`lib/client.js:18703`):
/// `justify-content:center;align-items:center;gap:12px;max-width:100%;padding-top:4px;display:flex`.
/// Activity / Usage inject `conversation.composer.dock`; ContextMeter is the
/// sibling after them (`InputBar` `lib/client.js:19161-19167`).
public let composerStatisticsRowCentersUnderComposer = true
public let composerStatisticsRowGapPoints: Double = 12
public let composerStatisticsRowPaddingTopPoints: Double = 4
/// `.root { padding: 0 var(--dsh-composer-side-clearance) 4px }`.
public let composerStatisticsRowPaddingBottomPoints: Double = 4
/// Desktop `.dock` has no inline padding. InputBar `.root` wraps card + dock
/// with `--dsh-composer-side-clearance` (`Conversation.module.css`
/// `lib/client.js:17325`: `.body` 16px / `.embeddedBody` 8px). iOS
/// `ComposerView` already uses 14pt as that gutter; the dock uses the same
/// 14 so it shares the card's content box. Not a user exception.
public let composerStatisticsRowPaddingHorizontalPoints: Double = 14
/// XCUITest: content-sized pills row, not the expanding `maxWidth` frame.
public func composerStatisticsRowIdentifier() -> String { "composerStats" }
/// Chat page composer card. Landing already uses `landingComposer`.
public func chatComposerIdentifier() -> String { "chatComposer" }
public let composerStatisticsRowCenterTolerancePoints: Double = 1

/// Desktop `ui-chat` `StatsPills.module.css` `.pill` (`lib/client.js:7373`):
/// `gap:6px;padding:1px 8px;border-radius:var(--dsw-radius-sm)` (theme `8px`);
/// `font-size:calc(var(--dsh-content-font-size-secondary,13px) - 1px)` → 12;
/// `line-height:calc(20px + var(--dsh-content-font-delta-secondary,0px))`;
/// `color:var(--dsw-alias-label-tertiary)`; expanded/hover uses
/// `interactive-bg-hover` + `label-secondary`.
public let composerStatisticsPillIconGapPoints: Double = 6
public let composerStatisticsPillPaddingVerticalPoints: Double = 1
public let composerStatisticsPillPaddingHorizontalPoints: Double = 8
public let composerStatisticsPillRadiusPoints: Double = 8
/// CSS `border-radius` is circular-arc, not iOS continuous squircle.
public let composerStatisticsPillCornerIsCircular = true
public let composerStatisticsPillFontSizePoints: Double = 12
public let composerStatisticsPillLineHeightPoints: Double = 20

/// Desktop `ui-conversation` `ContextMeter.module.css` `.trigger`
/// (`lib/client.js:18454`): `font-size:var(--dsh-content-font-size-secondary,13px)`;
/// `gap:6px;padding:1px 8px`. Fill stroke is `label-tertiary`, not primary.
public let composerContextMeterFontSizePoints: Double = 13
public let composerContextMeterIconGapPoints: Double = 6
public let composerContextRingFillUsesTertiary = true

/// Desktop `stat-dialog.module.css` `.panel` (`ui-chat` `lib/client.js:6814`):
/// `padding:16px;font-size:12px;line-height:18px;`
/// `min-width:min(300px,100vw - 24px);max-width:min(440px,100vw - 24px)`.
/// `.details { color: label-tertiary; gap: 6px 16px }`
/// `.details dd { color: label-secondary }`.
public let composerStatDialogPaddingPoints: Double = 16
public let composerStatDialogFontSizePoints: Double = 12
public let composerStatDialogLineHeightPoints: Double = 18
public let composerStatDialogDetailsRowGapPoints: Double = 6
public let composerStatDialogDetailsColumnGapPoints: Double = 16
public let composerStatDialogTitleGapPoints: Double = 16
public let composerStatDialogTitleMarginBottomPoints: Double = 8
public let composerStatDialogTitleRuleMarginBottomPoints: Double = 10
public let composerStatDialogMinWidthPoints: Double = 300
public let composerStatDialogMaxWidthPoints: Double = 440
public let composerStatDialogViewportInsetPoints: Double = 24

public func composerStatDialogMinWidth(screenWidth: Double) -> Double {
    min(composerStatDialogMinWidthPoints, screenWidth - composerStatDialogViewportInsetPoints)
}

public func composerStatDialogMaxWidth(screenWidth: Double) -> Double {
    min(composerStatDialogMaxWidthPoints, screenWidth - composerStatDialogViewportInsetPoints)
}

/// Desktop `ContextMeter.module.css` `.panel` (`lib/client.js:18454`):
/// `padding:12px;font-size:12px;line-height:20px;width:min(264px,100vw - 24px)`.
/// `.header { gap: 6px }`; `.bar { margin: 10px 0 12px; gap: 1px; height: 4px; radius 999 }`;
/// `.rows { margin: 6px 0 0 }`;
/// `.row { gap: 12px; padding: 2px 0 }`; `.swatch { 8×8, radius 2px, margin-right 6px }`.
public let composerContextPanelPaddingPoints: Double = 12
public let composerContextPanelFontSizePoints: Double = 12
public let composerContextPanelLineHeightPoints: Double = 20
public let composerContextPanelWidthPoints: Double = 264
public let composerContextPanelHeaderGapPoints: Double = 6
public let composerContextBarMarginTopPoints: Double = 10
public let composerContextBarMarginBottomPoints: Double = 12
public let composerContextBarHeightPoints: Double = 4
public let composerContextBarSegmentGapPoints: Double = 1
public let composerContextRowsMarginTopPoints: Double = 6
public let composerContextRowPaddingVerticalPoints: Double = 2
public let composerContextRowGapPoints: Double = 12
public let composerContextSwatchSizePoints: Double = 8
public let composerContextSwatchRadiusPoints: Double = 2
public let composerContextSwatchGapPoints: Double = 6

public func composerContextPanelWidth(screenWidth: Double) -> Double {
    min(composerContextPanelWidthPoints, screenWidth - composerStatDialogViewportInsetPoints)
}

/// Desktop usage chip opens an anchored popover, not a full-screen sheet.
public let composerSessionUsageIsPopover = true
/// Desktop `useStatDialog` (`side: 'top'`) places the panel above the chip.
/// SwiftUI `arrowEdge: .bottom` puts the tip on the bottom edge (content above).
public let composerUsagePopoverOpensAbove = true
/// Desktop `ActivityPill` is the same `DialogPill` / `useStatDialog` (`side: 'top'`).
public let composerActivityPopoverOpensAbove = true
/// Desktop `ContextMeter` `useAnchoredPosition` (`side: "top"`).
public let composerContextPopoverOpensAbove = true
/// Desktop `StatsPills` usage trigger uses `IconDatabaseOutlineRegular`, not the gauge.
public let composerUsagePillUsesDatabaseIcon = true
/// Activity pill: `IconGaugeOutlineRegular` 14×14. Usage pill / popovers:
/// `IconDatabaseOutlineRegular` 14×14. Never SF `gauge.*` / `cylinder`.
public let composerStatisticsIconSizePoints: Double = 14
public func composerActivityGaugeSymbol() -> String { "official.gaugeOutline" }
public func composerUsageDatabaseSymbol() -> String { "official.databaseOutline" }

public func isForbiddenComposerStatisticsSymbol(_ name: String) -> Bool {
    name == "gauge.with.dots.needle.67percent"
        || name == "gauge.with.needle"
        || name == "cylinder"
        || name == "externaldrive"
        || name == "externaldrive.fill"
}

/// Desktop `IconGaugeOutlineArtwork` arc / needle / hub.
public let composerActivityGaugeArcPath =
    "M3.4041 13.096C2.49514 12.187 1.87614 11.0288 1.62537 9.76798C1.37459 8.50716 1.50331 7.20028 1.99525 6.01261C2.48719 4.82494 3.32025 3.80981 4.3891 3.09557C5.45795 2.38134 6.71458 2.00008 8.0001 2C9.28563 2.00008 10.5423 2.38134 11.6111 3.09557C12.68 3.80981 13.513 4.82494 14.005 6.01261C14.4969 7.20028 14.6256 8.50716 14.3748 9.76798C14.1241 11.0288 13.5051 12.187 12.5961 13.096"
public let composerActivityGaugeNeedlePath = "M8 8.49994L11.6114 4.88855"
public let composerActivityGaugeHubPath =
    "M8 9.75C8.69036 9.75 9.25 9.19036 9.25 8.5C9.25 7.80964 8.69036 7.25 8 7.25C7.30964 7.25 6.75 7.80964 6.75 8.5C6.75 9.19036 7.30964 9.75 8 9.75Z"

/// Desktop `IconDatabaseOutlineArtwork` (top ellipse, sides, mid arc, bottom arc).
public let composerUsageDatabaseTopPath =
    "M13.1967 5.1869C13.7232 4.77378 14.0003 4.30517 14.0001 3.82819C14.0003 3.3512 13.7232 2.88259 13.1967 2.46947C12.6702 2.05635 11.9128 1.71328 11.0006 1.47475C10.0885 1.23621 9.05371 1.11062 8.00039 1.1106C6.94707 1.11057 5.9123 1.23612 5.00009 1.47461C4.08742 1.71301 3.32948 2.05604 2.80249 2.46919C2.2755 2.88235 1.99805 3.35106 1.99805 3.82819C1.99805 4.30531 2.2755 4.77402 2.80249 5.18718C3.32948 5.60033 4.08742 5.94336 5.00009 6.18176C5.9123 6.42025 6.94707 6.5458 8.00039 6.54578C9.05371 6.54575 10.0885 6.42016 11.0006 6.18163C11.9128 5.94309 12.6702 5.60002 13.1967 5.1869Z"
public let composerUsageDatabaseLeftPath = "M2 3.80371V11.7848"
public let composerUsageDatabaseRightPath = "M14 3.80371V11.7848"
public let composerUsageDatabaseMidPath =
    "M2 7.81396C2 8.60524 2.63214 9.36411 3.75736 9.92363C4.88258 10.4832 6.4087 10.7975 8 10.7975C9.5913 10.7975 11.1174 10.4832 12.2426 9.92363C13.3679 9.36411 14 8.60524 14 7.81396"
public let composerUsageDatabaseBottomPath =
    "M2 11.7847C2 12.6081 2.63214 13.3977 3.75736 13.98C4.88258 14.5622 6.4087 14.8893 8 14.8893C9.5913 14.8893 11.1174 14.5622 12.2426 13.98C13.3679 13.3977 14 12.6081 14 11.7847"
/// Desktop `ContextMeter` trigger is a 14px ring + percent, not a gauge pill.
public let composerContextUsesRingMeter = true
/// Desktop `ContextMeter` ring: 14×14 viewBox, r=5.5, 2px stroke.
public let composerContextRingSizePoints: Double = 14
public let composerContextRingRadiusPoints: Double = 5.5
public let composerContextRingStrokePoints: Double = 2
/// Desktop fill circle uses `stroke-linecap: round`; the track does not.
public let composerContextRingFillLineCapRound = true
/// Desktop `stat-dialog` title row: section name left, headline value right.
public let composerUsagePopoverHeaderSplitsTotal = true
/// Desktop puts the session / turn total in the header, not a 「合计」 row.
public let composerSessionUsageOmitsTotalRow = true
public let composerTurnUsageOmitsTotalRow = true

/// Desktop `ui-chat` `stats.dialog.title`. Activity never invents “loaded history”.
public func composerActivityTitle(english: Bool) -> String {
    english ? "Session statistics" : "会话统计"
}

/// Desktop `ui-chat` `stats.dialog.llmTime` / `toolTime` / `ttft` / `speed`.
public func composerActivityLlmTime(english: Bool) -> String {
    english ? "LLM time" : "模型用时"
}

public func composerActivityToolTime(english: Bool) -> String {
    english ? "Tool time" : "工具调用用时"
}

public func composerActivityTtft(english: Bool) -> String {
    english ? "Avg time to first token (TTFT)" : "首 token 平均（TTFT）"
}

public func composerActivitySpeed(english: Bool) -> String {
    english ? "Tokens per second (TPS)" : "输出速度（TPS）"
}

/// Desktop `ui-chat` `stats.counts`.
public func composerActivityCounts(turns: Int64, steps: Int64, english: Bool) -> String {
    english ? "\(turns) turns \(steps) steps" : "\(turns) 轮 \(steps) 步"
}

/// Desktop `ContextMeter` splits `conversation` `context.aria` around the percent.
public struct ComposerContextHeadline: Equatable, Sendable {
    public var before: String
    public var after: String

    public init(before: String, after: String) {
        self.before = before
        self.after = after
    }
}

public func composerContextHeadline(english: Bool) -> ComposerContextHeadline {
    english
        ? ComposerContextHeadline(before: "", after: "of context used")
        : ComposerContextHeadline(before: "上下文已用", after: "")
}

/// Desktop `conversation` `context.aria`.
public func composerContextAria(percent: String, english: Bool) -> String {
    let headline = composerContextHeadline(english: english)
    if headline.before.isEmpty { return "\(percent) \(headline.after)" }
    if headline.after.isEmpty { return "\(headline.before) \(percent)" }
    return "\(headline.before) \(percent) \(headline.after)"
}

/// Desktop `conversation` `context.used` (dialog aria).
public func composerContextUsed(english: Bool) -> String {
    english ? "of context used" : "上下文已用"
}

/// Desktop `conversation` `context.system` / `context.tools` / `context.messages`.
public func composerContextSystem(english: Bool) -> String {
    english ? "System prompt" : "系统提示词"
}

public func composerContextTools(english: Bool) -> String {
    english ? "Tool definitions" : "工具定义"
}

public func composerContextMessages(english: Bool) -> String {
    english ? "Messages" : "对话消息"
}

public enum ComposerContextBreakdownRow: String, Equatable, CaseIterable, Sendable {
    case system, tools, messages
}

public func composerContextBreakdownLabel(_ row: ComposerContextBreakdownRow, english: Bool) -> String {
    switch row {
    case .system: return composerContextSystem(english: english)
    case .tools: return composerContextTools(english: english)
    case .messages: return composerContextMessages(english: english)
    }
}

public enum ComposerSessionUsageRow: String, Equatable, Sendable {
    case cacheHit, uncachedInput, cacheRead, cacheWrite, output
}

/// Desktop `ui-chat` `stats.dialog.usageTitle` — label only; total is `titleValue`.
public func composerSessionUsageTitle(english: Bool) -> String {
    english ? "Token usage" : "Token 用量"
}

public func composerSessionUsageTitleValue(exactTotal: String) -> String {
    "\(exactTotal) \(composerStatisticsTokenUnit)"
}

/// Desktop `ui-chat` `message.turnUsage.title`.
public func composerTurnUsageTitle(english: Bool) -> String {
    english ? "Turn usage" : "本轮用量"
}

/// Desktop `ui-chat` `message.turnUsage.consumed` + `message.turnUsage.count`.
public func composerTurnUsageConsumed(total: String, english: Bool) -> String {
    english ? "Usage \(total)" : "用量 \(total)"
}

/// Desktop `ui-chat` `message.turnUsage.model`.
public func composerTurnUsageModelLabel(english: Bool) -> String {
    english ? "Provider / model" : "提供方 / 模型"
}

/// Desktop `ui-chat` `message.turnUsage.reasoning` (`{tokens}` already includes `tok`).
public func composerTurnUsageReasoning(tokens: String, english: Bool) -> String {
    english ? " (\(tokens) reasoning)" : "（其中推理 \(tokens)）"
}

public func composerSessionUsageRowLabel(_ row: ComposerSessionUsageRow, english: Bool) -> String {
    switch row {
    case .cacheHit: return english ? "Cache hit" : "缓存命中"
    case .uncachedInput: return english ? "Uncached input" : "未缓存输入"
    case .cacheRead: return english ? "Cached input" : "缓存读取"
    case .cacheWrite: return english ? "Cache write" : "缓存写入"
    case .output: return english ? "Output" : "输出"
    }
}

public func composerSessionUsageTokenValue(exact: String) -> String {
    "\(exact) \(composerStatisticsTokenUnit)"
}

/// Compact usage pill. Desktop `stats.cacheHit` is「缓存命中」, never「缓存命中中」.
public func composerCacheHitPill(percent: String, english: Bool) -> String {
    english ? "Cache hit \(percent)%" : "缓存命中 \(percent)%"
}

/// Desktop `RiskConfirmation` blurs the composer first.
public let permissionRiskDismissesKeyboard = true

/// Phone session drawer. Opening it (header button or leading-edge swipe)
/// must end composer first-responder so the IME cannot cover the drawer
/// footer (Settings / Remote Host). Android `ModalNavigationDrawer` plus
/// iOS convention; #65 pinned the landing composer to the bottom and #66
/// put the host name on that footer, which made the stuck IME visible.
public let openingSessionDrawerResignsComposer = true
/// Drawer search is the only drawer field that may show the keyboard, and
/// only after the user focuses it — opening the drawer does not.
public let drawerOpenDoesNotFocusSearch = true
public let drawerScrollDismissesKeyboard = true
/// Chat transcript (and landing leftover space) resign the composer.
public let chatScrollDismissesKeyboard = true
public let tapOutsideComposerResignsKeyboard = true
/// Pushing Settings / Remote Host from the drawer must not leave the IME.
public let leavingDrawerForSettingsOrHostResignsKeyboard = true

/// Desktop `message.ts` idle steer is `location.kind === "step" && step === 1`.
/// A turn without a step is not step 1.
public func wakingTriggerStep(openStep: Int?, openTurn _: Int?) -> Int? {
    openStep
}

/// Desktop `RiskConfirmation` is a centered dialog, not a full-screen sheet.
public let permissionRiskIsCenteredDialog = true
/// Checkbox / confirm stay in the viewport: ignore keyboard inset, scroll if needed.
public let permissionRiskStaysAboveKeyboard = true

/// Desktop keeps the conversation mounted while the in-app browser is open.
public let chatPreservesPositionAcrossBrowser = true

/// Phone chrome. Host `ui-theme` appearance / fonts belong to the Host window
/// (`ui-theme.preference`, `fontSize`, families). Android `#63` stopped mirroring
/// appearance; the controller also keeps fonts local so a phone size/family
/// change cannot mutate the remote Host, and disconnect cannot reset the phone.
public let phoneLocalThemeNamespace = "ui-theme"

public let phoneLocalThemeFields: Set<String> = [
    "preference",
    "fontSize",
    "codeFontSize",
    "terminalFontSize",
    "textFontFamily",
    "codeFontFamily",
    "terminalFontFamily",
]

public func isPhoneLocalThemeField(namespace: String, field: String) -> Bool {
    namespace == phoneLocalThemeNamespace && phoneLocalThemeFields.contains(field)
}

/// Desktop `locale.preference` / Android `SharedSetting.Language`. Controller copy
/// follows the Host window language. This is not phone-local `ui-theme`.
public let controllerLanguageFollowsHost = true
/// Android `enabled = shared.writable(SharedSetting.Language)`.
public let languagePickerRequiresHostWritable = true
public let hostLanguageNamespace = "locale"
public let hostLanguageField = "preference"

/// Host `locale.preference` wins. When the mirror is not ready, follow the system
/// language (Android `AppPrefs.language` getter). `nil` keeps the current value
/// (Host ready but the locale namespace is absent).
public func controllerLanguageIsZh(
    hostedPreference: String?,
    hostReady: Bool,
    systemIsZh: Bool
) -> Bool? {
    if let hosted = hostedPreference { return hosted.hasPrefix("zh") }
    if !hostReady { return systemIsZh }
    return nil
}

/// Desktop hero is already a blank session, so permission lives on the Host.
/// iOS landing has no session: the draft stays in memory and is not persisted.
public let landingPermissionPersistsAcrossLaunch = false

/// Desktop `permission.access` (composer / hero) vs `settings.permission` (defaults).
public enum PermissionRiskAudience: String, Equatable, Sendable {
    case currentSession
    case newSessionDefault
}

public func permissionFullAccessRiskDescription(audience: PermissionRiskAudience, english: Bool) -> String {
    switch audience {
    case .newSessionDefault:
        return english
            ? "With full access, new sessions will skip more confirmations and can perform more actions, including sensitive operations, file changes, or external commands. Use only when you trust later tasks."
            : "启用完全权限后，新会话将减少确认步骤，并且可以直接执行更多操作，包括敏感操作、文件修改或外部命令。仅建议在你信任后续任务时使用。"
    case .currentSession:
        return english
            ? "With full access, the agent will skip more confirmations and can perform more actions, including sensitive operations, file changes, or external commands. Use only when you trust the current task."
            : "启用完全权限后，智能体将减少确认步骤，并且可以直接执行更多操作，包括敏感操作、文件修改或外部命令。仅建议在你信任当前任务时使用。"
    }
}

public enum TurnTriggerIcon: String, Equatable, Sendable {
    case agent, github, goal, job, plugin, request, schedule, subagent, team, webhook
}

public func turnTriggerIcon(sourceKind: String?, provider: String?) -> TurnTriggerIcon {
    switch sourceKind {
    case "goal": return .goal
    case "agent-message": return .agent
    case "team-message": return .team
    case "subagent-settled": return .subagent
    case "webhook": return provider == "github" ? .github : .webhook
    case "schedule": return .schedule
    case "tool-jobs": return .job
    case "cordis-host-runner": return .plugin
    default: return .request
    }
}

/// Desktop `ui-chat` `message.trigger.*` — no invented copy.
public func turnTriggerTitle(sourceKind: String?, provider: String?, english: Bool) -> String {
    switch turnTriggerIcon(sourceKind: sourceKind, provider: provider) {
    case .goal: return english ? "Continuing goal" : "继续执行目标"
    case .agent: return english ? "Task message received" : "收到任务消息"
    case .team: return english ? "Team message received" : "收到团队消息"
    case .subagent: return english ? "Subtask status updated" : "子任务状态更新"
    case .github: return english ? "GitHub event received" : "收到 GitHub 事件"
    case .webhook: return english ? "External event received" : "收到外部事件"
    case .schedule: return english ? "Automation task" : "自动化任务"
    case .job: return english ? "Background task updated" : "后台任务状态更新"
    case .plugin: return english ? "Plugin status updated" : "插件状态更新"
    case .request: return english ? "Execution requested" : "收到执行请求"
    }
}

public func turnTriggerExplanation(english: Bool) -> String {
    english ? "This notification triggered this response." : "这条通知触发了本轮回复。"
}

public func turnTriggerProvider(_ sourceJson: String?) -> String? {
    guard let sourceJson, let parsed = try? JSONValue.parse(sourceJson) else { return nil }
    return parsed["provider"].str()
}

/// Desktop `ui-chat` `TurnTriggerNodeView` `TRIGGER_ICONS` size 14.
/// Never SF `target` / `person.crop.circle` / `bolt.horizontal` / …
public func turnTriggerOfficialSymbol(_ icon: TurnTriggerIcon) -> String {
    switch icon {
    case .request: return "official.contextInjection"
    case .goal: return "official.goalOutline"
    case .agent: return "official.paperPlaneOutline"
    case .team, .subagent: return "official.agentPreset"
    case .github: return "official.branchOutline"
    case .webhook: return "official.globeOutline"
    case .schedule: return "official.clockOutline"
    case .job: return "official.queueOutline"
    case .plugin: return "official.cordisPlugin"
    }
}

public func isForbiddenTurnTriggerSystemSymbol(_ name: String) -> Bool {
    name == "target"
        || name == "person.crop.circle"
        || name == "arrow.triangle.branch"
        || name == "globe"
        || name == "clock"
        || name == "clock.arrow.circlepath"
        || name == "puzzlepiece.extension"
        || name == "bolt.horizontal"
}

/// Desktop `--dsw-radius-xl` (`ui-theme` `base.css`).
public let dswRadiusXlPoints: Double = 20

/// Desktop `TurnTriggerNodeView.module.css` + `TRIGGER_ICONS` / chevron Regular.
public let turnTriggerIconSizePoints: Double = 14
public let turnTriggerChevronSizePoints: Double = 12
public let turnTriggerHeaderGapPoints: Double = 10
public let turnTriggerHeaderPaddingHorizontalPoints: Double = 16
public let turnTriggerHeaderPaddingVerticalPoints: Double = 12
public let turnTriggerTitleFontSizePoints: Double = 14
public let turnTriggerTimeFontSizePoints: Double = 12
public let turnTriggerBodyPaddingLeadingPoints: Double = 40
public let turnTriggerBodyPaddingBottomPoints: Double = 12
public let turnTriggerRadiusPoints: Double = dswRadiusXlPoints
public let turnTriggerBorderWidthPoints: Double = 0.5

/// Desktop `--dsw-alias-border-l1` (`ui-theme` light `#0000000a` / dark `#ffffff0f`).
public let dswAliasBorderL1LightHex: UInt32 = 0x0A000000
public let dswAliasBorderL1DarkHex: UInt32 = 0x0FFFFFFF
public func dswAliasBorderL1Hex(dark: Bool) -> UInt32 {
    dark ? dswAliasBorderL1DarkHex : dswAliasBorderL1LightHex
}

/// Desktop `--dsw-alias-turn-trigger-bg`: light markdown-code-block `#F9FAFB`,
/// dark interactive-bg-hover `#14FFFFFF`.
public let turnTriggerBackgroundLightHex: UInt32 = 0xFFF9FAFB
public let turnTriggerBackgroundDarkHex: UInt32 = 0x14FFFFFF
public func turnTriggerBackgroundHex(dark: Bool) -> UInt32 {
    dark ? turnTriggerBackgroundDarkHex : turnTriggerBackgroundLightHex
}

/// Desktop `ui-primitives` `IconContextInjectionOutlineArtwork` Regular.
public let iconContextInjectionFramePath =
    "M5 2.5H3.5C3.23478 2.5 2.98043 2.60536 2.79289 2.79289C2.60536 2.98043 2.5 3.23478 2.5 3.5V13.5C2.5 13.7652 2.60536 14.0196 2.79289 14.2071C2.98043 14.3946 3.23478 14.5 3.5 14.5H12.5C12.7652 14.5 13.0196 14.3946 13.2071 14.2071C13.3946 14.0196 13.5 13.7652 13.5 13.5V3.5C13.5 3.23478 13.3946 2.98043 13.2071 2.79289C13.0196 2.60536 12.7652 2.5 12.5 2.5H11"
public let iconContextInjectionStemPath = "M8 0.5V7.5"
public let iconContextInjectionArrowPath = "M5.5 5L8 7.5L10.5 5"
public let iconContextInjectionBarPath = "M5.5 11H10.5"

/// Slash catalog cache is per session (and never shared with a subagent).
public func skillCatalogScopeKey(sessionId: String?, subagent: Bool) -> String {
    if subagent { return "subagent:\(sessionId ?? "")" }
    return sessionId ?? "landing"
}

/// Desktop `conversation` `hero.headline` (`locale/zh.json` via `client.js`).
/// The Chinese string is **未至**, not the commonly misremembered **未知**.
public func landingHeadline(english: Bool) -> String {
    english ? "Into the Unknown" : "探索未至之境"
}

/// Desktop `conversation` `hero.preview`.
public func landingPreviewBadge(english: Bool) -> String {
    english ? "Preview" : "预览版"
}

/// Desktop `HeroShell.module.css` `.root` is `justify-content: center` for the
/// headline stack. Phone landing follows Android `Chat.kt`: Hero centers in
/// leftover space above the workspace row; InputBar pins to the safe-area
/// bottom (same dock as the chat composer). User-required: composer must
/// not float mid-screen with a blank below it.
public let landingHeroCentersStack = false
public let landingComposerPinsToSafeAreaBottom = true
public let landingHeadlineCentersInLeftover = true
/// Max gap from the composer card bottom to the safe-area bottom (pt).
public let landingComposerBottomGapMaxPoints: Double = 40
public let landingHeroPreviewSharesHeadlineLine = true
public let landingHeroStackGapPoints: Double = 12
public let landingHeroHeadlineSizePoints: Double = 26
public let landingHeroHeadlineLineHeightPoints: Double = 32
public let landingHeroHeadlineWeight: Double = 500
public let landingHeroPreviewFontSizePoints: Double = 12
public let landingHeroPreviewLineHeightPoints: Double = 18

/// Desktop EmptyHero `HeroFish` beside `hero.headline`. Previously skipped as
/// hide; user-required on phone landing. Artwork is primitives `FISH_LOGO_PATH`
/// (viewBox 23.16×17.04), not BrandWordmark's offset whale and not SF `fish`.
/// Width 34; height keeps the viewBox ratio. Fill `currentColor` =
/// `--dsw-alias-label-primary` (`T.ink`). Headline CSS `align-items:center`
/// + `gap: 12px 10px` (column-gap 10 from fish to title group). Hover swim
/// is desktop-only — phone has no hover.
public let landingHeroShowsFishLogo = true
public let landingHeroFishWidthPoints: Double = 34
public let fishLogoViewBoxWidth: Double = 23.16
public let fishLogoViewBoxHeight: Double = 17.04
public let landingHeroHeadlineColumnGapPoints: Double = 10
public let landingHeroHeadlineAlignsCenter = true
public let fishLogoPath =
    "M22.9168 1.43018C22.6713 1.31018 22.5658 1.53918 22.4223 1.65519C22.3733 1.69269 22.3318 1.74169 22.2903 1.78669C21.9317 2.1697 21.5127 2.42121 20.9657 2.39121C20.1657 2.34621 19.4827 2.59771 18.8787 3.20973C18.7502 2.45521 18.3236 2.0047 17.6746 1.71569C17.3351 1.56568 16.9916 1.41518 16.7536 1.08867C16.5876 0.856163 16.5421 0.597155 16.4591 0.341647C16.4061 0.187643 16.3536 0.0301382 16.1761 0.00363739C15.9836 -0.0263635 15.9081 0.135141 15.8326 0.270145C15.5306 0.822162 15.4136 1.43018 15.4251 2.0462C15.4516 3.43174 16.0366 4.53527 17.1991 5.3203C17.3311 5.4103 17.3651 5.5003 17.3236 5.63181C17.2441 5.90231 17.1501 6.16482 17.0671 6.43533C17.0141 6.60784 16.9351 6.64584 16.7501 6.57033C16.1121 6.30383 15.5611 5.90931 15.074 5.4328C14.2475 4.63328 13.5 3.75075 12.568 3.05973C12.349 2.89822 12.13 2.74822 11.9034 2.60522C10.9524 1.68169 12.028 0.923165 12.277 0.833162C12.5375 0.739159 12.3675 0.41615 11.5259 0.42015C10.6844 0.42365 9.91439 0.705658 8.93286 1.08117C8.78935 1.13767 8.63835 1.17867 8.48384 1.21267C7.59332 1.04367 6.66829 1.00617 5.70226 1.11517C3.88321 1.31768 2.43016 2.1777 1.36213 3.64575C0.0790928 5.4103 -0.222916 7.41536 0.146595 9.50642C0.535106 11.7105 1.66014 13.535 3.38869 14.9616C5.18125 16.4406 7.24581 17.1657 9.60138 17.0266C11.0319 16.9441 12.6245 16.7526 14.421 15.2321C14.874 15.4576 15.3496 15.5476 16.1381 15.6151C16.7456 15.6716 17.3306 15.5851 17.7836 15.4911C18.4931 15.3411 18.4441 14.6841 18.1876 14.5636C16.1081 13.595 16.5646 13.9891 16.1496 13.67C17.2061 12.42 18.8202 10.1979 19.3182 7.17235C19.3672 6.83834 19.4297 6.36783 19.4222 6.09732C19.4182 5.93231 19.4562 5.86831 19.6447 5.84931C20.1657 5.78931 20.6712 5.64681 21.1357 5.3913C22.4833 4.65528 23.0268 3.44624 23.1548 1.9972C23.1738 1.77569 23.1508 1.54668 22.9168 1.43018ZM11.1749 14.4736C9.15936 12.889 8.18184 12.3675 7.77832 12.39C7.40081 12.4125 7.46881 12.8445 7.55182 13.126C7.63882 13.404 7.75182 13.5955 7.91033 13.8396C8.01983 14.0011 8.09533 14.2411 7.80083 14.4216C7.15181 14.8231 6.02327 14.2866 5.97027 14.2601C4.65673 13.4865 3.5587 12.4655 2.78467 11.069C2.03715 9.72493 1.60314 8.28289 1.53164 6.74384C1.51264 6.37233 1.62214 6.24082 1.99215 6.17332C2.47916 6.08332 2.98118 6.06432 3.46769 6.13582C5.52476 6.43633 7.27581 7.35586 8.74385 8.8129C9.58188 9.64243 10.2159 10.634 10.8689 11.6025C11.5634 12.631 12.3105 13.611 13.262 14.4146C13.598 14.6961 13.866 14.9101 14.1225 15.0681C13.349 15.1546 12.058 15.1731 11.1749 14.4746L11.1749 14.4736ZM12.141 8.25988C12.141 8.09488 12.273 7.96338 12.439 7.96338C12.4765 7.96338 12.5105 7.97088 12.541 7.98188C12.5825 7.99688 12.6205 8.01938 12.6505 8.05338C12.7035 8.10588 12.7335 8.18088 12.7335 8.25988C12.7335 8.42489 12.6015 8.55639 12.4355 8.55639C12.2695 8.55639 12.141 8.42489 12.141 8.25988ZM15.1415 9.79893C14.949 9.87793 14.7565 9.94544 14.5715 9.95294C14.2845 9.96794 13.9715 9.85143 13.8015 9.70893C13.5375 9.48742 13.3485 9.36342 13.2695 8.97691C13.2355 8.8119 13.2545 8.55639 13.2845 8.40989C13.3525 8.09438 13.277 7.89187 13.0545 7.70787C12.8735 7.55786 12.643 7.51636 12.39 7.51636C12.2955 7.51636 12.209 7.47486 12.1445 7.44136C12.039 7.38886 11.9519 7.25735 12.035 7.09585C12.0615 7.04335 12.19 6.91584 12.22 6.89334C12.5635 6.69784 12.9595 6.76184 13.326 6.90834C13.6655 7.04735 13.9225 7.30236 14.292 7.66287C14.6695 8.09838 14.7375 8.21838 14.9525 8.54539C15.1225 8.8009 15.277 9.06341 15.3831 9.36392C15.4471 9.55142 15.3641 9.70493 15.1415 9.79893Z"

public func landingHeroFishHeightPoints() -> Double {
    landingHeroFishWidthPoints * fishLogoViewBoxHeight / fishLogoViewBoxWidth
}

public func landingHeroFishSymbol() -> String { "official.fishLogo" }

public func isForbiddenLandingFishSymbol(_ name: String) -> Bool {
    name == "fish" || name == "fish.fill" || name == "fish.circle"
}

/// Overlay slot above the composer (already keyboard-avoided) minus a hairline
/// margin. This is the *slot*, not the card: never stretch `MenuView` to fill
/// it (`inputTriggerMenuCardMaxHeight` caps the card at 400pt and hugs rows).
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

/// Desktop `ui-input-trigger` MenuView `.itemIcon` is 14×14; each slash
/// row passes `size: 14` into the primitives Regular glyph
/// (`ICON_REGULAR_STROKE` 1).
public let commandMenuIconSizePoints: Double = 14
public let commandMenuIconStrokeWidth: Double = 1

/// Desktop `ui-commands` `HOST_FACES` + conversation `/file` + model-selection
/// `/model`. Never SF paperclip / cylinder / target / shield.
public func commandMenuIconSymbol(_ kind: String?) -> String {
    switch kind {
    case "file": return "official.paperclipOutline"
    case "model": return settingsModelsSymbol()
    case "goal": return "official.goalOutline"
    case "plan": return "official.planOutline"
    case "feedback": return "official.paperPlaneOutline"
    case "compact": return "official.compactOutline"
    case "permission": return "official.permissionFullAccess"
    case "export": return "official.downloadOutline"
    default: return "official.codeOutline"
    }
}

public func commandMenuSkillSymbol() -> String { "official.sparkle" }

public func isForbiddenCommandMenuSystemSymbol(_ name: String) -> Bool {
    name == "paperclip"
        || name == "cylinder.split.1x2"
        || name == "target"
        || name == "doc.text"
        || name == "paperplane"
        || name == "circle.circle"
        || name == "shield"
        || name == "square.and.arrow.down"
        || name == "chevron.left.forwardslash.chevron.right"
        || name == "sparkle"
}

/// Desktop `IconPaperclipOutlineArtwork` Regular. Single stroke, 16×16 view box.
public let iconPaperclipOutlinePath =
    "M12.75 4.5V9.5C12.75 10.7598 12.2496 11.968 11.3588 12.8588C10.468 13.7496 9.25978 14.25 8 14.25C6.74022 14.25 5.53204 13.7496 4.64124 12.8588C3.75045 11.968 3.25 10.7598 3.25 9.5V5C3.25 4.13805 3.59241 3.3114 4.2019 2.7019C4.8114 2.09241 5.63805 1.75 6.5 1.75C7.36195 1.75 8.1886 2.09241 8.7981 2.7019C9.40759 3.3114 9.75 4.13805 9.75 5V9.5C9.75 9.96413 9.56563 10.4092 9.23744 10.7374C8.90925 11.0656 8.46413 11.25 8 11.25C7.53587 11.25 7.09075 11.0656 6.76256 10.7374C6.43437 10.4092 6.25 9.96413 6.25 9.5V5.5"

/// Desktop `IconPaperPlaneOutlineArtwork` Regular. Not `IconSendOutline`.
public let iconPaperPlaneOutlineBodyPath =
    "M4.74024 9.11029L1.82882 7.79865C1.75022 7.76323 1.75026 7.65161 1.82889 7.61626L12.9665 2.60943C13.0354 2.57846 13.1125 2.63213 13.1073 2.70749L12.3914 13.1388C12.3864 13.2117 12.3073 13.2548 12.2433 13.2194L6.12677 9.83657"
public let iconPaperPlaneOutlineFoldPath =
    "M8.44336 11.0825L6.2832 13.2843C6.22048 13.3482 6.11182 13.3038 6.11182 13.2143V9.86772C6.11182 9.84165 6.122 9.8166 6.1402 9.79793L12.972 2.78748"

/// Desktop `IconCompactOutlineArtwork` Regular. Ring is `opacity: 0.35`.
public let iconCompactOutlineRingPath =
    "M8 14.5C11.5899 14.5 14.5 11.5899 14.5 8C14.5 4.41015 11.5899 1.5 8 1.5C4.41015 1.5 1.5 4.41015 1.5 8C1.5 11.5899 4.41015 14.5 8 14.5Z"
public let iconCompactOutlineArcPath =
    "M8 1.5C8.85359 1.5 9.69883 1.66813 10.4874 1.99478C11.2761 2.32144 11.9926 2.80022 12.5962 3.40381C13.1998 4.00739 13.6786 4.72394 14.0052 5.51256C14.3319 6.30117 14.5 7.14641 14.5 8"
public let iconCompactOutlineRingOpacity: Double = 0.35

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

