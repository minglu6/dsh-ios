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

public func sidebarCompletionUnreadLabel(english: Bool) -> String {
    english ? "Completed, unread" : "已完成，未查看"
}

public func sidebarRunningLabel(english: Bool) -> String {
    english ? "Running" : "运行中"
}

public func sidebarAwaitingApprovalLabel(english: Bool) -> String {
    english ? "Waiting for approval" : "等待审批"
}

public func sidebarAwaitingAnswerLabel(english: Bool) -> String {
    english ? "Waiting for answer" : "等待回答"
}
