import SwiftUI
import DSHProtocol

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var lastOps: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            settingsShellHeader { model.pop() }
            ScrollView {
                settingsNavCard {
                    nav(
                        L.generalNav(),
                        row: .general,
                        official: .settingsOutlineRegular
                    ) { model.push(.general) }
                    nav(
                        L.modelsNav(),
                        row: .models,
                        official: .dataOutline,
                        divider: hasPresets || hasPluginSettings,
                        enabled: model.isOnline
                    ) { model.push(.models) }
                    if hasPresets {
                        nav(
                            L.agentPresets(),
                            row: .presets,
                            official: .agentPreset,
                            divider: hasPluginSettings,
                            enabled: model.isOnline
                        ) { model.push(.presets) }
                    }
                    if hasPluginSettings {
                        nav(
                            L.builtinPluginsNav(),
                            row: .plugins,
                            divider: false,
                            enabled: model.isOnline
                        ) {
                            model.push(.builtinPlugins)
                        } icon: {
                            PluginPinwheelIcon(
                                size: CGFloat(settingsNavIconSizePoints),
                                color: T.text2
                            )
                        }
                    }
                }
                .padding(.top, CGFloat(settingsNavGapPoints))
                .padding(.bottom, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        // `.contain` keeps header children (navBack) addressable; an id on
        // the header HStack itself would swallow navBack.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsShell")
        .onAppear { rememberOps() }
        .onChange(of: model.isOnline) { _ in rememberOps() }
        .onChange(of: model.ops) { _ in rememberOps() }
    }

    private var visibleOps: Set<String> { model.isOnline ? model.ops : lastOps }
    private var hasPluginSettings: Bool { visibleOps.contains("plugins.inventory") }
    private var hasPresets: Bool { visibleOps.contains("presets.list") || visibleOps.contains("presets.settings") }

    private func rememberOps() {
        if model.isOnline && !model.ops.isEmpty { lastOps = model.ops }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var shared: HostSettings
    @State private var sheet: String?
    @State private var permissionSelectOpen = false
    @State private var riskPermission: String?
    @State private var fontsExpanded = false

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
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L.t("权限", "Permission")).foregroundStyle(T.ink)
                                    Text(permissionDefaultDescription(english: L.en))
                                        .font(.caption)
                                        .foregroundStyle(T.text3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                SettingsPermissionSelect(
                                    current: model.defaultPermission,
                                    catalog: model.permissionCatalog,
                                    loading: model.permissionCatalogLoading,
                                    enabled: model.isOnline && shared.writable(.permission),
                                    onSelect: { value in
                                        if value == "danger-full-access" {
                                            riskPermission = value
                                        } else if model.permissionCatalog?.allowsDefault(value) == true {
                                            shared.write(.permission, value: .string(value))
                                        }
                                    },
                                    open: $permissionSelectOpen
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .opacity(model.isOnline && shared.writable(.permission) ? 1 : 0.5)
                            Divider().padding(.leading, 16)
                        }
                        picker(L.language(), selection: Binding(
                            get: { model.language },
                            set: { model.setLanguage($0); sheet = nil }
                        ), divider: true, enabled: shared.writable(.language)) {
                            Text("中文").tag(AppLanguage.zh)
                            Text("English").tag(AppLanguage.en)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L.appearance()).foregroundStyle(T.ink)
                            HStack(spacing: 8) {
                                appearanceCard(.light, L.light(), .appearanceLight)
                                appearanceCard(.dark, L.dark(), .appearanceDark)
                                appearanceCard(.system, L.followSystem(), .appearanceFollowSystem)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        Divider().padding(.leading, 16)
                        SettingsFontSizeRow(
                            role: .text,
                            value: model.fontSize,
                            expanded: fontsExpanded,
                            onToggle: { fontsExpanded.toggle() },
                            onChange: { model.setFontSize($0) }
                        )
                        if fontsExpanded {
                            SettingsFontFamilyRow(
                                role: .text,
                                value: model.textFontFamily,
                                onChange: { model.setTextFontFamily($0) }
                            )
                            SettingsFontFamilyRow(
                                role: .code,
                                value: model.codeFontFamily,
                                onChange: { model.setCodeFontFamily($0) }
                            )
                            SettingsFontSizeRow(
                                role: .code,
                                value: model.codeFontSize,
                                onChange: { model.setCodeFontSize($0) }
                            )
                            SettingsFontFamilyRow(
                                role: .terminal,
                                value: model.terminalFontFamily,
                                onChange: { model.setTerminalFontFamily($0) }
                            )
                            SettingsFontSizeRow(
                                role: .terminal,
                                value: model.terminalFontSize,
                                onChange: { model.setTerminalFontSize($0) }
                            )
                        }
                        preferenceRow(
                            L.workDetails(),
                            workDetailsDescription(english: L.en),
                            value: transcriptText(model.transcriptView),
                            enabled: shared.writable(.transcript)
                        ) { sheet = "transcript" }
                        preferenceRow(
                            L.collapseTiming(),
                            collapseTimingDescription(english: L.en),
                            value: collapseText(model.collapseTiming),
                            enabled: shared.writable(.collapse)
                        ) { sheet = "collapse" }
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
                        preferenceRow(
                            L.t("繁忙时的发送行为", "Send behavior while busy"),
                            busySendDescription(english: L.en),
                            value: model.busySend == .steer ? L.steerSend() : L.queueSend(),
                            enabled: shared.writable(.busySend)
                        ) { sheet = "busy" }
                        preferenceRow(
                            L.performanceUsage(),
                            performanceUsageDescription(english: L.en),
                            value: performanceUsageLabel(detailed: model.performanceUsage == .detailed, english: L.en),
                            enabled: shared.writable(.performance)
                        ) { sheet = "perf" }
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
                            preferenceRow(
                                linkOpeningTitle(english: L.en),
                                linkOpeningDescription(english: L.en),
                                value: shared.value(.linkOpening)?.str().flatMap { value in
                                    value.isEmpty ? nil : linkOpeningLabel(value, english: L.en)
                                },
                                enabled: shared.writable(.linkOpening)
                            ) { sheet = "links" }
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
                        .font(Font.caption)
                        .foregroundStyle(T.caption)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: Binding(get: { sheet != nil && riskPermission == nil }, set: { if !$0 { sheet = nil } })) {
            optionSheet
        }
        .overlay {
            if let value = riskPermission {
                PermissionRiskDialog(
                    preset: value,
                    enabled: model.isOnline && shared.writable(.permission) && model.permissionCatalog?.allowsDefault(value) == true,
                    forDefaults: true,
                    onDismiss: { riskPermission = nil; permissionSelectOpen = false },
                    onConfirm: {
                        shared.write(.permission, value: .string(value)) {
                            riskPermission = nil
                            permissionSelectOpen = false
                        }
                    }
                )
            }
        }
        .onAppear { if model.ops.contains("permissions.catalog") { model.reloadPermissionCatalog() } }
    }

    private func appearanceCard(_ value: Appearance, _ title: String, _ icon: OfficialGlyph.Kind) -> some View {
        let selected = model.appearance == value
        return Button {
            model.setAppearance(value)
        } label: {
            VStack(spacing: 8) {
                OfficialGlyph(kind: icon, size: 18, color: T.ink)
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
        .accessibilityIdentifier("appearance.\(value.rawValue)")
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
                            shared.write(.collapse, value: .string(mode.rawValue)) { sheet = nil }
                        }
                    }
                case "busy":
                    Button(L.queueSend()) { model.setBusySend(.queue); sheet = nil }
                    Button(L.steerSend()) { model.setBusySend(.steer); sheet = nil }
                case "perf":
                    ForEach(PerformanceUsage.allCases, id: \.rawValue) { mode in
                        Button(performanceUsageLabel(detailed: mode == .detailed, english: L.en)) {
                            shared.write(.performance, value: .string(mode.rawValue)) { sheet = nil }
                        }
                    }
                case "links":
                    let current = shared.value(.linkOpening)?.str()
                    ForEach(linkOpeningValues, id: \.self) { value in
                        Button(linkOpeningLabel(value, english: L.en)) {
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
        case "links": return linkOpeningTitle(english: L.en)
        default: return ""
        }
    }
}

func transcriptText(_ mode: TranscriptView) -> String {
    transcriptViewLabel(mode, english: L.en)
}

func collapseText(_ mode: CollapseTiming) -> String {
    collapseTimingLabel(mode, english: L.en)
}

func preferenceRow(
    _ title: String,
    _ description: String? = nil,
    value: String? = nil,
    divider: Bool = true,
    enabled: Bool = true,
    action: @escaping () -> Void
) -> some View {
    VStack(spacing: 0) {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).foregroundStyle(T.ink)
                    if let description, !description.isEmpty {
                        Text(description).font(.caption).foregroundStyle(T.text3)
                    }
                }
                Spacer()
                if let value, !value.isEmpty {
                    Text(value).font(Font.subheadline).foregroundStyle(T.text3).lineLimit(2)
                }
                OfficialGlyph(kind: .chevronDown, size: 12, color: T.text2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .opacity(enabled ? 1 : 0.5)
        }
        .disabled(!enabled)
        if divider { Divider().padding(.leading, 16) }
    }
}

func settingsMessage(_ text: String, error: Bool = false) -> some View {
    Text(text)
        .font(Font.footnote)
        .foregroundStyle(error ? T.err : T.text3)
        .padding(.horizontal, 22)
}

func header(_ title: String, back: @escaping () -> Void) -> some View {
    HStack {
        Button(action: back) { OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink) }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("navBack")
        Text(title).font(Font.headline).foregroundStyle(T.ink)
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(T.surface)
}

/// Keep the settings-home title at the same semantic size as its detail pages.
/// Identifier sits on a background fill so `navBack` stays addressable.
func settingsShellHeader(back: @escaping () -> Void) -> some View {
    HStack(spacing: CGFloat(settingsNavCellGapPoints)) {
        Button(action: back) { OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink) }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("navBack")
        Text(L.settings())
            .font(.headline)
            .frame(minHeight: CGFloat(settingsNavTitleLineHeightPoints), alignment: .leading)
            .foregroundStyle(T.ink)
        Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background {
        Rectangle()
            .fill(T.surface)
            .accessibilityElement()
            .accessibilityIdentifier(settingsShellHeaderIdentifier())
            .allowsHitTesting(false)
    }
}

func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) { content() }
        .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
        .padding(.horizontal, 16)
}

/// Phone wrap of the overlay left-nav list in desktop settings-card material
/// (`--dsw-alias-settings-card-*` + `--dsw-radius-lg`). Identifier sits on the
/// fill so nav row hits stay addressable. Fill, row rects, and stroke share
/// one `--dsw-radius-lg` shape — an unclipped `Rectangle` fill paints the
/// four corners outside the curve with card colour.
func settingsNavCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: CGFloat(settingsCardRadiusPoints))
    return VStack(spacing: 0) { content() }
        .background {
            shape
                .fill(T.settingsCard)
                .accessibilityElement()
                .accessibilityIdentifier(settingsNavCardIdentifier())
                .allowsHitTesting(false)
        }
        .clipShape(shape)
        .overlay(
            shape.stroke(T.settingsCardStroke, lineWidth: CGFloat(settingsCardStrokeWidthPoints))
        )
        .padding(.horizontal, 16)
}

func nav(
    _ title: String,
    row: SettingsNavRowId,
    official: OfficialGlyph.Kind,
    value: String? = nil,
    divider: Bool = true,
    enabled: Bool = true,
    action: @escaping () -> Void
) -> some View {
    nav(title, row: row, value: value, divider: divider, enabled: enabled, action: action) {
        OfficialGlyph(kind: official, size: CGFloat(settingsNavIconSizePoints), color: T.text2)
    }
}

func nav<Icon: View>(
    _ title: String,
    row: SettingsNavRowId,
    value: String? = nil,
    divider: Bool = true,
    enabled: Bool = true,
    action: @escaping () -> Void,
    @ViewBuilder icon: () -> Icon
) -> some View {
    VStack(spacing: 0) {
        Button(action: action) {
            HStack(spacing: CGFloat(settingsNavCellGapPoints)) {
                icon()
                    .frame(
                        width: CGFloat(settingsNavIconSizePoints),
                        height: CGFloat(settingsNavIconSizePoints)
                    )
                    .foregroundStyle(T.text2)
                Text(title)
                    .font(.body)
                    .frame(minHeight: CGFloat(settingsNavCellLineHeightPoints), alignment: .leading)
                    .foregroundStyle(T.ink)
                Spacer(minLength: 0)
                if let value, !value.isEmpty {
                    Text(value).font(Font.subheadline).foregroundStyle(T.text3).lineLimit(1)
                }
                OfficialGlyph(kind: .chevronRight, size: 12, color: T.text3)
            }
            .padding(.leading, CGFloat(settingsNavCellPaddingLeadingPoints))
            .padding(.trailing, CGFloat(settingsNavCellPaddingTrailingPoints))
            .padding(.top, CGFloat(settingsNavCellPaddingTopPoints))
            .padding(.bottom, CGFloat(settingsNavCellPaddingBottomPoints))
            .frame(minHeight: CGFloat(settingsNavCellHeightPoints), alignment: .center)
            .contentShape(Rectangle())
            .background {
                Rectangle()
                    .fill(T.settingsCard)
                    .accessibilityElement()
                    .accessibilityIdentifier(settingsNavRowIdentifier(row.rawValue))
                    .allowsHitTesting(false)
            }
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .disabled(!enabled)
        if divider { Divider().padding(.leading, 16) }
    }
}

func picker<Selection: Hashable, Content: View>(
    _ title: String,
    selection: Binding<Selection>,
    divider: Bool = true,
    enabled: Bool = true,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(spacing: 0) {
        HStack {
            Text(title).foregroundStyle(T.ink)
            Spacer()
            Picker("", selection: selection, content: content)
                .labelsHidden()
                .tint(T.ink)
                .accentColor(T.ink)
                .disabled(!enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .opacity(enabled ? 1 : 0.5)
        if divider { Divider().padding(.leading, 16) }
    }
}

/// Desktop `ui-theme` `FontSizeRow`: title + description + stepper pill + `px`.
/// Touch always shows the arrows (desktop reveals them on hover). Phone-local, always enabled.
struct SettingsFontSizeRow: View {
    let role: ThemeFontRole
    let value: Int
    var expanded: Bool? = nil
    var onToggle: (() -> Void)? = nil
    let onChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(themeFontSizeTitle(role, english: L.en)).foregroundStyle(T.ink)
                    Text(themeFontSizeDescription(role, english: L.en))
                        .font(.caption)
                        .foregroundStyle(T.text3)
                }
                Spacer(minLength: 8)
                HStack(spacing: 0) {
                    Text("\(value)")
                        .font(Font.subheadline)
                        .foregroundStyle(T.ink)
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 0) {
                        stepButton(increase: true)
                        stepButton(increase: false)
                    }
                    .frame(width: 32)
                }
                .frame(width: 72, height: 36)
                .background(T.fill2, in: RoundedRectangle(cornerRadius: 8))
                Text(themeFontSizeUnit)
                    .font(Font.subheadline)
                    .foregroundStyle(T.text2)
                if let onToggle {
                    Button(action: onToggle) {
                        OfficialGlyph(kind: .chevronDown, size: 12, color: T.text2)
                            .rotationEffect(.degrees(expanded == true ? 180 : 0))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 40, height: 40)
                    .accessibilityLabel(themeFontSettingsMoreLabel(english: L.en))
                    .accessibilityIdentifier("fontSettingsToggle")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityValue(expanded == true ? L.t("已展开", "Expanded") : L.t("已折叠", "Collapsed"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            Divider().padding(.leading, 16)
        }
    }

    private func stepButton(increase: Bool) -> some View {
        let enabled = increase ? themeFontSizeCanIncrease(role, value: value) : themeFontSizeCanDecrease(role, value: value)
        let label = themeFontSizeStepLabel(role, increase: increase, english: L.en)
        return Button {
            onChange(themeFontSizeStepped(role, value: value, delta: increase ? 1 : -1))
        } label: {
            OfficialGlyph(kind: increase ? .chevronUp : .chevronDown, size: 9, color: enabled ? T.ink : T.caption)
                .frame(width: 17, height: 12)
                .background(T.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                .frame(width: 32, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// Desktop `ui-theme` `FontFamilyRow`: commit on blur / Enter, max 200, placeholder 「默认」.
struct SettingsFontFamilyRow: View {
    let role: ThemeFontRole
    let value: String
    let onChange: (String) -> Void

    @State private var draft = ""
    @State private var dirty = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(themeFontFamilyTitle(role, english: L.en)).foregroundStyle(T.ink)
                    Text(themeFontFamilyDescription(role, english: L.en))
                        .font(.caption)
                        .foregroundStyle(T.text3)
                }
                TextField(themeFontFamilyPlaceholder(english: L.en), text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onChange(of: draft) { _ in
                        if focused { dirty = true }
                    }
                    .onSubmit { commit() }
                    .onChange(of: focused) { on in
                        if !on { commit() }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(T.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.borderStrong, lineWidth: 0.5))
                    .accessibilityLabel(themeFontFamilyTitle(role, english: L.en))
                    .accessibilityIdentifier(themeFontFamilyFieldTag(role))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            Divider().padding(.leading, 16)
        }
        .onAppear { draft = value }
        .onChange(of: value) { next in
            if !dirty { draft = next }
        }
    }

    private func commit() {
        guard dirty else { return }
        let normalized = normalizeFontFamily(themeFontFamilyDraft(draft))
        draft = normalized
        dirty = false
        if normalized != value { onChange(normalized) }
    }
}
