import SwiftUI
import UIKit
import DSHProtocol

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var theme = ThemeStateHolder.shared
    @State private var showHomePreset = false
    @State private var slashMenu = SlashMenuState()
    @StateObject private var commandHost = CommandMenuHost()
    @State private var showModels = false
    @State private var showPermission = false
    @State private var riskPermission: String?
    @State private var showWorkspacePicker = false
    @State private var composerFocus = 0

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            content
            if model.showDrawer {
                drawerScrim
            }
            if model.showDrawer {
                HStack(spacing: 0) {
                    SessionDrawer(model: model)
                        .frame(width: min(320, UIScreen.main.bounds.width * 0.86))
                        .transition(.move(edge: .leading))
                    Spacer()
                }
            }
        }
        .preferredColorScheme(preferred)
        .onAppear { theme.resolve(appearance: model.appearance, systemDark: colorScheme == .dark) }
        .onChange(of: model.appearance) { _ in theme.resolve(appearance: model.appearance, systemDark: colorScheme == .dark) }
        .onChange(of: colorScheme) { value in theme.resolve(appearance: model.appearance, systemDark: value == .dark) }
        .overlay(alignment: .top) {
            if let message = model.errorMessage ?? model.toast {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(T.onPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(T.primaryButton.opacity(0.92), in: Capsule())
                    .padding(.top, 8)
                    .onTapGesture { model.errorMessage = nil; model.toast = nil }
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        if model.errorMessage == message { model.errorMessage = nil }
                        if model.toast == message { model.toast = nil }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.showDrawer)
        .onChange(of: scenePhase) { phase in
            ConnectionKeeper.shared.sceneChanged(phase)
        }
        .sheet(isPresented: $showHomePreset) {
            PresetSheet(
                model: model,
                current: model.draftPreset,
                editable: true,
                onDismiss: { showHomePreset = false },
                onPick: { model.draftPreset = $0 }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            if keepsChatMounted {
                persistentChat
            }
            switch model.currentRoute {
            case .chat, .sessions:
                EmptyView()
            case .connections, .pair:
                ConnectionsView(model: model)
            case .settings:
                SettingsView(model: model)
            case .general:
                GeneralSettingsView(model: model)
            case .models:
                ModelsSettingsView(model: model)
            case .builtinPlugins:
                PluginInventoryView(model: model)
            case .presets:
                AgentPresetSettingsView(model: model, onCreator: {
                    model.pendingCreatorPreset = "cordis"
                    model.pop()
                    model.showDrawer = false
                    model.createAndOpenSession(preset: "cordis")
                })
            case .diagnostics:
                ConnectionsView(model: model)
            case .panel(let panel):
                HostPanelView(model: model, panel: panel)
            }
        }
    }

    /// Desktop keeps the conversation mounted while the in-app browser sidebar is open.
    private var keepsChatMounted: Bool {
        switch model.currentRoute {
        case .chat, .sessions: return true
        case .panel(.browser): return true
        default: return false
        }
    }

    @ViewBuilder
    private var persistentChat: some View {
        if model.chat != nil {
            ChatView(model: model)
                .allowsHitTesting(!isBrowserOnTop)
        } else if model.profiles.isEmpty {
            ConnectionsView(model: model)
        } else {
            emptyChat
        }
    }

    private var isBrowserOnTop: Bool {
        if case .panel(.browser) = model.currentRoute { return true }
        return false
    }

    private var landingSlashTrigger: ComposerTrigger? { slashMenuTrigger(model.composerText) }
    private var landingCommandMenuVisible: Bool { slashMenu.isVisible(trigger: landingSlashTrigger) }

    private var emptyChat: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.showDrawer = true } label: {
                    Image(systemName: D.panelLeft).foregroundStyle(T.ink)
                }
                BrandWordmark(height: 20)
                Spacer()
            }
            .padding(14)
            .background(T.surface)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    VStack(spacing: 12) {
                        Spacer()
                        Text(L.landingHeadline())
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(T.ink)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(L.landingPreview())
                            .font(.caption.weight(.medium))
                            .foregroundStyle(T.text3)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .overlay(Capsule().stroke(T.border, lineWidth: 1))
                            .accessibilityLabel(L.landingPreview())
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if landingCommandMenuVisible {
                        CommandMenuOverlay(
                            model: model,
                            host: commandHost,
                            query: slashMenuQuery(model.composerText),
                            leading: slashMenuIsLeading(model.composerText),
                            consumeSlash: landingSlashTrigger != nil,
                            availableHeight: max(0, geo.size.height - 8),
                            onDismiss: { slashMenu.dismiss(trigger: landingSlashTrigger) },
                            onFile: { model.createAndOpenSession() },
                            onGoal: { model.insertComposer("/goal ") },
                            onPlan: { model.executeCommand("/plan") },
                            onFeedback: { model.createAndOpenSession() },
                            onCompact: { model.executeCommand("/compact") },
                            onPerm: { if model.isOnline { showPermission = true } },
                            onModel: { if model.isOnline { showModels = true } },
                            onExport: { model.createAndOpenSession() },
                            onSelectPermission: { applyLandingPermission($0) }
                        )
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)
                        .frame(height: max(0, geo.size.height - 8), alignment: .bottom)
                    }
                }
            }
            landingWorkspaceRow
            ComposerView(
                model: model,
                interceptKeys: landingCommandMenuVisible,
                focusToken: composerFocus,
                heroPlaceholder: true,
                onPlus: {
                    slashMenu.togglePlus(trigger: landingSlashTrigger)
                    if slashMenu.isVisible(trigger: landingSlashTrigger) {
                        composerFocus += 1
                    }
                },
                onSelectPermission: { applyLandingPermission($0) },
                onModel: { if model.isOnline { showModels = true } },
                onSend: {
                    if landingCommandMenuVisible {
                        commandHost.requestEnter()
                        return
                    }
                    model.sendCurrent()
                },
                onCommandReturn: { commandHost.requestEnter() },
                onCommandMove: { commandHost.requestMove($0) },
                onCommandEscape: { slashMenu.dismiss(trigger: landingSlashTrigger) }
            )
        }
        .background(T.bg)
        .onChange(of: model.composerText) { _ in
            slashMenu.track(trigger: landingSlashTrigger)
        }
        .sheet(isPresented: $showModels) {
            ModelPicker(
                catalog: model.catalog,
                current: model.modelChoice,
                loading: model.catalogLoading,
                error: model.catalogError,
                pending: model.modelPending,
                enabled: model.isOnline,
                onReload: { model.reloadModelCatalog() },
                onDismiss: { showModels = false },
                onPick: { choice, done in model.selectModel(choice, onComplete: done) }
            )
            .padding()
        }
        .sheet(isPresented: $showWorkspacePicker) {
            WorkspaceDirectorySheet(model: model, onDismiss: { showWorkspacePicker = false })
        }
        .sheet(isPresented: $showPermission) {
            PermissionPickerSheet(
                current: model.sessionPermission ?? model.draftPermission ?? model.defaultPermission,
                catalog: model.permissionCatalog,
                loading: model.permissionCatalogLoading,
                error: model.permissionCatalogError,
                enabled: model.isOnline,
                busy: model.permissionChanging,
                onRefresh: { model.reloadPermissionCatalog() },
                onDismiss: { showPermission = false },
                onPick: { value in
                    showPermission = false
                    applyLandingPermission(value)
                }
            )
        }
        .overlay {
            if let value = riskPermission {
                PermissionRiskDialog(
                    preset: value,
                    enabled: model.isOnline && !model.permissionChanging && model.permissionCatalog?.find(value) != nil,
                    onDismiss: { riskPermission = nil },
                    onConfirm: {
                        model.setPermission(value) { _ in riskPermission = nil }
                    }
                )
            }
        }
    }

    private func applyLandingPermission(_ value: String) {
        if value == "danger-full-access" || value == "auto" {
            riskPermission = value
        } else {
            model.setPermission(value) { _ in }
        }
    }

    private var landingWorkspaceRow: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(model.workspaces) { workspace in
                    Button(
                        workspaceDisplayTitle(
                            title: workspace.title,
                            path: workspace.path,
                            localizedDefault: L.defaultWorkspace()
                        )
                    ) {
                        model.draftWorkspaceId = workspace.workspaceId
                    }
                }
                if model.ops.contains("workspace.create") {
                    Button(L.selectWorkspaceDirectory()) { showWorkspacePicker = true }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: model.landingWorkspaceLabel == nil ? "folder" : "folder.fill")
                        .font(.system(size: 14))
                    Text(model.landingWorkspaceLabel ?? landingChooseWorkspace(english: L.en))
                        .font(.subheadline)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                }
                .foregroundStyle(T.text2)
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .background(T.fill, in: Capsule())
            }
            .accessibilityLabel(landingChooseWorkspace(english: L.en))
            if !model.presetRoster.isEmpty {
                Button { showHomePreset = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: D.agentPreset)
                        Text(homePresetLabel)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                    }
                    .font(.subheadline)
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 36)
                    .background(T.fill, in: Capsule())
                }
                .accessibilityLabel(homePresetLabel)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private var homePresetLabel: String {
        let id = model.draftPreset.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? model.presetRoster.first { $0["isDefault"].bool() == true }?["id"].str()
            : model.draftPreset
        if let id, let row = model.presetRoster.first(where: { $0["id"].str() == id }) {
            return PresetPolicy.name(row, english: L.en)
        }
        return L.agentPresets()
    }

    private var drawerScrim: some View {
        T.scrim.ignoresSafeArea().onTapGesture { model.showDrawer = false }
    }

    private var preferred: ColorScheme? {
        switch model.appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
