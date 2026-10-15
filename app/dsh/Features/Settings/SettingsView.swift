import SwiftUI
import DSHProtocol

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header(L.settings()) { model.pop() }
                .accessibilityIdentifier("settingsShell")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card {
                        nav(L.generalNav(), D.sliders) { model.push(.general) }
                        nav(L.modelsNav(), "cpu", divider: hasPresets || hasPluginSettings) { model.push(.models) }
                        if hasPresets {
                            nav(L.agentPresets(), D.agentPreset, divider: hasPluginSettings) { model.push(.presets) }
                        }
                        if hasPluginSettings {
                            nav(L.builtinPluginsNav(), D.plugin, divider: false) { model.push(.builtinPlugins) }
                        }
                    }
                    Text(L.phoneConnection())
                        .font(.caption)
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 22)
                    card {
                        nav(L.connections(), "link", value: model.activeProfile?.name ?? L.notConnected(), divider: false) {
                            model.push(.connections)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
    }

    private var hasPluginSettings: Bool { model.ops.contains("plugins.inventory") }
    private var hasPresets: Bool { model.ops.contains("presets.list") || model.ops.contains("presets.settings") }
}

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var shared: HostSettings
    @State private var sheet: String?
    @State private var riskPermission: String?

    init(model: AppModel) {
        self.model = model
        self.shared = model.hostSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            header(L.generalNav()) { model.pop() }
                .accessibilityIdentifier("generalSettings")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if shared.saving {
                        settingsMessage(L.saving())
                    } else if shared.loading {
                        settingsMessage(L.loading())
                    } else if shared.online && !shared.ready {
                        settingsMessage(L.unavailable())
                    }
                    if let error = shared.error {
                        settingsMessage(error, error: true)
                        if shared.online {
                            Button(L.retry()) { shared.dismissError(); shared.refresh() }
                                .disabled(shared.loading || shared.saving)
                                .padding(.horizontal, 22)
                        }
                    }
                    card {
                        if model.ops.contains("permissions.catalog") {
                            nav(L.t("权限", "Permission"), "hand.raised", value: defaultPermissionLabel, divider: true) {
                                sheet = "perm"
                            }
                            .disabled(!model.isOnline || !shared.writable(.permission))
                        }
                        picker(L.language(), selection: Binding(
                            get: { model.language },
                            set: { model.setLanguage($0); sheet = nil }
                        ), divider: true) {
                            Text("中文").tag(AppLanguage.zh)
                            Text("English").tag(AppLanguage.en)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L.appearance()).foregroundStyle(T.ink)
                            HStack(spacing: 8) {
                                appearanceCard(.light, L.light(), "sun.max")
                                appearanceCard(.dark, L.dark(), "moon")
                                appearanceCard(.system, L.followSystem(), "desktopcomputer")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        Divider().padding(.leading, 16)
                        fontRow
                        nav(L.workDetails(), "list.bullet", value: transcriptText(model.transcriptView)) {
                            sheet = "transcript"
                        }
                        .disabled(!shared.writable(.transcript))
                        nav(L.collapseTiming(), "rectangle.compress.vertical", value: collapseText(model.collapseTiming)) {
                            sheet = "collapse"
                        }
                        .disabled(!model.isOnline)
                        HStack {
                            VStack(alignment: .leading) {
                                Text(L.t("显示代码工作视图", "Show coding view")).foregroundStyle(T.ink)
                                Text(L.t("开启后，显示轨迹、本轮代码差异，可选择完整的 Agent 预设切换", "Shows trajectory, code diffs, and all Agent presets"))
                                    .font(.caption).foregroundStyle(T.text3)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { model.showCodeWorkView },
                                set: { shared.write(.codeWork, value: .bool($0)) }
                            ))
                            .labelsHidden()
                            .disabled(!shared.writable(.codeWork))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        Divider().padding(.leading, 16)
                        nav(L.t("繁忙时的发送行为", "Send behavior while busy"), "paperplane", value: model.busySend == .steer ? L.steerSend() : L.queueSend()) {
                            sheet = "busy"
                        }
                        .disabled(!shared.writable(.busySend))
                        nav(L.performanceUsage(), "speedometer", value: model.performanceUsage == .detailed ? L.detailed() : L.compact()) {
                            sheet = "perf"
                        }
                        .disabled(!shared.writable(.performance))
                        if shared.namespace(.sessionLog) != nil {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(sessionLogUploadLabel(english: L.en)).foregroundStyle(T.ink)
                                    Text(L.t("帮助改进 DeepSeek 模型与产品", "Help improve DeepSeek models and products.")).font(.caption).foregroundStyle(T.text3)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { shared.value(.sessionLog)?.bool() == true },
                                    set: { shared.write(.sessionLog, value: .bool($0)) }
                                ))
                                .labelsHidden()
                                .disabled(!shared.writable(.sessionLog))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            Divider().padding(.leading, 16)
                        }
                        if shared.hasField(.linkOpening) {
                            nav(L.linkOpening(), "link", value: shared.value(.linkOpening)?.str() ?? "") {
                                sheet = "links"
                            }
                            .disabled(!shared.writable(.linkOpening))
                        }
                        HStack {
                            Text(L.t("代码自动换行", "Wrap code")).foregroundStyle(T.ink)
                            Spacer()
                            Toggle("", isOn: Binding(get: { model.codeWordWrap }, set: { model.setCodeWordWrap($0) }))
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    Text("\(L.currentVersion())：\(AppModel.appVersion)")
                        .font(.caption)
                        .foregroundStyle(T.caption)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: Binding(get: { sheet != nil && sheet != "perm" && riskPermission == nil }, set: { if !$0 { sheet = nil } })) {
            optionSheet
        }
        .sheet(isPresented: Binding(get: { sheet == "perm" && riskPermission == nil }, set: { if !$0 { sheet = nil } })) {
            PermissionPickerSheet(
                current: model.defaultPermission,
                catalog: model.permissionCatalog,
                loading: model.permissionCatalogLoading,
                error: model.permissionCatalogError,
                enabled: model.isOnline && shared.writable(.permission),
                forDefaults: true,
                onRefresh: { model.reloadPermissionCatalog() },
                onDismiss: { sheet = nil },
                onPick: { value in
                    if value == "danger-full-access" {
                        riskPermission = value
                    } else if model.permissionCatalog?.allowsDefault(value) == true {
                        shared.write(.permission, value: .string(value)) { sheet = nil }
                    }
                }
            )
        }
        .sheet(isPresented: Binding(get: { riskPermission != nil }, set: { if !$0 { riskPermission = nil } })) {
            if let value = riskPermission {
                PermissionRiskSheet(
                    preset: value,
                    enabled: model.isOnline && shared.writable(.permission) && model.permissionCatalog?.allowsDefault(value) == true,
                    forDefaults: true,
                    onDismiss: { riskPermission = nil; sheet = nil },
                    onConfirm: {
                        shared.write(.permission, value: .string(value)) {
                            riskPermission = nil
                            sheet = nil
                        }
                    }
                )
            }
        }
        .onAppear { if model.ops.contains("permissions.catalog") { model.reloadPermissionCatalog() } }
    }

    @ViewBuilder
    private var fontRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading) {
                Text(L.fontSize()).foregroundStyle(T.ink)
                Text(L.t("仅影响会话内容的字号", "Only affects conversation content")).font(.caption).foregroundStyle(T.text3)
            }
            Spacer()
            Menu {
                ForEach(Array(ConversationFontSize.range), id: \.self) { size in
                    Button(conversationFontSizeLabel(size)) { model.setFontSize(size) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(conversationFontSizeLabel(model.fontSize)).foregroundStyle(T.text2)
                    Text("⌄")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(T.text3)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(T.fill, in: Capsule())
            }
            .accessibilityLabel(L.fontSize())
            .accessibilityValue(conversationFontSizeLabel(model.fontSize))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        Divider().padding(.leading, 16)
    }

    private func appearanceCard(_ value: Appearance, _ title: String, _ system: String) -> some View {
        let selected = model.appearance == value
        return Button {
            model.setAppearance(value)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: system)
                    .font(.system(size: 18))
                    .foregroundStyle(T.ink)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(T.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? T.fill2 : T.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? T.borderStrong : T.border, lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityLabel(title)
    }

    private var defaultPermissionLabel: String {
        let value = model.defaultPermission
        return permissionLabel(value: value, option: model.permissionCatalog?.find(value))
    }

    @ViewBuilder
    private var optionSheet: some View {
        NavigationStack {
            List {
                switch sheet {
                case "transcript":
                    ForEach(TranscriptView.allCases, id: \.rawValue) { mode in
                        Button(transcriptText(mode)) {
                            shared.write(.transcript, value: .string(mode.rawValue)) { sheet = nil }
                        }
                    }
                case "collapse":
                    ForEach(CollapseTiming.allCases, id: \.rawValue) { mode in
                        Button(collapseText(mode)) {
                            model.collapseTiming = mode
                            sheet = nil
                        }
                    }
                case "busy":
                    Button(L.queueSend()) { model.setBusySend(.queue); sheet = nil }
                    Button(L.steerSend()) { model.setBusySend(.steer); sheet = nil }
                case "perf":
                    ForEach(PerformanceUsage.allCases, id: \.rawValue) { mode in
                        Button(mode == .detailed ? L.detailed() : L.compact()) {
                            shared.write(.performance, value: .string(mode.rawValue)) { sheet = nil }
                        }
                    }
                case "perm":
                    EmptyView()
                case "links":
                    let current = shared.value(.linkOpening)?.str()
                    ForEach(["in-app", "system"], id: \.self) { value in
                        Button(value == "system" ? L.t("系统浏览器", "System browser") : L.t("应用内", "In-app")) {
                            shared.write(.linkOpening, value: .string(value)) { sheet = nil }
                        }
                        .disabled(current == value)
                    }
                default:
                    EmptyView()
                }
            }
            .navigationTitle(sheetTitle)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.cancel()) { sheet = nil } } }
        }
    }

    private var sheetTitle: String {
        switch sheet {
        case "transcript": return L.workDetails()
        case "collapse": return L.collapseTiming()
        case "busy": return L.t("繁忙时的发送行为", "Send behavior while busy")
        case "perf": return L.performanceUsage()
        case "perm": return L.t("权限", "Permission")
        case "links": return L.linkOpening()
        default: return ""
        }
    }
}

func transcriptText(_ mode: TranscriptView) -> String {
    switch mode {
    case .compact: return L.t("精简", "Compact")
    case .standard: return L.t("标准", "Standard")
    case .detailed: return L.t("详细", "Detailed")
    case .verbose: return L.t("完整", "Verbose")
    }
}

func collapseText(_ mode: CollapseTiming) -> String {
    switch mode {
    case .completion: return L.t("本轮完成后", "After the turn completes")
    case .nextInput: return L.t("下次发送后", "After the next send")
    }
}

func settingsMessage(_ text: String, error: Bool = false) -> some View {
    Text(text)
        .font(.footnote)
        .foregroundStyle(error ? T.err : T.text3)
        .padding(.horizontal, 22)
}

func header(_ title: String, back: @escaping () -> Void) -> some View {
    HStack {
        Button(action: back) { Image(systemName: "chevron.left").foregroundStyle(T.ink) }
        Text(title).font(.headline).foregroundStyle(T.ink)
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(T.surface)
}

func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) { content() }
        .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
        .padding(.horizontal, 16)
}

func nav(_ title: String, _ system: String, value: String? = nil, divider: Bool = true, action: @escaping () -> Void) -> some View {
    VStack(spacing: 0) {
        Button(action: action) {
            HStack {
                Image(systemName: system).foregroundStyle(T.text2)
                Text(title).foregroundStyle(T.ink)
                Spacer()
                if let value, !value.isEmpty {
                    Text(value).font(.subheadline).foregroundStyle(T.text3).lineLimit(1)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(T.text3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        if divider { Divider().padding(.leading, 16) }
    }
}

func picker<Selection: Hashable, Content: View>(
    _ title: String,
    selection: Binding<Selection>,
    divider: Bool = true,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(spacing: 0) {
        HStack {
            Text(title).foregroundStyle(T.ink)
            Spacer()
            Picker("", selection: selection, content: content)
                .labelsHidden()
                .tint(T.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        if divider { Divider().padding(.leading, 16) }
    }
}
