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

/// Desktop `ui-settings-general` `SettingsRoot` `triggerRow` is one flex row:
/// Settings (`IconSettingsOutlineMedium` 16 + `settings.trigger`) then the
/// trailing action (`ConnectionIndicator`). Phone maps the Host switcher to
/// that trailing seat — not a full-width row above Settings.
/// `SidebarRoot` still lists `sidebar.footer.action` above `sidebar.settings`,
/// but that seat is empty on a stock Host; the visible foot is the trigger row.
public let sidebarFooterActionAboveSettings = false
public let sidebarFooterActionSharesSettingsRow = true
public let sidebarSettingsTriggerIconSizePoints: Double = 16
public let sidebarSettingsTriggerHeightPoints: Double = 42
public let sidebarSettingsTriggerGapPoints: Double = 8
public let sidebarSettingsTriggerFontSizePoints: Double = 14
public let sidebarFooterActionButtonPoints: Double = 28
public let sidebarFooterActionIconSizePoints: Double = 16

/// Desktop `SettingsRoot` / `TriggerContent` uses `IconSettingsOutlineMedium`,
/// never SF `gearshape`. Artwork is `ui-primitives` `IconSettingsOutlineArtwork`
/// on a 16×16 view box; Medium stroke is `ICON_MEDIUM_STROKE` 1.3.
public let sidebarSettingsTriggerUsesOfficialGlyph = true
public let sidebarSettingsTriggerIconStrokeWidth: Double = 1.3

public func sidebarSettingsTriggerSymbol() -> String { "official.settingsOutline" }

public func isForbiddenSystemSettingsSymbol(_ name: String) -> Bool {
    name == "gearshape" || name == "gearshape.fill"
}

/// Desktop `ui-sidebar` header / `SidebarRoot` (narrow) and `ui-workspace`
/// workspace-row new-session use `IconNewChatOutlineRegular`, never SF
/// `square.and.pencil`. Artwork is `ui-primitives` `NewChatOutlineArtwork`
/// on a 16×16 view box; Regular stroke is `ICON_REGULAR_STROKE` 1.
public let sidebarNewChatUsesOfficialGlyph = true
public let sidebarNewChatIconSizePoints: Double = 16
public let sidebarNewChatIconStrokeWidth: Double = 1

public func sidebarNewChatSymbol() -> String { "official.newChat" }

public func isForbiddenSystemNewChatSymbol(_ name: String) -> Bool {
    name == "square.and.pencil"
}

/// Desktop `NewChatOutlineArtwork` bubble (`d` of the first `<path>`).
public let sidebarNewChatBubblePath =
    "M2.37091 11.2501C1.58745 9.89288 1.32067 8.29835 1.61969 6.76006C1.91872 5.22177 2.76342 3.8433 3.99826 2.87846C5.2331 1.91362 6.77494 1.42737 8.33988 1.50925C9.90482 1.59113 11.3875 2.23562 12.5149 3.32406C13.6425 4.41269 14.3387 5.87206 14.4754 7.4334C14.612 8.99474 14.18 10.5529 13.2587 11.8209C12.3375 13.0888 10.9891 13.9813 9.46194 14.3337C8.18691 14.628 6.85895 14.5294 5.64989 14.0605C5.1712 13.8748 4.76962 13.4932 4.26534 13.3967C3.67413 13.2835 2.95257 13.5598 2.03794 14.3337"

/// Desktop `NewChatOutlineArtwork` plus stem / bar.
public let sidebarNewChatPlusVerticalPath = "M8 5V11"
public let sidebarNewChatPlusHorizontalPath = "M5 8H11"

/// Desktop `ui-workspace` `WorkspaceBrowser` search uses
/// `IconSearchOutlineRegular`, never SF `magnifyingglass`. Artwork is
/// `ui-primitives` `IconSearchOutlineArtwork` on a 16×16 view box; Regular
/// stroke is `ICON_REGULAR_STROKE` 1. Wide header idle button is 14; the
/// expanded-slot 11 is a desktop squeeze. Phone keeps the already-approved
/// persistent field and uses the idle button size.
public let sidebarSearchUsesOfficialGlyph = true
public let sidebarSearchIconSizePoints: Double = 14
public let sidebarSearchIconStrokeWidth: Double = 1

public func sidebarSearchSymbol() -> String { "official.searchOutline" }

public func isForbiddenSystemSearchSymbol(_ name: String) -> Bool {
    name == "magnifyingglass"
}

/// Desktop `IconSearchOutlineArtwork` lens (`d` of the first `<path>`).
public let sidebarSearchCirclePath =
    "M6.58727 11.8586C9.55061 11.8586 11.9529 9.45637 11.9529 6.49304C11.9529 3.5297 9.55061 1.12744 6.58727 1.12744C3.62394 1.12744 1.22168 3.5297 1.22168 6.49304C1.22168 9.45637 3.62394 11.8586 6.58727 11.8586Z"

/// Desktop `IconSearchOutlineArtwork` handle (`d` of the second `<path>`).
public let sidebarSearchHandlePath = "M10.2991 10.3933L14.7783 14.8725"

/// Desktop `ui-workspace` `WorkspaceBrowser` header add uses
/// `IconProjectAddOutlineRegular`, never SF `plus`. Artwork is
/// `ui-primitives` `IconProjectAddOutlineArtwork` on a 16×16 view box:
/// filled folder + Regular-stroke plus (`ICON_REGULAR_STROKE` 1). Wide
/// header is 16; the narrow 18 is a rail squeeze. Phone maps to the wide
/// column. Trigger is desktop `.iconButton` 28×28.
public let sidebarProjectAddUsesOfficialGlyph = true
public let sidebarProjectAddIconSizePoints: Double = 16
public let sidebarProjectAddIconStrokeWidth: Double = 1
public let sidebarProjectAddButtonPoints: Double = 28

public func sidebarProjectAddSymbol() -> String { "official.projectAdd" }

public func isForbiddenSystemProjectAddSymbol(_ name: String) -> Bool {
    name == "plus"
}

/// Desktop `IconProjectAddOutlineArtwork` folder (`d` of the first `<path>`, fill).
public let sidebarProjectAddFolderPath =
    "M5.54492 2.06738C5.91034 2.06754 6.26318 2.20149 6.53711 2.44336L7.94043 3.68164V4.7998C7.71462 4.74105 7.50367 4.63139 7.32617 4.47461L5.87598 3.19238C5.78477 3.11185 5.66658 3.06754 5.54492 3.06738H2.94922C2.67322 3.06738 2.44946 3.29145 2.44922 3.56738V12.4326C2.44927 12.7087 2.67311 12.9326 2.94922 12.9326H12.9326C13.2086 12.9325 13.4326 12.7086 13.4326 12.4326V8.53613H14.4326V12.4326C14.4326 13.2609 13.7609 13.9325 12.9326 13.9326H2.94922C2.12083 13.9326 1.44927 13.261 1.44922 12.4326V3.56738C1.44946 2.73916 2.12094 2.06738 2.94922 2.06738H5.54492Z"

/// Desktop `IconProjectAddOutlineArtwork` plus bar / stem.
public let sidebarProjectAddPlusHorizontalPath = "M9.75977 4.50208H14.5509"
public let sidebarProjectAddPlusVerticalPath = "M12.1492 6.89758L12.1492 2.10642"

/// Desktop `IconSettingsOutlineArtwork` hub circle (`d` of the first `<path>`).
public let sidebarSettingsOutlineHubPath =
    "M8 9.75012C8.9665 9.75012 9.75 8.96662 9.75 8.00012C9.75 7.03362 8.9665 6.25012 8 6.25012C7.0335 6.25012 6.25 7.03362 6.25 8.00012C6.25 8.96662 7.0335 9.75012 8 9.75012Z"

/// Desktop `IconSettingsOutlineArtwork` gear ring (`d` of the second `<path>`).
public let sidebarSettingsOutlineRingPath =
    "M13.0107 7.79377C12.9505 7.89401 12.9205 7.94413 12.9205 7.99951C12.9205 8.0549 12.9505 8.10502 13.0106 8.20528L13.9849 9.83006C14.045 9.93029 14.0751 9.9804 14.0751 10.0358C14.0751 10.0911 14.045 10.1413 13.9849 10.2415L13.0037 11.8777C12.9468 11.9726 12.9184 12.0201 12.8725 12.0461C12.8267 12.072 12.7713 12.072 12.6607 12.072H10.6704C10.5598 12.072 10.5045 12.072 10.4586 12.098C10.4128 12.1239 10.3843 12.1714 10.3274 12.2662L9.33825 13.9142C9.28133 14.009 9.25287 14.0564 9.20703 14.0823C9.16118 14.1083 9.10588 14.1083 8.99529 14.1083H7.00486C6.89426 14.1083 6.83896 14.1083 6.79312 14.0823C6.74727 14.0564 6.71881 14.009 6.6619 13.9142L5.67273 12.2662C5.61581 12.1714 5.58735 12.1239 5.54151 12.098C5.49566 12.072 5.44036 12.072 5.32977 12.072H3.33945C3.2288 12.072 3.17347 12.072 3.12761 12.0461C3.08176 12.0201 3.0533 11.9726 2.9964 11.8777L2.0152 10.2415C1.9551 10.1413 1.92505 10.0911 1.92505 10.0358C1.92505 9.9804 1.9551 9.93029 2.0152 9.83006L2.98951 8.20528C3.04963 8.10502 3.07969 8.0549 3.07969 7.99951C3.07968 7.94413 3.04961 7.89401 2.98946 7.79377L2.01529 6.17011C1.95514 6.06987 1.92507 6.01975 1.92507 5.96437C1.92506 5.90899 1.95512 5.85886 2.01524 5.7586L2.9964 4.1224C3.0533 4.0275 3.08176 3.98005 3.12761 3.95408C3.17347 3.92811 3.2288 3.92811 3.33945 3.92811H5.32977C5.44036 3.92811 5.49566 3.92811 5.54151 3.90216C5.58735 3.87621 5.61581 3.82879 5.67273 3.73397L6.6619 2.08599C6.71881 1.99116 6.74727 1.94375 6.79312 1.9178C6.83896 1.89185 6.89426 1.89185 7.00486 1.89185H8.99529C9.10588 1.89185 9.16118 1.89185 9.20703 1.9178C9.25287 1.94375 9.28133 1.99116 9.33825 2.08599L10.3274 3.73397C10.3843 3.82879 10.4128 3.87621 10.4586 3.90216C10.5045 3.92811 10.5598 3.92811 10.6704 3.92811H12.6607C12.7713 3.92811 12.8267 3.92811 12.8725 3.95408C12.9184 3.98005 12.9468 4.0275 13.0037 4.1224L13.9849 5.7586C14.045 5.85886 14.0751 5.90899 14.0751 5.96437C14.0751 6.01975 14.045 6.06987 13.9849 6.17011L13.0107 7.79377Z"

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

/// Composer model name takes leftover toolbar width; effort / chevron stay intrinsic.
public let composerModelNameUsesRemainingWidth = true

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

/// Desktop `PermissionSelect` trigger shows icon + label. Phone composer is
/// too narrow; the toolbar keeps the icon (and chevron), the menu keeps labels.
/// User-confirmed narrow-screen adaptation — do not restore the chip label.
public let permissionChipTriggerShowsLabel = false

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

// MARK: - CompactionItem (desktop ui-chat CompactionItem)

/// Desktop `message.compaction` / `message.compaction.commandTitle`.
public func compactionRowTitle(sourceCommandId: String?, english: Bool) -> String {
    if sourceCommandId != nil {
        return "compact"
    }
    return english ? "Context compacted" : "上下文已压缩"
}

/// Desktop CompactionItem summary line. Counts require both fields; otherwise
/// `fallbackSummary`, else expand copy when a body exists, else unavailable.
public func compactionRowSummary(
    shadowedItemCount: Int?,
    shadowedTokenCount: Int?,
    fallbackSummary: String?,
    hasSummary: Bool,
    english: Bool
) -> String {
    if let items = shadowedItemCount, let tokens = shadowedTokenCount {
        return english
            ? "Compacted \(items) history items (~\(tokens) tokens)"
            : "已压缩 \(items) 条历史记录（约 \(tokens) tokens）"
    }
    if let fallbackSummary, !fallbackSummary.isEmpty {
        return fallbackSummary
    }
    if hasSummary {
        return english ? "View compaction summary" : "点击查看压缩摘要"
    }
    return english ? "Compaction summary unavailable" : "压缩摘要不可用"
}

public func compactionRowSummary(item: Item.Compacted, english: Bool) -> String {
    compactionRowSummary(
        shadowedItemCount: item.shadowedItemCount,
        shadowedTokenCount: item.shadowedTokenCount,
        fallbackSummary: item.commandOutcomeText,
        hasSummary: item.summary != nil,
        english: english
    )
}

/// Desktop `compactionDefinition.buildViewNode` is null until the checkpoint
/// lands. Manual `/compact` (`sourceCommandId`) is owned by `commandDefinition`;
/// CompactionItem only appears via `CompactionCommandCard` after the checkpoint.
/// Automatic in-flight `compaction/start` without summary/counts stays hidden.
/// Settled automatic markers (end, summary, or counts) still render if the
/// checkpoint event is outside the window.
public func compactionItemIsVisible(_ item: Item.Compacted) -> Bool {
    if item.sourceCommandId != nil { return item.hasCheckpoint }
    if item.hasCheckpoint { return true }
    if item.status != .running { return true }
    if item.summary != nil { return true }
    if item.shadowedItemCount != nil && item.shadowedTokenCount != nil { return true }
    return false
}

/// Desktop `isVisibleChatNode` hides `/permission`. `CompactionCommandCard`
/// replaces the generic card with CompactionItem once a checkpoint exists.
public func commandItemIsVisible(_ item: Item.Command, compactCheckpointCommandIds: Set<String>) -> Bool {
    if item.name == "permission" { return false }
    if item.name == "compact", compactCheckpointCommandIds.contains(item.commandId) {
        return false
    }
    return true
}

/// Desktop `GenericCommandCard` title: `node.name ?? command.title`.
public func commandRowTitle(_ item: Item.Command, english: Bool) -> String {
    item.name ?? (english ? "Command" : "指令")
}

/// Desktop `GenericCommandCard` / `CompactionCommandCard` summary line.
public func commandRowSummary(_ item: Item.Command, english: Bool) -> String {
    if item.outcomeKind == nil {
        if item.name == "compact" {
            return english ? "Compacting context…" : "正在压缩…"
        }
        return english ? "Running…" : "执行中…"
    }
    if let text = item.outcomeText { return text }
    return item.outcomeKind == .error
        ? (english ? "Command failed" : "指令失败")
        : (english ? "Completed" : "已完成")
}

public func commandRowIsRunning(_ item: Item.Command) -> Bool {
    item.outcomeKind == nil
}

public func commandRowIsError(_ item: Item.Command) -> Bool {
    item.outcomeKind == .error
}

/// Desktop expands only when `outcome.text` contains a newline.
public func commandRowIsExpandable(_ item: Item.Command) -> Bool {
    item.outcomeText?.contains("\n") == true
}

/// Desktop visually-hidden `row.running` / `row.failed`.
public func commandRowStateLabel(_ item: Item.Command, english: Bool) -> String? {
    if commandRowIsRunning(item) { return english ? "Running" : "运行中" }
    if commandRowIsError(item) { return english ? "Failed" : "失败" }
    return nil
}

public func compactCheckpointCommandIds(in items: [Item]) -> Set<String> {
    Set(items.compactMap { item -> String? in
        guard case .compacted(let compacted) = item, compacted.hasCheckpoint else { return nil }
        return compacted.sourceCommandId
    })
}

public func compactionRowIsExpandable(_ item: Item.Compacted) -> Bool {
    item.summary != nil
}

/// Desktop `compactSummary`: `data.summary` is an array of text blocks joined
/// with no separator. Non-arrays are not a summary.
public func compactionSummaryText(from summary: JSONValue) -> String? {
    guard let blocks = summary.arr() else { return nil }
    let text = blocks.map { block in
        block["type"].str() == "text" ? (block["text"].str() ?? "") : ""
    }.joined()
    return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
}

/// Desktop: `shadowedSeqs` must be an array of non-negative safe integers.
public func compactionShadowedItemCount(from data: JSONValue) -> Int? {
    guard let seqs = data["shadowedSeqs"].arr() else { return nil }
    for seq in seqs {
        guard let value = seq.long(), value >= 0 else { return nil }
    }
    return seqs.count
}

public func compactionShadowedTokenCount(from data: JSONValue) -> Int? {
    guard let value = data["shadowedTokenCount"].long(), value >= 0 else { return nil }
    return Int(value)
}

/// Desktop `isCompactionCheckpoint`: replacement `user/message` whose source
/// kind is `compact-checkpoint`. `surfaceOp` must be present and not `append`.
public func isCompactionCheckpoint(event: JSONValue, data: JSONValue) -> Bool {
    guard event["type"].str() == "user/message" else { return false }
    guard let op = event["surfaceOp"].str(), op != "append" else { return false }
    return compactionCheckpointId(from: data) != nil
}

public func compactionCheckpointId(from data: JSONValue) -> String? {
    let source = compactionMessageSource(data)
    guard source["kind"].str() == "compact-checkpoint" else { return nil }
    let id = source["compactionId"].str()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return id.isEmpty ? nil : id
}

public func compactionCheckpointCommandId(from data: JSONValue) -> String? {
    guard let value = compactionMessageSource(data)["sourceCommandId"].str()?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else { return nil }
    return value
}

private func compactionMessageSource(_ data: JSONValue) -> JSONValue {
    let msg = data["content"].isNull && data["message"].obj() != nil ? data["message"] : data
    return msg["source"].isNull ? data["source"] : msg["source"]
}

// MARK: - ContextInjectionRow tool-change chrome (desktop ui-chat isVisibleChatNode)

/// Desktop `dsh-llm` `ContentBlock` text / `tool-addition` / `tool-removal`.
public func contextContentBlocks(_ blocks: [JSONValue]) -> (text: String, added: [String], removed: [String]) {
    var texts: [String] = []
    var added: [String] = []
    var removed: [String] = []
    for block in blocks {
        switch block["type"].str() {
        case "text":
            texts.append(block["text"].str() ?? "")
        case "tool-addition":
            if let name = block["toolName"].str()?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                added.append(name)
            }
        case "tool-removal":
            if let name = block["toolName"].str()?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                removed.append(name)
            }
        default:
            break
        }
    }
    return (texts.joined(separator: "\n"), added, removed)
}

/// Desktop `isVisibleChatNode`: ordinary Context is hidden; tool-change blocks stay.
public func contextHasToolChanges(_ item: Item.Context) -> Bool {
    !item.toolAdditions.isEmpty || !item.toolRemovals.isEmpty
}

public func contextItemIsVisible(_ item: Item.Context) -> Bool {
    item.waking || contextHasToolChanges(item)
}

/// Desktop `ContextInjectionRow` uses tool chrome when every block is add/remove.
public func contextToolChangeIsExclusive(_ item: Item.Context) -> Bool {
    contextHasToolChanges(item)
        && item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

/// Desktop `message.toolAdded` / `message.toolRemoved` / `message.toolsUpdated`.
public func contextToolChangeTitle(added: [String], removed: [String], english: Bool) -> String {
    if added.count == 1 && removed.isEmpty {
        return english ? "Tool added: \(added[0])" : "已添加工具：\(added[0])"
    }
    if removed.count == 1 && added.isEmpty {
        return english ? "Tool removed: \(removed[0])" : "已移除工具：\(removed[0])"
    }
    return english ? "Tools updated" : "工具已更新"
}

public func contextToolChangeTitle(item: Item.Context, english: Bool) -> String {
    contextToolChangeTitle(added: item.toolAdditions, removed: item.toolRemovals, english: english)
}

/// Desktop `message.contextInjection` when Context is visible but not exclusive tool-change blocks.
public func contextInjectionTitle(english: Bool) -> String {
    english ? "Context injection" : "上下文注入"
}

/// Desktop `dsh-llm` `SessionReferenceSource` / ui-chat `sessionRecallLabels`.
/// Ordinary recall Context stays hidden (`isVisibleChatNode`); labels land on the user bubble.
public func sessionRecallLabels(source: JSONValue) -> [String] {
    guard source["kind"].str() == "session-reference" else { return [] }
    var seen: [String] = []
    for entry in source["references"].arr() ?? [] {
        guard let label = entry["label"].str()?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else {
            continue
        }
        if !seen.contains(label) { seen.append(label) }
    }
    return seen
}

/// Desktop `ReferenceLabelProjector`: recall context at `seq` labels the user at `seq - 1`.
public func applyingUserReferenceLabels(_ items: [Item]) -> [Item] {
    var labelsByUserSeq: [Int64: [String]] = [:]
    for item in items {
        guard case .context(let ctx) = item, let seq = ctx.seq else { continue }
        let labels = ctx.recallLabels
        if labels.isEmpty { continue }
        labelsByUserSeq[seq - 1] = labels
    }
    return items.map { item in
        guard case .user(var user) = item, let seq = user.seq, let labels = labelsByUserSeq[seq], !labels.isEmpty else {
            return item
        }
        user.referenceLabels = labels
        return .user(user)
    }
}

/// Desktop `message.referenceSummary` + `message.referenceSeparator`.
public func referenceSummaryText(labels: [String], english: Bool) -> String? {
    guard !labels.isEmpty else { return nil }
    let joined = labels.joined(separator: english ? ", " : "、")
    return english ? "Referenced session · \(joined)" : "引用会话 · \(joined)"
}

/// Desktop `ui-chat` `fileOpen.title`. English apostrophe is U+2019.
public func fileOpenTitle(english: Bool) -> String {
    english ? "Couldn\u{2019}t open file" : "无法打开文件"
}

/// Desktop `ui-chat` `fileOpen.unknown`.
public func fileOpenUnknown(english: Bool) -> String {
    english ? "Couldn\u{2019}t open this file" : "无法打开此文件"
}

/// Desktop `sidebarPdf` `failed`.
public func pdfFailedMessage(_ message: String, english: Bool) -> String {
    english ? "Cannot display PDF: \(message)" : "无法显示 PDF：\(message)"
}

/// PDFKit `PDFDocument` is nil with no engine `Error`; interpolate `fileOpen.title`.
public func pdfDocumentOpenFailed(english: Bool) -> String {
    pdfFailedMessage(fileOpenTitle(english: english), english: english)
}

public func contextRowTitle(item: Item.Context, english: Bool) -> String {
    if contextToolChangeIsExclusive(item) {
        return contextToolChangeTitle(item: item, english: english)
    }
    return contextInjectionTitle(english: english)
}

/// Desktop collapsed summary: counts only when there is more than one tool-change block.
public func contextToolChangeSummary(added: [String], removed: [String], english: Bool) -> String? {
    if added.count + removed.count <= 1 { return nil }
    if !added.isEmpty && !removed.isEmpty {
        return english
            ? "\(added.count) added, \(removed.count) removed"
            : "新增 \(added.count) 个，移除 \(removed.count) 个"
    }
    if !added.isEmpty {
        return english ? "\(added.count) added" : "新增 \(added.count) 个"
    }
    return english ? "\(removed.count) removed" : "移除 \(removed.count) 个"
}

public func contextToolChangeSummary(item: Item.Context, english: Bool) -> String? {
    contextToolChangeSummary(added: item.toolAdditions, removed: item.toolRemovals, english: english)
}

public func contextToolChangeIsExpandable(added: [String], removed: [String]) -> Bool {
    added.count + removed.count > 1
}

public func contextToolChangeAddedLine(names: [String], english: Bool) -> String? {
    if names.isEmpty { return nil }
    let joined = names.joined(separator: ", ")
    return english ? "Added: \(joined)" : "新增：\(joined)"
}

public func contextToolChangeRemovedLine(names: [String], english: Bool) -> String? {
    if names.isEmpty { return nil }
    let joined = names.joined(separator: ", ")
    return english ? "Removed: \(joined)" : "移除：\(joined)"
}

// MARK: - TurnMaxTokensItem / stopped notice (desktop ui-chat MessageItem)

/// Desktop `message.maxTokens`.
public func maxTokensTitle(english: Bool) -> String {
    english ? "Output token limit reached" : "已达到输出 token 上限"
}

/// Desktop `message.maxTokens.hint`.
public func maxTokensHint(english: Bool) -> String {
    english
        ? "The reply was cut off; earlier output is preserved in the conversation. Send \"continue\" to let the model resume."
        : "回答被截断，已有输出保留在对话中。发送“继续”可让模型接着输出。"
}

/// Desktop `message.stopped`.
public func messageStopped(english: Bool) -> String {
    english ? "Stopped" : "已停止"
}

// MARK: - First landing prompt (desktop pending echo; Android `FirstPrompt`)

/// First send from a phone landing that has no Host session yet.
/// Desktop already has a blank session, so the same identity is a local echo
/// (`Item.User.pending` / `TranscriptReducer.echo`) until `user/message` confirms.
public struct FirstPrompt: Equatable, Sendable {
    public var requestId: String
    public var text: String
    public var images: Int
    public var files: Int
    public var error: String?

    public init(
        requestId: String,
        text: String,
        images: Int = 0,
        files: Int = 0,
        error: String? = nil
    ) {
        self.requestId = requestId
        self.text = text
        self.images = images
        self.files = files
        self.error = error
    }
}

/// Same key as `TranscriptReducer.addEcho` so the row identity survives
/// landing → `initializeChat` seed.
public func firstPromptPendingItem(_ prompt: FirstPrompt) -> Item {
    .user(Item.User(
        key: "local-\(prompt.requestId)",
        text: prompt.text,
        images: prompt.images,
        pending: true,
        requestId: prompt.requestId
    ))
}

/// Prefer the live transcript (seeded echo) once the session exists.
public func firstPromptVisibleItems(chatItems: [Item], prompt: FirstPrompt?) -> [Item] {
    if !chatItems.isEmpty { return chatItems }
    guard let prompt else { return [] }
    return [firstPromptPendingItem(prompt)]
}

/// Desktop `conversation` `queue.sending`. Shown while create/prompt is in flight
/// because the queue dock does not exist until the session exists.
public func firstPromptSendingLabel(english: Bool) -> String {
    english ? "Sending…" : "发送中…"
}

public func firstPromptBlocksComposerActions(_ prompt: FirstPrompt?) -> Bool {
    prompt != nil
}

public func noticeChatTitle(_ notice: Item.Notice, english: Bool) -> String {
    switch notice.kind {
    case .maxTokens: return maxTokensTitle(english: english)
    case .stopped: return messageStopped(english: english)
    case .generic: return notice.text
    }
}
