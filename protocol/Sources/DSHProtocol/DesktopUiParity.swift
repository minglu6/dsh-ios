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
