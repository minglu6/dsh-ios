import Foundation

/// Desktop `ui-chat` `ChatGroupSeat` `PROCESS_ICONS` + `ToolRow` / `toolProcessSummary`
/// icon mapping onto `@deepseek-ai/dsh-client-ui-primitives@0.2.1-alpha.5`.
/// Phone must not invent SF stand-ins when these artworks exist.

/// Desktop `PROCESS_ICONS` keys plus `toolActivityKind` / thinking.
public let chatProcessOfficialKinds = [
    "thinking", "read", "readImage", "webFetch", "search", "edit", "write",
    "commands", "code", "webSearch", "subagents", "plan", "questions", "tools",
]

public func chatProcessOfficialSymbol(_ kind: String) -> String {
    switch kind {
    case "thinking": return "official.think"
    case "read", "readImage", "webFetch": return "official.browseOutline"
    case "search": return "official.searchOutline"
    case "edit", "write": return "official.editOutline"
    case "commands": return "official.apiOutline"
    case "code": return "official.codeOutline"
    case "webSearch": return "official.globeOutline"
    case "subagents": return "official.agentPreset"
    case "plan": return "official.planOutline"
    case "questions": return "official.questionOutline"
    case "tools": return "official.sparkle"
    default:
        preconditionFailure("chatProcessOfficialSymbol unknown PROCESS_ICONS kind \(kind)")
    }
}

public func toolProcessOfficialSymbol(_ icon: ToolProcessIcon) -> String {
    switch icon {
    case .browse: return "official.browseOutline"
    case .search: return "official.searchOutline"
    case .command: return "official.apiOutline"
    case .write, .edit: return "official.editOutline"
    case .code: return "official.codeOutline"
    case .generic: return "official.sparkle"
    case .users: return "official.usersOutline"
    case .checklist: return "official.checklistOutline"
    case .clock: return "official.clockOutline"
    case .goal: return "official.goalOutline"
    case .plugin: return "official.cordisPlugin"
    case .agent: return "official.agentPreset"
    case .branch: return "official.branchOutline"
    }
}

public func isForbiddenChatToolSystemSymbol(_ name: String) -> Bool {
    name == "doc.text.magnifyingglass"
        || name == "magnifyingglass"
        || name == "pencil"
        || name == "terminal"
        || name == "chevron.left.forwardslash.chevron.right"
        || name == "person.2"
        || name == "checklist"
        || name == "clock"
        || name == "target"
        || name == "puzzlepiece.extension"
        || name == "person.crop.circle"
        || name == "arrow.triangle.branch"
        || name == "sparkle"
        || name == "sparkles"
        || name == "brain"
        || name == "questionmark.circle"
}

/// Desktop `IconBrowseOutlineArtwork` Regular exported as a template PDF so
/// SwiftUI `Text(Image)` markdown file chips can paint `ReferenceIconRegular`.
public let markdownFileChipAssetName = "officialBrowseOutline"

/// XCUI identifier for an inline markdown file chip. Catalog names inside
/// `Text(Image)` attachments are not exposed as XCUI images, so the wrapping
/// paragraph advertises this identifier instead.
public let markdownFileChipAccessibilityIdentifier = "official.markdownFileChip"

/// Desktop `IconBrowseOutlineArtwork` Regular: two caption strokes + filled page.
public let chatBrowseCaptionTopPath = "M4.9375 5.90295H11.0625"
public let chatBrowseCaptionMidPath = "M4.9375 9.02991H8.27841"
public let chatBrowsePagePath =
    "M12.5 1.32617C13.3039 1.32617 14 1.95171 14 2.77637V13.2246C13.9996 14.0489 13.3036 14.6738 12.5 14.6738H3.5C2.69637 14.6738 2.00042 14.0489 2 13.2246V2.77637C2 1.95171 2.69613 1.32617 3.5 1.32617H12.5ZM3.5 2.32617C3.1993 2.32617 3 2.55186 3 2.77637V13.2246C3.00044 13.4489 3.19963 13.6738 3.5 13.6738H12.5C12.8004 13.6738 12.9996 13.4489 13 13.2246V2.77637C13 2.55186 12.8007 2.32617 12.5 2.32617H3.5Z"

/// Desktop `IconEditOutlineArtwork` Regular.
public let chatEditPagePath =
    "M8.85596 2.69971H4.19971C3.37141 2.69971 2.69992 3.37146 2.69971 4.19971V11.8003C2.69992 12.6285 3.37141 13.3003 4.19971 13.3003H11.8003C12.6283 13.2999 13.3001 12.6283 13.3003 11.8003V7.89893H14.3003V11.8003C14.3001 13.1806 13.1806 14.2999 11.8003 14.3003H4.19971C2.81913 14.3003 1.69992 13.1808 1.69971 11.8003V4.19971C1.69992 2.81918 2.81913 1.69971 4.19971 1.69971H8.85596V2.69971Z"
public let chatEditStrokePath = "M7.7849 8.23878L13.888 2.13574"

/// Desktop `IconApiOutlineArtwork` Regular, 14 default size on a 16×16 view box.
public let chatApiChevronPath = "M3 4L7 8L3 12"
public let chatApiBarPath = "M9 12H13"

/// Desktop `IconCodeOutlineArtwork` Regular.
public let chatCodeSlashLeftPath = "M6.27612 1.5L4.52612 14.5"
public let chatCodeSlashRightPath = "M11.4739 1.5L9.72388 14.5"
public let chatCodeRuleTopPath = "M2.39868 5.5H14.0681"
public let chatCodeRuleBottomPath = "M1.93188 10.5H13.6013"

/// Desktop `IconPlanOutline` is `IconListPenOutlineArtwork`.
public let chatPlanCaptionTopPath = "M4.9375 5.90295H11.0625"
public let chatPlanCaptionMidPath = "M4.9375 9.02991H8.27841"
public let chatPlanPagePath =
    "M12.5 1.32617C13.3039 1.32617 14 1.95171 14 2.77637V7.61328L13 8.68164V2.77637C13 2.55186 12.8007 2.32617 12.5 2.32617H3.5C3.1993 2.32617 3 2.55186 3 2.77637V13.2246C3.00044 13.4489 3.19963 13.6738 3.5 13.6738H8.32812L7.39258 14.6738H3.5C2.69637 14.6738 2.00042 14.0489 2 13.2246V2.77637C2 1.95171 2.69613 1.32617 3.5 1.32617H12.5Z"
public let chatPlanPencilPath =
    "M8.97212 14.3693C9.17511 14.5723 9.37811 14.7753 9.5811 14.9783C9.67012 14.8953 9.75914 14.8123 9.84815 14.7293C11.4505 13.2352 13.0528 11.7411 14.6551 10.247C14.7441 10.164 14.8331 10.081 14.9221 9.99803C14.5989 9.6748 14.2756 9.35157 13.9524 9.02834C13.8694 9.11736 13.7864 9.20637 13.7034 9.29539C12.2093 10.8977 10.7152 12.5 9.22113 14.1023C9.13813 14.1913 9.05513 14.2803 8.97212 14.3693Z"
public let chatPlanPencilBasePath =
    "M11.6323 13.7841C11.6323 14.0395 11.6323 14.295 11.6323 14.5504C11.6812 14.5523 11.7301 14.5543 11.779 14.5562C12.659 14.5913 13.539 14.6263 14.419 14.6614C14.4679 14.6633 14.5168 14.6653 14.5657 14.6672C14.5657 14.3339 14.5657 14.0006 14.5657 13.6672C14.5168 13.6692 14.4679 13.6711 14.419 13.6731C13.539 13.7081 12.659 13.7432 11.779 13.7783C11.7301 13.7802 11.6812 13.7821 11.6323 13.7841Z"

/// Desktop `IconQuestionOutlineArtwork` Regular.
public let chatQuestionRingPath =
    "M8 14.5C11.5899 14.5 14.5 11.5899 14.5 8C14.5 4.41015 11.5899 1.5 8 1.5C4.41015 1.5 1.5 4.41015 1.5 8C1.5 11.5899 4.41015 14.5 8 14.5Z"
public let chatQuestionHookPath =
    "M5.75 6.69646C5.75 6.29865 5.88196 5.90976 6.12919 5.57899C6.37643 5.24821 6.72783 4.99041 7.13896 4.83817C7.5501 4.68593 8.0025 4.6461 8.43895 4.72371C8.87541 4.80132 9.27632 4.99289 9.59099 5.27419C9.90566 5.55549 10.12 5.91388 10.2068 6.30406C10.2936 6.69423 10.249 7.09866 10.0787 7.4662C9.90843 7.83373 9.62004 8.14787 9.25003 8.36889C9.19476 8.4019 9.13803 8.43262 9.08004 8.46099C8.52566 8.73217 8 9.20817 8 9.82532"
public let chatQuestionDotPath = "M8 10.7416V11.7416"

/// Desktop `IconUsersOutlineArtwork` Regular.
public let chatUsersHeadPath =
    "M6 8.25C7.51878 8.25 8.75 7.01878 8.75 5.5C8.75 3.98122 7.51878 2.75 6 2.75C4.48122 2.75 3.25 3.98122 3.25 5.5C3.25 7.01878 4.48122 8.25 6 8.25Z"
public let chatUsersShoulderPath = "M1 14.5C1 11.5 3.5 10.25 6 10.25C8.5 10.25 11 11.5 11 14.5"
public let chatUsersRearHeadPath = "M10.5 2.9C11.65 3.35 12.45 4.35 12.45 5.5C12.45 6.65 11.65 7.65 10.5 8.1"
public let chatUsersRearShoulderPath = "M12.4 10.6C13.9 11.3 15 12.6 15 14.5"

/// Desktop `IconChecklistOutlineArtwork` Regular.
public let chatChecklistDotTopPath =
    "M3.75 6.25C4.7165 6.25 5.5 5.4665 5.5 4.5C5.5 3.5335 4.7165 2.75 3.75 2.75C2.7835 2.75 2 3.5335 2 4.5C2 5.4665 2.7835 6.25 3.75 6.25Z"
public let chatChecklistLineTopPath = "M7.5 4.5H13.5"
public let chatChecklistDotBottomPath =
    "M3.75 13.25C4.7165 13.25 5.5 12.4665 5.5 11.5C5.5 10.5335 4.7165 9.75 3.75 9.75C2.7835 9.75 2 10.5335 2 11.5C2 12.4665 2.7835 13.25 3.75 13.25Z"
public let chatChecklistLineBottomPath = "M7.5 11.5H13.5"

/// Desktop `IconGoalOutlineArtwork` Regular.
public let chatGoalOuterArcPath =
    "M14.5001 8C14.5 9.28552 14.1188 10.5422 13.4045 11.611C12.6903 12.6799 11.6752 13.5129 10.4875 14.0049C9.29982 14.4968 7.99295 14.6255 6.73212 14.3747C5.4713 14.124 4.31314 13.505 3.4041 12.596C2.49514 11.687 1.87614 10.5288 1.62537 9.26798C1.37459 8.00716 1.50331 6.70028 1.99525 5.51261C2.48719 4.32494 3.32025 3.30981 4.3891 2.59557C5.45795 1.88134 6.71458 1.50008 8.0001 1.5"
public let chatGoalInnerArcPath =
    "M11.5 8C11.5001 8.69227 11.2948 9.36901 10.9102 9.94463C10.5257 10.5202 9.97901 10.9689 9.33944 11.2338C8.69986 11.4987 7.99609 11.5681 7.31712 11.433C6.63816 11.2979 6.01449 10.9645 5.52501 10.475C5.03548 9.98552 4.70209 9.36185 4.56702 8.68289C4.43195 8.00392 4.50127 7.30015 4.76619 6.66057C5.03112 6.021 5.47976 5.47436 6.05538 5.08978C6.631 4.70519 7.30774 4.49995 8.00001 4.5"
public let chatGoalPointerPath = "M8.00024 7.99976L11.2 4.80005"
public let chatGoalFlagPath =
    "M12.4719 5.62245C12.4246 5.66972 12.3569 5.69025 12.2913 5.67715L10.7814 5.37555C10.7022 5.35972 10.6402 5.29781 10.6244 5.2186L10.3228 3.70866C10.3097 3.6431 10.3302 3.57533 10.3775 3.52806L12.1826 1.723C12.2863 1.61929 12.4627 1.65879 12.5122 1.79684L12.9271 2.95225C12.9472 3.00847 12.9915 3.05272 13.0477 3.07291L14.2031 3.48774C14.3412 3.5373 14.3807 3.71368 14.277 3.81739L12.4719 5.62245Z"

/// Desktop `IconCordisPluginOutlineArtwork` Regular.
public let chatCordisPluginFillPath =
    "M3.16143 6.59068L1.75205 8.00006L3.10619 9.35419L2.39908 10.0613L0.832948 8.49517C0.559581 8.2218 0.559582 7.77831 0.832948 7.50494L2.45432 5.88357L3.16143 6.59068ZM8.49511 15.1671C8.22176 15.4405 7.77826 15.4404 7.50489 15.1671L5.93461 13.5968L6.64172 12.8897L8 14.248L9.40938 12.8386L10.1165 13.5457L8.49511 15.1671ZM15.1671 7.50494C15.4403 7.7782 15.4401 8.22179 15.1671 8.49517L13.652 10.0102L12.9449 9.30309L14.248 8.00006L12.8897 6.64178L13.5968 5.93467L15.1671 7.50494ZM9.35414 3.10624L8 1.7521L6.69696 3.05514L5.98986 2.34803L7.50489 0.833003C7.77828 0.559981 8.22186 0.559752 8.49511 0.833003L10.0612 2.39913L9.35414 3.10624Z"
public let chatCordisPluginCircleCenter: Double = 8
public let chatCordisPluginCircleRadius: Double = 1.76221

/// Desktop `IconStopFillArtwork` used by `ui-jobs` kill.
public let jobsStopFillPath =
    "M12.5 2.5H3.5C2.94772 2.5 2.5 2.94772 2.5 3.5V12.5C2.5 13.0523 2.94772 13.5 3.5 13.5H12.5C13.0523 13.5 13.5 13.0523 13.5 12.5V3.5C13.5 2.94772 13.0523 2.5 12.5 2.5Z"

public func jobsStopFillSymbol() -> String { "official.stopFill" }

/// Desktop `TodoPanel` / `GoalBar` / `QueueDock` leading + queue actions.
/// View-options `.queue` keeps `official.queue` (filterShow); the dock uses
/// the same ChatLinesOutline artwork under `official.queueOutline`.
public func chatTodoDockSymbol() -> String { "official.checklistOutline" }
public func chatGoalDockSymbol() -> String { "official.goalOutline" }
public func chatQueueDockSymbol() -> String { "official.queueOutline" }
public func chatTodoPanelIdentifier() -> String { "todoPanel" }
public func chatGoalBarIdentifier() -> String { "goalBar" }
public func chatQueueDockIdentifier() -> String { "promptQueue" }
public func isForbiddenChatDockSystemSymbol(_ name: String) -> Bool {
    name == "checklist"
        || name == "target"
        || name == "text.line.first.and.arrowtriangle.forward"
        || name == "pencil"
        || name == "trash"
        || name == "paperplane"
}

public func isForbiddenJobsRowChromeSymbol(_ name: String) -> Bool {
    name == "chevron.down"
        || name == "chevron.right"
        || name == "chevron.up"
        || name == "stop.fill"
}

/// Desktop `JobListAction` row chevron is `IconChevronDownOutlineRegular` size 12;
/// open applies `.chevronOpen` `rotate(180deg)`.
public let jobsRowChevronIconSizePoints: Double = 12
public let jobsRowChevronOpenRotationDegrees: Double = 180

/// Desktop settled-section toggle uses the same down chevron; collapsed CSS is
/// `.sectionChevron` `rotate(-90deg)`, open is `transform: none`.
public let jobsSettledChevronCollapsedRotationDegrees: Double = -90
public let jobsSettledChevronOpenRotationDegrees: Double = 0

/// Desktop `ui-plugin-manager` inventory / settings toolbar refresh is
/// `IconRefreshOutlineRegular`. Phone builtin-plugin settings must reuse it.
public let builtinPluginRefreshUsesOfficialGlyph = true
public func builtinPluginRefreshSymbol() -> String { "official.refreshOutline" }
public func isForbiddenBuiltinPluginRefreshSymbol(_ name: String) -> Bool {
    name == "arrow.clockwise"
}

/// Desktop `ui-trajectory` inspector jump / thinking toggle: `IconChevronRightOutlineRegular`
/// size 12. Thinking rotates 90° when `aria-expanded=true`.
public let trajectoryDetailChevronIconSizePoints: Double = 12
public let trajectoryThinkingChevronExpandedRotationDegrees: Double = 90

public func isForbiddenTrajectoryDetailSystemSymbol(_ name: String) -> Bool {
    name == "chevron.right"
        || name == "chevron.down"
        || name == "wrench.and.screwdriver"
        || name == "square.on.square"
}

/// Desktop `ContextInjectionRow` tool-change leading icon is `IconBrowseOutlineRegular`.
public func contextInjectionOfficialSymbol() -> String { "official.browseOutline" }

/// Desktop `GenericCommandCard` / `CompactionItem` leading icon is `IconApiOutlineRegular`.
public func commandCardOfficialSymbol() -> String { "official.apiOutline" }

/// Phone-only pairing QR row. `ui-primitives@0.2.1-alpha.5` has no QR / scan artwork.
public let connectionsScanUsesOfficialGlyph = false
public let connectionsScanSkipReason =
    "ui-primitives 0.2.1-alpha.5 has no QR/scan artwork; do not invent one"

/// Nearby leading icon is Android Material `Icons.Outlined.Computer`, not a
/// primitives glyph. Do not invent an IconComputer or reuse appearance cubes.
public let connectionsNearbyUsesOfficialGlyph = false
public let connectionsNearbySkipReason =
    "ui-primitives 0.2.1-alpha.5 has no IconComputer; Android nearby uses Material Outlined Computer"

/// Session Inspector pick + type filter are Android/phone surfaces, not desktop Guide.
/// `IconInspectOutline` is `CodeBracketsArtwork` (`<>`), not a viewfinder.
public let inspectorPickUsesOfficialGlyph = false
public let inspectorTypeFilterUsesOfficialGlyph = false
public let inspectorPickSkipReason =
    "desktop Guide has no Session Inspector; primitives IconInspectOutline is CodeBracketsArtwork, not a viewfinder"
public let inspectorTypeFilterSkipReason =
    "ui-primitives 0.2.1-alpha.5 has no type-filter artwork"
public let inspectorPickSkipSymbol = "viewfinder"
public let inspectorTypeFilterSkipSymbol = "line.3.horizontal.decrease"
public func inspectorPickSkipIdentifier() -> String { "inspector.viewfinder" }
public func inspectorTypeFilterSkipIdentifier() -> String { "inspector.typeFilter" }

/// Desktop terminal panel has no centered spinner. `IconLoadingOutline` is a static
/// arc used next to loading labels elsewhere; rotating it in the PTY pane would
/// invent a loading animation the Host UI does not show.
public let terminalCenterLoadingUsesOfficialGlyph = false
public let terminalCenterLoadingSkipReason =
    "desktop sidebar-terminal has no center spinner; do not invent a rotating loading SVG"
