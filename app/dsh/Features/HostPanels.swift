import SwiftUI

/// Host surfaces that share official desktop semantics.
/// Trajectory is the Chat / 轨迹 tab; this panel is only reached if something
/// still pushes `.panel(.trajectory)` (same ledger, no empty TODO).
struct HostPanelView: View {
    @ObservedObject var model: AppModel
    let panel: DrawerPanel

    var body: some View {
        VStack(spacing: 0) {
            if showsSharedHeader {
                header(title) { model.pop() }
            }
            switch panel {
            case .plugins: PluginsScreen(model: model, onCreatePlugin: {
                model.pendingCreatorPreset = "cordis"
                model.pop()
                model.showDrawer = false
                model.createAndOpenSession(preset: "cordis")
            })
            case .schedule: ScheduleScreen(model: model)
            case .trajectory: TrajectoryView(model: model)
            case .files: FilesPanel(model: model)
            case .terminal: TerminalPanel(model: model)
            case .jobs: JobsPanel(model: model) { model.pop() }
            case .settings:
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(T.bg)
                    .onAppear { model.pop() }
            }
        }
        .background(T.bg.ignoresSafeArea())
    }

    private var showsSharedHeader: Bool {
        switch panel {
        case .files, .terminal, .jobs, .plugins, .schedule: return false
        default: return true
        }
    }

    private var title: String {
        switch panel {
        case .plugins: return L.pluginsNav()
        case .schedule: return L.scheduleNav()
        case .files: return L.files()
        case .terminal: return L.terminal()
        case .trajectory: return L.trajectory()
        case .jobs: return L.jobs()
        case .settings: return L.settings()
        }
    }

}

/// Official GuideBody: compass watermark and a centered column of entry capsules.
struct StartPanel: View {
    @ObservedObject var model: AppModel
    var onFiles: () -> Void
    var onTerminal: () -> Void
    var onBrowser: () -> Void
    var onInspector: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header(L.startPanel()) { onDismiss() }
            ScrollView {
                VStack(spacing: 14) {
                    Image(systemName: "safari")
                        .font(.system(size: 40))
                        .foregroundStyle(T.caption)
                        .padding(.bottom, 16)
                    if model.canShowFiles {
                        guideEntry(L.workspaceFiles(), L.workspaceFilesHint(), "folder", action: onFiles)
                    }
                    if model.canShowTerminal {
                        guideEntry(L.terminal(), L.terminalHint(), "terminal", action: onTerminal)
                    }
                    guideEntry(L.t("浏览器", "Browser"), L.t("浏览网页", "Browse web pages"), "globe", action: onBrowser)
                    guideEntry(
                        L.t("会话数据诊断", "Session Log"),
                        L.t("在侧边栏分析当前会话原始日志和聊天分组数据", "Analyze raw logs and grouped chat messages for the current session in the sidebar."),
                        "viewfinder",
                        action: onInspector
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: 380)
                .frame(maxWidth: .infinity)
            }
        }
        .background(T.bg.ignoresSafeArea())
    }

    private func guideEntry(_ title: String, _ description: String, _ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: system).font(.system(size: 22)).foregroundStyle(T.text2).frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14)).foregroundStyle(T.ink).lineLimit(1)
                    Text(description).font(.system(size: 11)).foregroundStyle(T.text3).lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 56)
            .background(T.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(T.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
