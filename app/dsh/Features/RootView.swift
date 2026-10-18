import SwiftUI
import UIKit
import UniformTypeIdentifiers
import DSHProtocol

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var theme = ThemeStateHolder.shared
    @State private var slashMenu = SlashMenuState()
    @StateObject private var commandHost = CommandMenuHost()
    @State private var showModels = false
    @State private var permissionMenuOpen = false
    @State private var riskPermission: String?
    @State private var showWorkspacePicker = false
    @State private var showFileImporter = false
    @State private var composerFocus = 0
    @State private var landingComposerHeight: CGFloat = 0

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            content
            if model.showDrawer && model.currentRoute.allowsSessionDrawer {
                drawerScrim
            }
            if model.showDrawer && model.currentRoute.allowsSessionDrawer {
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
                    .onTapGesture {
                        if model.toastUndoArchiveId != nil {
                            model.undoLastArchive()
                        }
                        model.errorMessage = nil
                        model.toast = nil
                    }
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        if model.errorMessage == message { model.errorMessage = nil }
                        if model.toast == message { model.toast = nil }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.showDrawer)
        .onChange(of: model.showDrawer) { _ in
            Keyboard.dismiss()
        }
        .simultaneousGesture(drawerEdgeSwipe)
        .onChange(of: scenePhase) { phase in
            ConnectionKeeper.shared.sceneChanged(phase)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(1)
            case .diagnostics:
                ConnectionsView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(1)
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
        if model.chat != nil || model.firstPrompt != nil {
            ChatView(model: model)
                .allowsHitTesting(!isBrowserOnTop)
        } else if model.profiles.isEmpty {
            ConnectionsView(model: model)
        } else {
            emptyChat
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("landingHero")
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
                Button {
                    Keyboard.dismiss()
                    model.showDrawer = true
                } label: {
                    OfficialGlyph(kind: .panelLeft, size: 16, color: T.ink)
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("openDrawer")
                BrandWordmark(height: 20)
                Spacer()
            }
            .padding(14)
            .background(T.surface)
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    landingHeadlineRow
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { Keyboard.dismiss() }
                    VStack(spacing: CGFloat(landingHeroStackGapPoints)) {
                        landingWorkspaceRow
                        landingComposer
                    }
                }
                if landingCommandMenuVisible {
                    GeometryReader { geo in
                        landingCommandMenuLayer(
                            availableHeight: max(0, geo.size.height - landingComposerHeight - 8)
                        )
                        .padding(.bottom, landingComposerHeight + 4)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onPreferenceChange(LandingComposerHeightKey.self) { landingComposerHeight = $0 }
        }
        .background(T.bg)
        .onChange(of: model.composerText) { _ in
            slashMenu.track(trigger: landingSlashTrigger)
        }
        .sheet(isPresented: $showWorkspacePicker) {
            WorkspaceDirectorySheet(model: model, onDismiss: { showWorkspacePicker = false })
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                for url in urls {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    guard let data = try? Data(contentsOf: url) else { continue }
                    let type = UTType(filenameExtension: url.pathExtension)
                    if type?.conforms(to: .image) == true {
                        model.attachImage(name: url.lastPathComponent, mediaType: type?.preferredMIMEType ?? "image/jpeg", data: data)
                    } else {
                        model.attachFile(name: url.lastPathComponent, mediaType: type?.preferredMIMEType ?? "application/octet-stream", data: data)
                    }
                }
            }
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

    /// Phone landing (Android `Chat.kt`): Hero centers in leftover space;
    /// workspace row sits `gap: 12` above InputBar; InputBar pins to the
    /// safe-area bottom like the chat composer. Slash menu overlays the
    /// leftover above the composer — Composer stays outside GeometryReader
    /// so XCUITest can still see the plus/send UIKit hosts.
    private var landingComposer: some View {
        ComposerView(
            model: model,
            interceptKeys: landingCommandMenuVisible && riskPermission == nil,
            resignKeyboard: (permissionRiskDismissesKeyboard && riskPermission != nil)
                || (openingSessionDrawerResignsComposer && model.showDrawer),
            focusToken: composerFocus,
            heroPlaceholder: true,
            onPlus: {
                slashMenu.togglePlus(trigger: landingSlashTrigger)
                if slashMenu.isVisible(trigger: landingSlashTrigger) {
                    composerFocus += 1
                }
            },
            onSelectPermission: { applyLandingPermission($0) },
            modelMenuOpen: $showModels,
            permissionMenuOpen: $permissionMenuOpen,
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("landingComposer")
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: LandingComposerHeightKey.self, value: proxy.size.height)
            }
        )
    }

    private func landingCommandMenuLayer(availableHeight: CGFloat) -> some View {
        CommandMenuOverlay(
            model: model,
            host: commandHost,
            query: slashMenuQuery(model.composerText),
            leading: slashMenuIsLeading(model.composerText),
            consumeSlash: landingSlashTrigger != nil,
            availableHeight: availableHeight,
            onDismiss: { slashMenu.dismiss(trigger: landingSlashTrigger) },
            onFile: { showFileImporter = true },
            onGoal: { model.insertComposer("/goal ") },
            onPlan: { model.executeCommand("/plan") },
            onFeedback: { model.createAndOpenSession() },
            onCompact: { model.executeCommand("/compact") },
            onPerm: {},
            onModel: { if model.isOnline { showModels = true } },
            onExport: { model.createAndOpenSession() },
            onSelectPermission: { applyLandingPermission($0) }
        )
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    /// Desktop `HeroShell` `.headline`: FishLogo + title + preview pill.
    /// Tokens: 26/32/500 primary; badge 12/18 code, business-tertiary fill,
    /// bluish label — not system tint. Fish is primitives `FISH_LOGO_PATH`
    /// at HeroFish width 34, fill `--dsw-alias-label-primary`, column-gap 10,
    /// `align-items: center`. Never SF `fish`.
    private var landingHeadlineRow: some View {
        HStack(alignment: landingHeroHeadlineAlignsCenter ? .center : .top, spacing: CGFloat(landingHeroHeadlineColumnGapPoints)) {
            if landingHeroShowsFishLogo {
                OfficialGlyph(
                    kind: .fishLogo,
                    size: CGFloat(landingHeroFishWidthPoints),
                    color: T.ink
                )
                .fixedSize()
            }
            HStack(alignment: .top, spacing: 10) {
                Text(L.landingHeadline())
                    .font(.system(size: CGFloat(landingHeroHeadlineSizePoints), weight: .medium))
                    .foregroundStyle(T.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("landingHeadline")
                Text(L.landingPreview())
                    .font(LocalFonts.code(size: CGFloat(landingHeroPreviewFontSizePoints)))
                    .foregroundStyle(T.bluish)
                    .padding(.top, 1)
                    .padding(.horizontal, 7)
                    .background(T.tint, in: Capsule())
                    .overlay(Capsule().stroke(T.hoverBg, lineWidth: 1))
                    .offset(x: -3, y: 2)
                    .accessibilityLabel(L.landingPreview())
                    .accessibilityIdentifier("landingPreview")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
    }

    private var landingWorkspaceRow: some View {
        HStack(spacing: 10) {
            LandingWorkspaceChip(model: model, showDirectoryPicker: $showWorkspacePicker)
            AgentPresetSeat(model: model)
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    private var drawerScrim: some View {
        T.scrim.ignoresSafeArea().onTapGesture {
            Keyboard.dismiss()
            model.showDrawer = false
        }
    }

    /// Android `ModalNavigationDrawer` edge swipe. Invisible; not a control.
    private var drawerEdgeSwipe: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .global)
            .onChanged { value in
                guard model.currentRoute.allowsSessionDrawer else { return }
                if !model.showDrawer, value.startLocation.x < 24 {
                    Keyboard.dismiss()
                }
            }
            .onEnded { value in
                guard model.currentRoute.allowsSessionDrawer else { return }
                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                if !model.showDrawer,
                   value.startLocation.x < 24,
                   value.translation.width > 80,
                   horizontal {
                    model.showDrawer = true
                    return
                }
                if model.showDrawer, value.translation.width < -80, horizontal {
                    Keyboard.dismiss()
                    model.showDrawer = false
                }
            }
    }

    private var preferred: ColorScheme? {
        switch model.appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

private struct LandingComposerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
