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
/// `ui-sidebar-terminal` / `ui-sidebar-browser` (`order` 10 / 20 / 30).
/// Session inspector is **not** a desktop Guide card; the phone still exposes
/// the Android `SessionInspectorPanel` after the official three because the
/// user asked for a visible entry (locale: 会话数据诊断 / Session diagnostics).
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

/// Slash catalog cache is per session (and never shared with a subagent).
public func skillCatalogScopeKey(sessionId: String?, subagent: Bool) -> String {
    if subagent { return "subagent:\(sessionId ?? "")" }
    return sessionId ?? "landing"
}

/// Desktop `conversation` `hero.headline`.
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
