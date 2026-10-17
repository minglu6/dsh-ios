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
