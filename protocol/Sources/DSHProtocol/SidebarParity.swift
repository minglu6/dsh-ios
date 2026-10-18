/// Desktop `@deepseek-ai/dsh-client-ui-*@0.2.1-alpha.5` sidebar inventory.
///
/// Right column (`ui-sidebar-right` + tab providers in `dsh-web-app` `cordis.patch.yml`):
/// the header corner button expands a dock whose default page is the Guide.
/// Guide cards come from registered `guide` entries, ordered by `order`.
///
/// Left column (`ui-sidebar` + `ui-workspace` + settings/plugin/schedule seats):
/// workspaces/sessions, then plugin-manager and schedule pages, then the
/// Settings trigger row (`ui-settings-general` `triggerRow`).
public enum DesktopSidebarSurface: String, Equatable, Hashable, Sendable, CaseIterable {
    case leftWorkspaces
    case leftPlugins
    case leftSchedule
    case leftSettings
    case rightGuide
    case rightFiles
    case rightTerminal
    case rightBrowser
    case rightDocumentPreview
    case rightSessionInspector
}

public struct DesktopSidebarEntry: Equatable, Sendable {
    public var surface: DesktopSidebarSurface
    public var official: Bool
    public var zh: String
    public var en: String
    public var packageId: String
}

public enum DesktopSidebarInventory {
    /// Desktop right-sidebar Guide cards, in `order`.
    public static let rightGuideCards: [(id: String, order: Int, zh: String, en: String, zhHint: String, enHint: String)] = [
        ("workspace", 10, "工作区文件", "Workspace files", "浏览会话工作区的文件", "Browse files in this session's workspace"),
        ("new", 20, "新建终端", "New terminal", "在会话工作区运行命令", "Run commands in the Session workspace"),
        ("browser", 30, "浏览器", "Browser", "浏览网页", "Browse web pages"),
    ]

    public static let entries: [DesktopSidebarEntry] = [
        DesktopSidebarEntry(surface: .leftWorkspaces, official: true, zh: "工作区 / 会话", en: "Workspaces / sessions", packageId: "@deepseek-ai/dsh-client-ui-workspace"),
        DesktopSidebarEntry(surface: .leftPlugins, official: true, zh: "插件", en: "Plugins", packageId: "@deepseek-ai/dsh-client-ui-plugin-manager"),
        DesktopSidebarEntry(surface: .leftSchedule, official: true, zh: "自动化任务", en: "Automation tasks", packageId: "@deepseek-ai/dsh-client-ui-schedule"),
        DesktopSidebarEntry(surface: .leftSettings, official: true, zh: "设置", en: "Settings", packageId: "@deepseek-ai/dsh-client-ui-settings-general"),
        DesktopSidebarEntry(surface: .rightGuide, official: true, zh: "开始", en: "Start", packageId: "@deepseek-ai/dsh-client-ui-sidebar-right"),
        DesktopSidebarEntry(surface: .rightFiles, official: true, zh: "文件", en: "Files", packageId: "@deepseek-ai/dsh-client-ui-sidebar-files"),
        DesktopSidebarEntry(surface: .rightTerminal, official: true, zh: "终端", en: "Terminal", packageId: "@deepseek-ai/dsh-client-ui-sidebar-terminal"),
        DesktopSidebarEntry(surface: .rightBrowser, official: true, zh: "浏览器", en: "Browser", packageId: "@deepseek-ai/dsh-client-ui-sidebar-browser"),
        DesktopSidebarEntry(surface: .rightDocumentPreview, official: true, zh: "文档预览", en: "Document preview", packageId: "@deepseek-ai/dsh-client-ui-sidebar-documentpreview"),
        DesktopSidebarEntry(
            surface: .rightSessionInspector,
            official: false,
            zh: "会话数据诊断",
            en: "Session diagnostics",
            packageId: "android SessionInspectorPanel / iOS SessionInspectorPanel"
        ),
    ]

    public static func officialGuideKinds() -> [String] {
        rightGuideCards.map(\.id)
    }

    public static var desktopGuideIncludesBrowser: Bool { true }
    public static var desktopGuideIncludesSessionInspector: Bool { false }
}

public enum ViewOptionsSection: String, Equatable, Sendable, CaseIterable {
    case groupBy
    case orderBy
    case filter
}

public enum ViewOptionsRow: String, Equatable, Sendable, CaseIterable {
    case groupWorkspace
    case groupWorkspaceTree
    case groupFlat
    case orderManual
    case orderUpdated
    case filterHide
    case filterShow
    case filterOnly
}

public enum ViewOptionsMenuPolicy {
    public static func section(of row: ViewOptionsRow) -> ViewOptionsSection {
        switch row {
        case .groupWorkspace, .groupWorkspaceTree, .groupFlat: return .groupBy
        case .orderManual, .orderUpdated: return .orderBy
        case .filterHide, .filterShow, .filterOnly: return .filter
        }
    }

    public static func rows(in section: ViewOptionsSection) -> [ViewOptionsRow] {
        ViewOptionsRow.allCases.filter { self.section(of: $0) == section }
    }

    public static func title(_ section: ViewOptionsSection, english: Bool) -> String {
        switch section {
        case .groupBy: return english ? "Group by" : "分组方式"
        case .orderBy: return english ? "Order by" : "排序方式"
        case .filter: return english ? "View options" : "视图选项"
        }
    }

    public static func label(_ row: ViewOptionsRow, english: Bool) -> String {
        switch row {
        case .groupWorkspace: return english ? "WorkSpace" : "按工作区"
        case .groupWorkspaceTree: return english ? "Workspace Tree" : "按工作区树"
        case .groupFlat: return english ? "In one list" : "单列表"
        case .orderManual: return english ? "Manual" : "手动排序"
        case .orderUpdated: return english ? "Last updated" : "最近更新"
        case .filterHide: return english ? "Hide archived" : "隐藏已归档"
        case .filterShow: return english ? "All conversations (show archived)" : "全部对话（显示已归档）"
        case .filterOnly: return english ? "Archived only" : "仅显示已归档"
        }
    }

    public static func icon(_ row: ViewOptionsRow) -> String {
        switch row {
        case .groupWorkspace: return "folderClose"
        case .groupWorkspaceTree: return "workspaceTree"
        case .groupFlat: return "flatList"
        case .orderManual: return "chevronsUpDown"
        case .orderUpdated: return "clockOutline"
        case .filterHide: return "archiveOff"
        case .filterShow: return "queue"
        case .filterOnly: return "archiveCheck"
        }
    }
}

/// Desktop `ui-workspace` `ViewOptionsMenu` is a dense `Menu` (`min-width: 200px`)
/// anchored to the sliders trigger — not an iPhone compact sheet.
public let viewOptionsUsesCompactPopover = true
public let viewOptionsMenuMinWidthPoints: Double = 200
public let viewOptionsMenuRowMinHeightPoints: Double = 34
public let viewOptionsEveryRowHasOfficialLeadingIcon = true

/// Desktop `IconSlidersTwoOutlineArtwork` knobs (stroked circles, fill none).
public let viewOptionsSlidersKnobTopCenterX: Double = 9.95
public let viewOptionsSlidersKnobTopCenterY: Double = 5
public let viewOptionsSlidersKnobBottomCenterX: Double = 5.75
public let viewOptionsSlidersKnobBottomCenterY: Double = 11
public let viewOptionsSlidersKnobRadius: Double = 1.45

public func viewOptionsOfficialIdentifier(_ row: ViewOptionsRow) -> String {
    "official.\(ViewOptionsMenuPolicy.icon(row))"
}

public func viewOptionsTriggerOfficialIdentifier() -> String { "official.slidersTwo" }

public func isForbiddenViewOptionsSystemSymbol(_ name: String) -> Bool {
    switch name {
    case "slider.horizontal.3",
         "line.3.horizontal.decrease",
         "square.grid.2x2",
         "list.bullet",
         "list.bullet.rectangle",
         "arrow.up.arrow.down",
         "clock",
         "clock.fill",
         "archivebox",
         "archivebox.fill",
         "tray.full",
         "folder.fill":
        return true
    default:
        return false
    }
}

public enum SchedulePagePolicy {
    public static let headerNewActionUsesShortLabel = true
    public static let showsUnofficialRefresh = false
    public static let emptyRepeatsHeaderNewAction = false
    public static func tabLabel(_ id: String, english: Bool) -> String {
        switch id {
        case "all": return english ? "All" : "全部"
        case "active": return english ? "Enabled" : "已开启"
        case "inactive": return english ? "Inactive" : "已结束"
        default:
            fatalError("SchedulePagePolicy.tabLabel: unknown tab \(id)")
        }
    }

    public static func headerNewLabel(english: Bool) -> String {
        english ? "New" : "新建"
    }

    public static func emptyActionLabel(english: Bool) -> String {
        english ? "New automation task" : "新建自动化任务"
    }

    public static func emptyBody(hasRows: Bool, filter: String, query: String, english: Bool) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return english ? "No matching tasks" : "没有匹配的自动化任务"
        }
        if filter == "inactive" {
            return english ? "No inactive automation tasks" : "没有已结束的自动化任务"
        }
        if !hasRows {
            return english
                ? "No tasks yet. Tasks created in your sessions appear here."
                : "还没有自动化任务，在会话中创建的任务会显示在这里"
        }
        return english ? "No matching tasks" : "没有匹配的自动化任务"
    }
}

public enum SessionRowChromePolicy {
    public static let timeSharesTitleLine = true
    public static let trailingActionsAlwaysVisibleOnTouch = true
    public static let hidesTimeWhenActionsVisible = true
}

/// Desktop `ui-workspace` `ProjectRowItem` folder slot.
/// Collapsed: `IconFolderCloseRegular`. Expanded: filled `IconFolderOpenRegular`
/// (not the outline artwork used by the file tree). Hover-chevron swap is skip.
public func workspaceGroupFolderSymbol(collapsed: Bool) -> String {
    collapsed ? "official.folderClose" : "official.folderOpenFill"
}

public let workspaceGroupFolderIconSizePoints: Double = 16

/// Desktop `active = containsCurrentDescendant || (expanded && containsCurrent)`.
/// Current = workspace that owns `mainSessionId`. Ancestors stay lit when the
/// subtree is collapsed; the current row itself only lights while expanded.
public func workspaceGroupFolderIsActive(
    containsCurrent: Bool,
    containsCurrentDescendant: Bool,
    expanded: Bool
) -> Bool {
    containsCurrentDescendant || (expanded && containsCurrent)
}

/// Desktop `.folder` uses `--dsw-alias-label-tertiary`; `.folderActive` uses
/// `--dsw-alias-state-business-primary` (`ui-theme` light `#4176E6` / dark `#7AAAFF`).
public func workspaceGroupFolderUsesBusinessPrimaryWhenActive() -> Bool { true }
public let workspaceGroupFolderActiveColorLightHex: UInt32 = 0x4176E6
public let workspaceGroupFolderActiveColorDarkHex: UInt32 = 0x7AAAFF
public func workspaceGroupFolderActiveColorHex(dark: Bool) -> UInt32 {
    dark ? workspaceGroupFolderActiveColorDarkHex : workspaceGroupFolderActiveColorLightHex
}

/// Desktop hover swaps the folder for `IconTriangleRightFillRegular`. Touch has
/// no hover; do not invent a persistent chevron.
public let workspaceGroupFolderHoverChevronSwapIsSkip = true

public func isForbiddenWorkspaceGroupFolderSymbol(_ name: String) -> Bool {
    name == "folder" || name == "folder.fill"
}

public func workspaceGroupFolderIconIdentifier(_ workspaceId: String) -> String {
    "workspaceIcon.\(workspaceId)"
}

/// Desktop `IconFolderOpenArtwork` fill paths (opacity 0.16 shade + two fills).
public let workspaceFolderOpenFillShadePath =
    "M2.55912 7.93683C2.67584 7.49906 3.0723 7.19446 3.52536 7.19446H13.6491C14.3061 7.19446 14.7846 7.81725 14.6153 8.45209L13.4411 12.856C13.3244 13.2938 12.9279 13.5984 12.4748 13.5984H2.35113C1.69411 13.5984 1.21562 12.9756 1.38489 12.3407L2.55912 7.93683Z"
public let workspaceFolderOpenFillPocketPath =
    "M13.6491 6.69446C14.6346 6.69453 15.3522 7.62895 15.0983 8.58118L13.9245 12.9845C13.7494 13.6412 13.1539 14.0988 12.4743 14.0988H2.35126C1.36574 14.0988 0.648153 13.1643 0.902044 12.212L2.07587 7.80774C2.25102 7.15128 2.84567 6.69455 3.52509 6.69446H13.6491ZM3.52509 7.69446C3.29865 7.69455 3.10004 7.84674 3.04169 8.06555L1.86786 12.4698C1.78345 12.7872 2.02285 13.0988 2.35126 13.0988H12.4743C12.7007 13.0988 12.8992 12.9463 12.9577 12.7277L14.1325 8.32336C14.2171 8.00598 13.9776 7.69453 13.6491 7.69446H3.52509Z"
public let workspaceFolderOpenFillTabPath =
    "M4.7666 1.90137C5.13227 1.90144 5.48571 2.03525 5.75977 2.27734L7.27246 3.61328C7.36379 3.69382 7.48174 3.73828 7.60352 3.73828H12.3994C13.2276 3.73841 13.8993 4.41005 13.8994 5.23828V6.7168C13.8183 6.70327 13.735 6.69436 13.6494 6.69434H12.8994V5.23828C12.8993 4.96233 12.6754 4.73841 12.3994 4.73828H7.60352C7.23781 4.73828 6.88446 4.60438 6.61035 4.3623L5.09766 3.02637C5.00636 2.94576 4.88838 2.90144 4.7666 2.90137H2.0498C1.77366 2.90137 1.5498 3.12523 1.5498 3.40137V9.78223L0.902344 12.2119C0.648452 13.1642 1.36604 14.0986 2.35156 14.0986H2.0498C1.2214 14.0986 0.549838 13.427 0.549805 12.5986V3.40137C0.549805 2.57294 1.22138 1.90137 2.0498 1.90137H4.7666Z"
public let workspaceFolderOpenFillShadeOpacity: Double = 0.16
