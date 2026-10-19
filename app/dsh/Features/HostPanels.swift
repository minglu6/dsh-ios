import SwiftUI
import DSHProtocol

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
            case .browser:
                BrowserPanel(
                    model: model,
                    sessionKey: model.activeId ?? model.chat?.sessionId ?? "landing",
                    onDismiss: { model.pop() }
                )
            case .inspector:
                if let sessionId = model.chat?.sessionId {
                    SessionInspectorPanel(model: model, sessionId: sessionId) { model.pop() }
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(T.bg)
                        .onAppear { model.pop() }
                }
            case .start:
                StartPanel(
                    model: model,
                    onFiles: { openWorkspaceSurface(.files) },
                    onTerminal: { openWorkspaceSurface(.terminal) },
                    onBrowser: { model.push(.panel(.browser)) },
                    onInspector: { openWorkspaceSurface(.inspector) },
                    onDismiss: { model.pop() }
                )
            case .settings:
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(T.bg)
                    .onAppear { model.pop() }
            }
        }
        .background(T.bg.ignoresSafeArea())
        // `.contain` keeps child ids (pluginInfoButton, official.*, navBack)
        // addressable; a bare id on this VStack would overwrite every
        // descendant's id. Start / Browser / Inspector use the XCUI ids the
        // screenshot tests query — do not nest a second contain+id inside
        // those panels or XCUI drops the inner identifier.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(surfaceAccessibilityId)
    }

    private var surfaceAccessibilityId: String {
        switch panel {
        case .start: return "startPanel"
        case .browser: return "browserPanel"
        case .inspector: return "sessionInspector"
        default: return "hostPanel.\(panel.rawValue)"
        }
    }

    private var showsSharedHeader: Bool {
        switch panel {
        case .files, .terminal, .jobs, .plugins, .schedule, .browser, .inspector, .start: return false
        default: return true
        }
    }

    /// Desktop new-session page is a blank session. The iOS landing is
    /// session-less, so Files / Terminal / Inspector first create that session.
    private func openWorkspaceSurface(_ panel: DrawerPanel) {
        if model.chat != nil {
            model.push(.panel(panel))
            return
        }
        model.createAndOpenSession(workspaceId: model.draftWorkspaceId) {
            model.push(.panel(panel))
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
        case .browser: return L.browser()
        case .inspector: return L.sessionInspector()
        case .start: return L.startPanel()
        case .settings: return L.settings()
        }
    }

}

/// Desktop Start / Guide: files + terminal + browser (order 10/20/30) plus
/// the optional-bundle session-inspector card (`session-inspector-log` order 60).
/// Desktop shows it as an optional-bundle Guide card; iOS always lists it
/// (no host capability flag), matching Android `RightPanel`.
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
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(
                        StartPanelPolicy.entries(
                            files: model.canShowFiles,
                            terminal: model.canShowTerminal,
                            browser: true,
                            inspector: true
                        ),
                        id: \.self
                    ) { entry in
                        switch entry {
                        case .workspaceFiles:
                            guideEntry(
                                L.workspaceFiles(),
                                L.workspaceFilesHint(),
                                .folderClose,
                                tint: Color(hex: 0xFFF5B942),
                                shortcut: StartPanelPolicy.shortcut(entry),
                                chevron: StartPanelPolicy.showsChevron(entry),
                                action: onFiles
                            )
                        case .newTerminal:
                            guideEntry(
                                L.newTerminal(),
                                L.terminalHint(),
                                .terminalPrompt,
                                tint: T.ink,
                                shortcut: StartPanelPolicy.shortcut(entry),
                                chevron: StartPanelPolicy.showsChevron(entry),
                                action: onTerminal
                            )
                        case .browser:
                            guideEntry(
                                L.browser(),
                                L.browserHint(),
                                .globe,
                                tint: T.ink,
                                shortcut: StartPanelPolicy.shortcut(entry),
                                chevron: StartPanelPolicy.showsChevron(entry),
                                action: onBrowser
                            )
                        case .sessionInspector:
                            guideEntry(
                                L.sessionInspector(),
                                L.sessionInspectorHint(),
                                .slidersTwo,
                                tint: T.ink,
                                shortcut: StartPanelPolicy.shortcut(entry),
                                chevron: StartPanelPolicy.showsChevron(entry),
                                action: onInspector
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(T.bg.ignoresSafeArea())
    }

    private func guideEntry(
        _ title: String,
        _ description: String,
        _ icon: OfficialGlyph.Kind,
        tint: Color,
        shortcut: String?,
        chevron: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                OfficialGlyph(kind: icon, size: 22, color: tint)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14)).foregroundStyle(T.ink).lineLimit(1)
                    Text(description).font(.system(size: 11)).foregroundStyle(T.text3).lineLimit(1)
                }
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12).weight(.medium))
                        .foregroundStyle(T.caption)
                }
                if chevron {
                    OfficialGlyph(kind: .chevronDown, size: 14, color: T.caption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 56)
            .background(T.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(T.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(description)
        .accessibilityIdentifier("start.\(title)")
    }
}
