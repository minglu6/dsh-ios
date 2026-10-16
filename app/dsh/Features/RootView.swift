import SwiftUI
import UIKit
import DSHProtocol

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var theme = ThemeStateHolder.shared
    @State private var showHomePreset = false

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
        switch model.currentRoute {
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
        case .chat:
            ChatView(model: model)
        case .sessions:
            if model.chat != nil {
                ChatView(model: model)
            } else if model.profiles.isEmpty {
                ConnectionsView(model: model)
            } else {
                emptyChat
            }
        }
    }

    private var emptyChat: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.showDrawer = true } label: {
                    Image(systemName: D.panelLeft).foregroundStyle(T.ink)
                }
                BrandWordmark(height: 20)
                Spacer()
                if !model.presetRoster.isEmpty {
                    Button { showHomePreset = true } label: {
                        Label(homePresetLabel, systemImage: D.agentPreset)
                            .font(.caption)
                            .foregroundStyle(T.accent)
                    }
                }
            }
            .padding(14)
            .background(T.surface)
            Spacer()
            Button(L.newSession(), action: { model.createAndOpenSession() })
                .foregroundStyle(T.onPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(T.primaryButton, in: Capsule())
                .disabled(!model.isOnline)
            Text(model.isOnline ? L.emptySessions() : L.notConnected())
                .font(.subheadline)
                .foregroundStyle(T.text3)
                .padding(.top, 12)
            Spacer()
        }
        .background(T.bg)
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
