import Foundation

/// Desktop `ui-permission-presets` / `ui-model-selection` / `ui-chat` ReasoningRow /
/// sidebar completion / settings shell. Phone layout may change; copy, metrics,
/// and interaction follow desktop. Desktop wins over Android on conflict.

// MARK: - Conversation header

/// Desktop `ConversationSessionHeader` has crumbs / tabs / slots, not a model chip.
public let conversationHeaderShowsModelChip = false

/// Desktop hides `AgentPresetLabel` at width ≤ 540; the iPhone header never shows it.
public let conversationHeaderShowsAgentPreset = false

/// Desktop `AgentPresetSeat` lives on the empty-session hero, not the conversation header.
public let agentPresetSeatOnLandingOnly = true

// MARK: - Settings vs drawer footer

/// Desktop Settings is General / Models / Presets / Plugins. Phone connection
/// is the drawer footer (computer name + status), never a Settings group.
public let settingsIncludesPhoneConnection = false

/// Drawer footer is the desktop location for switching / managing the remote Host.
public let phoneConnectionLivesInDrawerFooter = true

/// Desktop `ui-sidebar` `SidebarRoot` foot: `sidebar.footer.action` then `sidebar.settings`.
/// The peer/device switcher is that footer action, never a Settings group.
public let sidebarFooterActionAboveSettings = true

// MARK: - Permission chip + menu

public let permissionMenuMinWidthPoints: Double = 144
public let permissionMenuMaxWidthPoints: Double = 360
public let permissionMenuPaddingPoints: Double = 4
public let permissionMenuRowMinHeightPoints: Double = 34
public let permissionMenuIconSizePoints: Double = 14
public let permissionTriggerIconSizePoints: Double = 14
public let permissionExpBadgeFontSizePoints: Double = 8
public let permissionExpBadgeFontWeight: Double = 500
public let permissionExpBadgeLetterSpacing: Double = 0.2

/// Desktop `PermissionSelect` / `ModelSelect` `MenuSurface` uses `side: 'top'`
/// (content above the composer chip). SwiftUI `arrowEdge: .bottom` puts the tip
/// on the bottom edge — same mapping as `composerUsagePopoverOpensAbove`.
public let composerPickerPopoverOpensAbove = true

/// Catalog rows (including Auto review) must all fit in the menu above the chip.
public func permissionMenuHeightPoints(optionCount: Int) -> Double {
    precondition(optionCount >= 0, "permissionMenuHeightPoints optionCount must be >= 0")
    return permissionMenuPaddingPoints * 2 + Double(optionCount) * permissionMenuRowMinHeightPoints
}

/// Desktop `PermissionSelect` ships Auto review with `PermissionIconAutoReview`.
public let permissionAutoHasIcon = true

public func permissionHasGlyph(_ value: String) -> Bool {
    switch value {
    case "read-only", "workspace-write", "danger-full-access", "auto": return true
    default: return false
    }
}

public func permissionExpBadge(_ value: String) -> String? {
    value == "auto" ? "EXP" : nil
}

public func permissionAutoDescription(english: Bool) -> String {
    english
        ? "Run without a sandbox after an experimental same-model review of every native tool call and PTC inner call."
        : "无沙箱运行；每次原生工具调用和 PTC 内层调用前由同一模型进行实验性审查。"
}

public func permissionAutoConfirmTitle(english: Bool) -> String {
    english ? "Enable Auto review (experimental)?" : "确认启用自动审查（实验）？"
}

public func permissionAutoConfirmEnable(english: Bool) -> String {
    english ? "Enable Auto review" : "启用自动审查"
}

public func permissionAutoConfirmAcknowledge(english: Bool) -> String {
    english ? "I understand these risks and want to continue" : "我已了解这些风险，并愿意继续"
}

public func permissionAutoConfirmDescription(english: Bool) -> String {
    english
        ? "Auto review runs without a sandbox. Before every native tool call and PTC inner call, the same model as the current agent reviews whether to allow it; you approve or reject each call it denies. This feature is experimental, can falsely allow or deny actions, and uses additional tokens."
        : "自动审查不使用沙箱。每次原生工具调用和 PTC 内层调用前，都会由与当前 agent 相同的模型进行审查；审查拒绝的调用由你批准或拒绝。此功能仍属实验性，可能误放行或误拒绝，并会消耗额外 token。"
}

// MARK: - Model picker

public func modelPickerRootModelLabel(english: Bool) -> String {
    english ? "Model" : "模型"
}

/// Desktop `menu.effort` is "Effort" / "推理等级".
public func modelPickerRootEffortLabel(english: Bool) -> String {
    english ? "Effort" : "推理等级"
}

public func modelPickerEmptyModels(english: Bool) -> String {
    english ? "No models available." : "暂无可用模型"
}

public func modelPickerSearchEmpty(english: Bool) -> String {
    english ? "No matching models." : "没有匹配的模型。"
}

public func modelPickerEmptyEfforts(english: Bool) -> String {
    english ? "This model provides no reasoning effort levels." : "当前模型未提供推理等级。"
}

/// Desktop `ui-model-selection` locale `effort.providerDefault` is the English word in both zh and en.
public func modelPickerEffortProviderDefault(english: Bool) -> String {
    "Default"
}

public func modelPickerSearchPlaceholder(english: Bool) -> String {
    english ? "Search models…" : "搜索模型…"
}

public func modelPickerReloadAction(english: Bool) -> String {
    english ? "Reload" : "重新加载"
}

public let modelPickerMenuMinWidthPoints: Double = 240
public let modelPickerMenuMaxWidthPoints: Double = 420
public let modelPickerMenuMaxHeightPoints: Double = 360
public let modelPickerRowMinHeightPoints: Double = 34
public let modelPickerRootShowsEffortOnlyWhenReasoning = true

// MARK: - Agent preset seat

public let agentPresetSeatMinHeightPoints: Double = 28
public let agentPresetSeatMaxWidthPoints: Double = 240
public let agentPresetSeatFontSizePoints: Double = 13
public let agentPresetSeatFontWeight: Double = 500

// MARK: - Think / reasoning row (desktop ReasoningRow + DisclosureRow)

/// Title is always `message.think`. Streaming vs done is TextShimmer, not a label swap.
public func reasoningTitle(english: Bool) -> String {
    english ? "Think" : "思考"
}

public let reasoningDefaultExpanded = false
public let reasoningChevronReplacesIconWhenExpanded = true
public let reasoningUsesTextShimmerNotSpinner = true
public let reasoningBodyIsCompactMarkdown = true
public let reasoningBodyLeadingPoints: Double = 22
public let reasoningBodyVerticalPaddingPoints: Double = 4
public let reasoningPreviewSeparatorSizePoints: Double = 2
public let reasoningPreviewSeparatorSpacingPoints: Double = 8
public let reasoningIconSizePoints: Double = 14
public let reasoningLeadingBoxPoints: Double = 16
public let reasoningRowGapPoints: Double = 6
public let reasoningTitleFontWeight: Double = 400

/// Compact reasoning Markdown uses secondary size and tertiary color.
public func reasoningBodyFontSize(contentFontSize: Int) -> Int {
    max(10, contentFontSize - 1)
}

/// Desktop `MarkdownText` compact `line-height: 20px` at the 13px secondary size.
public let reasoningBodyLineHeightPoints: Double = 20

/// Desktop `ChatGroupSeat` title uses `--dsh-content-font-size` (14), not the secondary 13.
public let processGroupTitleUsesContentFontSize = true

/// Desktop `ChatGroupSeat` `.content` has no extra left padding; members share the column.
public let processGroupMembersShareColumn = true

/// Desktop `locale.ts` `message.turnProcess.separator`.
public let messageTurnProcessSeparator = " · "

public func processGroupHeaderTitle(label: String, detail: String?) -> String {
    guard let detail, !detail.isEmpty else { return label }
    return label + messageTurnProcessSeparator + detail
}

// MARK: - Sidebar session leading (desktop StateDot + completion.view)

public enum SidebarSessionLeading: String, Equatable, Sendable {
    case idle
    case unread
    case running
    case awaitingAnswer
    case awaitingApproval
}

/// Green unread/finished-unviewed dot only when idle, not archived, and in `completion.view`.
/// Running spinner is session-only; workspace rows keep the folder icon.
public func sidebarSessionLeading(
    running: Bool,
    archived: Bool,
    unread: Bool,
    awaitingApproval: Bool,
    awaitingAnswer: Bool
) -> SidebarSessionLeading {
    if awaitingApproval { return .awaitingApproval }
    if awaitingAnswer { return .awaitingAnswer }
    if running { return .running }
    if unread && !archived { return .unread }
    return .idle
}

public let sidebarLeadingSlotWidthPoints: Double = 16
public let sidebarLeadingSlotHeightPoints: Double = 14
public let sidebarCompletionDotRadiusRatio: Double = 3.0 / 14.0
public let sidebarWorkspaceKeepsFolderIcon = true
public let sidebarIdleSessionHasNoBubble = true
public let sidebarArchivedIdleHasNoLeadingIcon = true
/// Desktop `SearchResultItem` shows workspace context under the title.
public let searchResultShowsWorkspaceContext = true

/// Desktop `EmptySessions` copy when the tree/flat body has no rows.
/// Archived-only adds `empty.viewOthers`, which resets the filter to hide-archived.
/// Desktop has no offline-specific roster sentence (`empty.none` / `empty.noneArchived` only).
public enum DrawerEmptyKind: String, Equatable, Sendable {
    /// Desktop `empty.none`. Not named `none` — that collides with `Optional.none`.
    case empty
    /// Desktop `empty.noneArchived`.
    case emptyArchived
}

public func drawerEmptyKind(online _: Bool, archivedOnly: Bool, hasVisibleSessions: Bool) -> DrawerEmptyKind? {
    if hasVisibleSessions { return nil }
    return archivedOnly ? .emptyArchived : .empty
}

/// Desktop `ui-workspace` `empty.none`.
public func emptySessionsNone(english: Bool) -> String {
    english ? "No sessions yet" : "暂无会话"
}

/// Desktop `EmptySessions` never invents Batch H 「连接后显示会话」.
public let drawerEmptyIgnoresOnline = true

/// Desktop `SessionTree` EmptySessions is `groups.length === 0`, not “no visible
/// sessions”. `groupByWorkspace` still emits a group per workspace unless the
/// archived filter is `only` and that group has no visible members. FlatList
/// EmptySessions is `rows.length === 0`.
public func drawerShowsEmptySessions(
    hasVisibleSessions: Bool,
    groupByWorkspace: Bool,
    hasWorkspaces: Bool,
    archivedOnly: Bool
) -> Bool {
    if hasVisibleSessions { return false }
    if archivedOnly { return true }
    if groupByWorkspace && hasWorkspaces { return false }
    return true
}

/// Desktop `ui-workspace` `empty.viewOthers`.
public func emptyArchivedViewOthers(english: Bool) -> String {
    english ? "View other sessions" : "查看其他会话"
}

/// Desktop `leaveArchivedOnly` writes archived filter `default` (hide archived).
public let emptyArchivedViewOthersResetsToHide = true

/// Desktop `ui-workspace` `toast.archivedNotOpenable`.
public func archivedNotOpenable(english: Bool) -> String {
    english
        ? "Archived sessions cannot be opened. Unarchive it to view."
        : "已归档对话暂时无法查看，请取消归档后查看"
}

public func sidebarCompletionUnreadLabel(english: Bool) -> String {
    english ? "Completed, unread" : "已完成，未查看"
}

/// Desktop `ui-workspace` `status.running`.
public func sidebarRunningLabel(english: Bool) -> String {
    english ? "Running" : "进行中"
}

public func sidebarAwaitingApprovalLabel(english: Bool) -> String {
    english ? "Waiting for approval" : "等待审批"
}

public func sidebarAwaitingAnswerLabel(english: Bool) -> String {
    english ? "Waiting for answer" : "等待回答"
}

// MARK: - Landing workspace chip (desktop EmptyHero WorkspaceChip)

/// Desktop `HeroShell.module.css` `.workspace`: ghost, 13/500, minHeight 28, maxWidth 360.
public let workspaceChipMinHeightPoints: Double = 28
public let workspaceChipMaxWidthPoints: Double = 360
public let workspaceChipFontSizePoints: Double = 13
public let workspaceChipFontWeight: Double = 500
public let workspaceChipIconSizePoints: Double = 16
public let workspaceChipChevronSizePoints: Double = 12
public let workspaceChipUsesGhostTrigger = true
public let workspaceChipUsesSystemMenu = false

/// Desktop `WorkspacePicker` opens the directory flow immediately when add is the only entry.
public func workspaceChipOpensDirectoryFlowDirectly(workspaceCount: Int, canCreate: Bool) -> Bool {
    canCreate && workspaceCount == 0
}

/// Desktop `ui-workspace` `menu.addWorkspace`.
public func addWorkspaceMenuLabel(english: Bool) -> String {
    english ? "Add workspace…" : "添加工作区…"
}

/// Desktop `ui-workspace` `picker.loading`.
public func workspacePickerLoading(english: Bool) -> String {
    english ? "Loading workspaces…" : "正在加载工作区…"
}

// MARK: - Plan chip (desktop ui-plan PlanModeControl)

/// Visible chip text is `chip.label`. Tooltip is `planChipTitle`; a11y is `planChipAria`.
public func planChipLabel(english: Bool) -> String {
    english ? "Plan" : "计划"
}

/// Desktop `chip.on.aria`.
public func planChipAria(english: Bool) -> String {
    english ? "Plan mode on, press to turn off" : "计划模式已开启，按下关闭"
}

/// Desktop `InputBar` `.modes` sits permission then plan, not above the draft editor.
public let planChipLivesInComposerModesRow = true
public let planChipHeightPoints: Double = 28
public let planChipFontSizePoints: Double = 13
public let planChipFontWeight: Double = 500
public let planChipIconSizePoints: Double = 14

/// Desktop `PermissionSelect` returns null until `catalog` is loaded.
public let permissionChipRequiresCatalog = true

/// Desktop `conversation` `input.commands` (plus button aria / tooltip).
public func composerCommandsAria(english: Bool) -> String {
    english ? "Add files or run commands" : "添加文件或调用指令"
}

/// Desktop InputBar `.add`: 28px filled circle, `--dsw-specific-selector` fill.
public let composerAddButtonUsesFilledCircle = true
public let composerAddButtonUsesSelectorFill = true
public let composerAddButtonSelectorLightHex: UInt32 = 0xFFF5F6F7
public let composerAddButtonSelectorDarkHex: UInt32 = 0xFF353638

/// Desktop `conversation.input.left` has no occupant. Ask reopen lives on
/// `ui-tool` `AskQuestionRow` (`ask.reopen`), not a composer chip.
public let composerShowsAskChip = false

public func isAskUserQuestionTool(_ name: String) -> Bool {
    name == "ask_user_question" || name == "request_user_input"
}

/// Desktop `AskQuestionRow` `rowAction` when the question is still answerable.
public func askToolRowReopensComposer(toolName: String, callId: String?, hiddenQuestionCallId: String?) -> Bool {
    guard isAskUserQuestionTool(toolName), let callId, !callId.isEmpty else { return false }
    return callId == hiddenQuestionCallId
}

/// Desktop `AskQuestionRow` `useProjection("userQuestions")` `view.active`.
public func askToolRowIsAnswerable(callId: String?, questionId: String?, activeCallIds: [String]) -> Bool {
    if let callId, !callId.isEmpty, activeCallIds.contains(callId) { return true }
    if let questionId, !questionId.isEmpty, activeCallIds.contains(questionId) { return true }
    return false
}

/// Desktop `isPendingResult`: JSON `{ pending: true, callId }`.
public func isAskPendingResult(_ result: String?) -> Bool {
    guard let result, let parsed = try? JSONValue.parse(result) else { return false }
    return parsed["pending"].bool() == true && (parsed["callId"].str()?.isEmpty == false)
}

/// Desktop `ui-conversation` `ask.waiting` / `ask.pending` / `ask.closed`.
public func askWaitingLabel(english: Bool) -> String {
    english ? "waiting" : "等待回答"
}

public func askPendingLabel(english: Bool) -> String {
    english ? "continued; answer still available" : "已继续工作，仍可回答"
}

public func askClosedLabel(english: Bool) -> String {
    english ? "closed" : "已结束"
}

public func askCancelledLabel(english: Bool) -> String {
    english ? "cancelled" : "已取消"
}

public func askInterruptedLabel(english: Bool) -> String {
    english ? "interrupted" : "已中断"
}

/// Desktop `AskQuestionRow` title / summary / reopen. Review panel is desktop-only.
public struct AskToolRowChrome: Equatable, Sendable {
    public var title: String
    public var summary: String?
    public var actionLabel: String?

    public init(title: String, summary: String?, actionLabel: String?) {
        self.title = title
        self.summary = summary
        self.actionLabel = actionLabel
    }
}

public func askToolRowChrome(
    name: String,
    status: ToolStatus,
    error: String?,
    result: String?,
    answerable: Bool,
    english: Bool
) -> AskToolRowChrome? {
    guard isAskUserQuestionTool(name) else { return nil }
    let title = askRowTitle(english: english)
    if error == "ASK_CANCELLED" {
        return AskToolRowChrome(title: title, summary: askCancelledLabel(english: english), actionLabel: nil)
    }
    if error == "ASK_ABORTED" {
        return AskToolRowChrome(title: title, summary: askInterruptedLabel(english: english), actionLabel: nil)
    }
    if status == .running || status == .preparing {
        return AskToolRowChrome(
            title: title,
            summary: askWaitingLabel(english: english),
            actionLabel: answerable ? askReopenLabel(english: english) : nil
        )
    }
    if isAskPendingResult(result) {
        if answerable {
            return AskToolRowChrome(
                title: title,
                summary: askPendingLabel(english: english),
                actionLabel: askReopenLabel(english: english)
            )
        }
        return AskToolRowChrome(title: title, summary: askClosedLabel(english: english), actionLabel: nil)
    }
    return AskToolRowChrome(title: title, summary: nil, actionLabel: nil)
}

/// Desktop `ui-chat` `image.loading` / `image.failed`.
public func messageImageLoading(english: Bool) -> String {
    english ? "Loading image…" : "加载图片…"
}

public func messageImageFailed(english: Bool) -> String {
    english ? "Image preview unavailable" : "图片无法预览"
}

/// Desktop `ui-chat` `ModelRetryItem` label: active uses `retry.active`.
public func retryAttemptLabel(state: RetryState, active: Bool, english: Bool) -> String {
    if active { return english ? "Retrying model request" : "正在重试模型请求" }
    switch state {
    case .cancelled: return english ? "Model request retry cancelled" : "模型请求重试已取消"
    case .started: return english ? "Retried model request" : "已重试模型请求"
    case .scheduled: return english ? "Waiting to retry model request" : "等待重试模型请求"
    }
}

/// Desktop `duration.milliseconds`.
public func retryDelayMilliseconds(delayMs: Int64, english: Bool) -> String {
    english ? "\(delayMs)ms" : "\(delayMs)毫秒"
}

public func retryAttemptIsActive(state: RetryState, isLast: Bool) -> Bool {
    state == .scheduled && isLast
}

/// Desktop `TurnErrorItem` title: signed-out and interrupted share `message.taskStopped`.
public func turnFailureTitle(code: String?, english: Bool) -> String {
    if code == "ACCOUNT_SIGNED_OUT" || code == "INTERRUPTED" {
        return english ? "Task stopped" : "任务已停止"
    }
    return english ? "This turn failed" : "本轮运行失败"
}

/// Desktop `TurnErrorItem` hides the `INTERRUPTED` code chip.
public func turnFailureShowsCode(_ code: String?) -> Bool {
    guard let code, !code.isEmpty else { return false }
    return code != "INTERRUPTED"
}

/// Desktop `ui-deliverables` `diff.*` notices on the review surface.
public enum ChangesDiffNotice: String, Equatable, Sendable {
    case missing, binary, oversized, created, deleted, unchanged, coarse
}

public func changesDiffNoticeKind(_ diff: WorkspaceFileDiff?) -> ChangesDiffNotice? {
    guard let diff else { return .missing }
    if diff.kind == "binary" { return .binary }
    if diff.kind == "oversized" { return .oversized }
    if !diff.before { return .created }
    if !diff.after { return .deleted }
    if diff.coarse { return .coarse }
    if diff.hunks.isEmpty { return .unchanged }
    return nil
}

public func changesDiffNoticeLabel(_ kind: ChangesDiffNotice, english: Bool) -> String {
    switch kind {
    case .missing:
        return english
            ? "The contents of this turn’s changes are no longer available"
            : "这轮改动的内容已不可用"
    case .binary:
        return english ? "Binary file; changes cannot be shown" : "二进制文件，无法显示改动"
    case .oversized:
        return english ? "File too large; changes cannot be shown" : "文件过大，无法显示改动"
    case .created:
        return english ? "Created in this turn" : "本轮新建的文件"
    case .deleted:
        return english ? "Deleted in this turn" : "本轮删除的文件"
    case .unchanged:
        return english ? "Both sides hold the same lines" : "两侧内容相同"
    case .coarse:
        return english
            ? "Line comparison timed out; shown as a whole-file replacement"
            : "逐行对比超时，按整个文件替换显示"
    }
}

public func changesDiffTruncatedLabel(count: Int, english: Bool) -> String {
    english ? "Showing the first \(count) lines" : "只显示前 \(count) 行"
}

/// Collapse stores the tool `callId` so `AskQuestionRow` can match the transcript row.
public func userQuestionCollapseId(questionId: String, callId: String?) -> String {
    callId ?? questionId
}

public func userQuestionIsCollapsed(questionId: String, callId: String?, hiddenId: String?) -> Bool {
    guard let hiddenId, !hiddenId.isEmpty else { return false }
    if hiddenId == questionId { return true }
    if let callId, hiddenId == callId { return true }
    return false
}

/// Desktop hero is a blank Host session, so `addFiles` is wired. iOS landing
/// has no session: keep local draft files and upload after `sessions.create`.
public let landingAllowsDraftFileAttachments = true
public let landingFileAttachRequiresSession = false

/// Desktop `ConversationSessionHeader` `deriveAncestry`: walk parents while
/// `origin === "subagent"`. A regular session is a single current crumb.
public struct ConversationHeaderCrumb: Equatable, Sendable {
    public var sessionId: String
    public var title: String
    public var subagent: Bool
    public var current: Bool

    public init(sessionId: String, title: String, subagent: Bool, current: Bool) {
        self.sessionId = sessionId
        self.title = title
        self.subagent = subagent
        self.current = current
    }
}

public func conversationHeaderAncestry(
    sessions: [SessionSummary],
    sessionId: String?,
    currentTitle: String,
    newSession: String,
    untitled: String
) -> [ConversationHeaderCrumb] {
    guard let sessionId else { return [] }
    var chain: [(id: String, title: String, subagent: Bool)] = []
    var seen = Set<String>()
    var cursor: String? = sessionId
    while let id = cursor {
        if seen.contains(id) { break }
        seen.insert(id)
        let summary = sessions.first { $0.sessionId == id }
        let subagent = summary?.origin == "subagent"
        let title: String
        if id == sessionId {
            title = currentTitle
        } else {
            title = drawerSessionTitle(
                summary ?? SessionSummary(sessionId: id),
                current: sessionId,
                newSession: newSession,
                untitled: untitled
            )
        }
        chain.insert((id, title, subagent), at: 0)
        if !subagent { break }
        cursor = summary?.parentSessionId
    }
    return chain.enumerated().map { index, item in
        ConversationHeaderCrumb(
            sessionId: item.id,
            title: item.title,
            subagent: item.subagent,
            current: index == chain.count - 1
        )
    }
}

/// Drawer hides subagent rows; the header still shows crumbs when the current
/// session is a subagent (desktop `session.hierarchy`).
public func conversationHeaderShowsCrumbs(_ crumbs: [ConversationHeaderCrumb]) -> Bool {
    crumbs.count > 1
}

/// Desktop `conversation` `session.hierarchy`.
public func sessionHierarchyAria(english: Bool) -> String {
    english ? "Session hierarchy" : "会话层级"
}

/// Desktop `ui-commands` `status.loading` / `status.empty`.
public func commandMenuStatusLoading(english: Bool) -> String {
    english ? "Loading options…" : "正在加载选项…"
}

public func commandMenuStatusEmpty(english: Bool) -> String {
    english ? "No options" : "无选项"
}

/// Desktop `ui-agent-preset` `seatHint` / `noDescription`.
public func agentPresetSeatHint(english: Bool) -> String {
    english ? "Choose the agent preset for your new task" : "选择新任务使用的 Agent 预设"
}

public func agentPresetNoDescription(english: Bool) -> String {
    english ? "No description." : "暂无描述。"
}

/// Desktop `ui-plugin-manager` add-plugin menu (not a system confirmationDialog).
public func pluginAddInstallExisting(english: Bool) -> String {
    english ? "Install a third-party plugin" : "安装第三方插件"
}

public func pluginAddInstallExistingDescription(english: Bool) -> String {
    english ? "Supports npm packages, Git repositories, and local directories" : "支持 npm 包、Git 仓库和本地目录"
}

public func pluginAddCreatePlugin(english: Bool) -> String {
    english ? "Let the agent create a plugin" : "让 Agent 创建插件"
}

public func pluginAddChooseMethod(english: Bool) -> String {
    english ? "Choose how to add a plugin" : "选择添加插件方式"
}

public func pluginAddCreatePluginDescription(english: Bool) -> String {
    english ? "Enter Creator mode and make your own DSH plugin" : "进入创造模式，制作属于你的 DSH 插件"
}

public func pluginAddCreatePluginChecking(english: Bool) -> String {
    english ? "Checking whether Creator mode is available" : "正在确认创造模式是否可用"
}

public func pluginAddCreatePluginUnavailable(english: Bool) -> String {
    english ? "Temporarily unavailable. Reopen this menu to retry" : "暂时不可用，请重新打开菜单重试"
}

public func pluginAddCreatePluginMissing(english: Bool) -> String {
    english ? "Creator mode is not included in this configuration" : "当前配置未提供创造模式"
}

public let pluginAddMenuUsesMenuSurface = true
