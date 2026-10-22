import SwiftUI
import DSHProtocol

struct PluginsScreen: View {
    @ObservedObject var model: AppModel
    var onCreatePlugin: () -> Void = {}
    @State private var creatorState = "idle"
    @State private var bundles: [JSONValue] = []
    @State private var plugins: [JSONValue] = []
    @State private var namespaces: [JSONValue] = []
    @State private var managementAvailable = false
    @State private var writable = false
    @State private var loading = false
    @State private var busy = false
    @State private var error: String?
    @State private var configError: String?
    @State private var outcome: JSONValue?
    @State private var detail: String?
    @State private var moreOpen = false
    @State private var builtin: PluginBuiltinItem?
    @State private var addMenuOpen = false
    @State private var config: JSONValue?
    @State private var installOpen = false
    @State private var installSpec = ""
    @State private var catalogEnabled = false
    @State private var registry = ""
    @State private var registries: [String] = []
    @State private var resolvedRegistry: String?
    @State private var installCheckTask: Task<Void, Never>?
    @State private var installResult: JSONValue?
    @State private var installError: String?
    @State private var installRequest: String?
    @State private var installing = false
    @State private var checking = false
    @State private var cancelling = false
    @State private var uninstall: JSONValue?
    @State private var showPluginInfo = false

    var body: some View {
        if let builtin {
            PluginBuiltinConfiguration(model: model, item: builtin, namespaces: namespaces,
                                       writable: model.isOnline && writable && model.ops.contains("plugins.settingsMutate")) {
                self.builtin = nil
                Task { await refresh() }
            }
        } else if let config {
            PluginConfigurationView(model: model, namespace: config, writable: model.isOnline && writable && model.ops.contains("plugins.settingsMutate"), onBack: {
                self.config = nil
                Task { await refresh() }
            })
        } else {
            list
        }
    }

    private var locked: Bool { busy || loading || installing || checking || installRequest != nil }

    /// Host `managementAvailable` after `plugins.list`. UITest fixture has no
    /// Host; advertise the add split when `plugins.install` is seeded.
    private var showsPluginAddMenu: Bool {
        managementAvailable || (model.uiTestFixture && model.ops.contains("plugins.install"))
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if selected == nil { pluginsHeader }
                if let error { Text(error).font(.system(size: 13)).foregroundStyle(T.err) }
                if let configError { Text(configError).font(.system(size: 13)).foregroundStyle(T.err) }
                if let outcome { Text(pluginChangeText(outcome, en: L.en)).font(.system(size: 13)).foregroundStyle(T.text2) }
                if loading || busy { ProgressView().frame(maxWidth: .infinity) }
                if let selected { bundleDetail(selected) } else { market }
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity)
        }
        .background(T.bg.ignoresSafeArea())
        .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in
            showPluginInfo = false
            addMenuOpen = false
        })
        .overlayPreferenceValue(PluginHeaderAnchors.self) { anchors in
            if let presentation = anchors.values.first(where: { $0.content != nil }), let content = presentation.content {
                GeometryReader { canvas in
                    SettingsSelectLayout(anchor: canvas[presentation.anchor], viewport: canvas.size) {
                        Color.clear.contentShape(Rectangle()).onTapGesture {
                            showPluginInfo = false
                            addMenuOpen = false
                        }
                        content
                    }
                }
            }
        }
        .accessibilityHidden(installOpen || uninstall != nil)
        .overlay {
            if installOpen { installDialog }
            if let uninstall {
                PluginUninstallDialog(title: pluginTitle(uninstall, english: L.en),
                                      onCancel: { self.uninstall = nil }) {
                    if let name = uninstall["name"].str() {
                        mutate { try await $0.pluginsUninstall(bundle: name) }
                    }
                    self.uninstall = nil
                }
            }
        }
        .task(id: "\(model.activeId ?? "")-\(model.pluginCatalogRevision)") {
            if model.uiTestFixture {
                bundles = PluginManagerFixture.bundles
                plugins = PluginManagerFixture.plugins
                namespaces = PluginManagerFixture.namespaces
                managementAvailable = true
                writable = true
            } else if model.isOnline { await refresh() }
        }
        .task(id: installRequest ?? "") {
            guard let requestId = installRequest, !installing, let client = model.clientOrNull(),
                  model.ops.contains("plugins.waitForInstall") else { return }
            installing = true
            do {
                installResult = try await client.pluginsWaitForInstall(requestId: requestId)
                installRequest = nil
                await refresh()
            } catch {
                installError = error.localizedDescription
            }
            installing = false
        }
        .onDisappear {
            installCheckTask?.cancel()
            installCheckTask = nil
            checking = false
        }
    }

    private var selected: JSONValue? {
        bundles.first { $0["name"].str() == detail }
    }

    private var creatorPresent: Bool {
        model.presetRoster.contains { $0["id"].str() == "cordis" }
    }

    private var creatorDescription: String {
        switch creatorState {
        case "idle", "loading": return pluginAddCreatePluginChecking(english: L.en)
        case "ready":
            return creatorPresent
                ? pluginAddCreatePluginDescription(english: L.en)
                : pluginAddCreatePluginMissing(english: L.en)
        default:
            return pluginAddCreatePluginUnavailable(english: L.en)
        }
    }

    private func loadCreator() {
        if creatorState == "loading" { return }
        creatorState = "loading"
        Task {
            do {
                guard let client = model.clientOrNull() else {
                    creatorState = "unavailable"
                    return
                }
                let operation: String
                if model.ops.contains("presets.settings") { operation = "presets.settings" }
                else if model.ops.contains("presets.list") { operation = "presets.list" }
                else {
                    creatorState = "unavailable"
                    return
                }
                let result = try await client.call(operation)
                model.presetRoster = PresetPolicy.parseRoster(result)
                creatorState = "ready"
            } catch is CancellationError {
                return
            } catch {
                creatorState = "unavailable"
            }
        }
    }

    private var pluginsHeader: some View {
        Group {
            if moreOpen {
                HStack(spacing: 8) {
                    Button { moreOpen = false } label: {
                        OfficialGlyph(kind: .chevronLeft, size: 20, color: T.text2).frame(width: 28, height: 28)
                    }
                    .accessibilityLabel(L.t("返回插件列表", "Back to plugins"))
                    .accessibilityIdentifier("pluginMoreBack")
                    Text(L.t("实验性插件", "Experimental plugins")).font(.system(size: 20, weight: .medium))
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 0) { pageHeading.fixedSize(); Spacer(minLength: 16); toolbar }
                    VStack(alignment: .leading, spacing: 16) { pageHeading; toolbar }
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(T.ink)
    }

    private var pageHeading: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button(action: back) {
                    OfficialGlyph(kind: .chevronLeft, size: 20, color: T.text2)
                }
                .accessibilityLabel(L.t("返回", "Back"))
                Text(L.pluginsNav()).font(.system(size: 20, weight: .medium))
                    .frame(minHeight: 28, alignment: .leading)
                    .accessibilityIdentifier("pluginPageTitle")
            }
            HStack(spacing: 4) {
                Text(L.pluginsHint()).font(.system(size: 13)).foregroundStyle(T.text2)
                Button {
                    addMenuOpen = false
                    showPluginInfo.toggle()
                } label: {
                    OfficialGlyph(kind: .infoOutline, size: 14, color: T.caption)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(pluginInfoLabel(english: L.en))
                .accessibilityIdentifier("pluginInfoButton")
                .anchorPreference(key: PluginHeaderAnchors.self, value: .bounds) {
                    ["info": PluginHeaderPresentation(anchor: $0, content: showPluginInfo ? AnyView(pluginInfoTooltip) : nil)]
                }
            }
            .frame(minHeight: 20, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Button(action: reload) {
                OfficialGlyph(kind: .refreshOutline, size: 16, color: T.caption)
                    .frame(width: 28, height: 28).contentShape(Rectangle())
            }
            .accessibilityLabel(L.refresh())
            .disabled(!model.isOnline || locked)
            if (showsPluginAddMenu && model.ops.contains("plugins.install")) || installRequest != nil {
                PluginAddMenu(
                    enabled: installRequest != nil || (model.isOnline && !locked),
                    creatorEnabled: creatorState == "ready" && creatorPresent && model.ops.contains("sessions.create"),
                    creatorDescription: creatorDescription, expanded: $addMenuOpen,
                    onOpen: { showPluginInfo = false; loadCreator() },
                    onInstall: { openInstall() }, onCreatePlugin: onCreatePlugin
                )
            }
        }
        .fixedSize()
    }

    /// Desktop `Tooltip`: fade-in bubble under `(i)`, never a system popover.
    private var pluginInfoTooltip: some View {
        Text(pluginInfoDescription(english: L.en))
            .font(Font.system(size: CGFloat(pluginInfoTooltipFontSizePoints)))
            .lineSpacing(CGFloat(pluginInfoTooltipLineHeightPoints) - 16)
            .foregroundStyle(T.tooltipFg)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, CGFloat(pluginInfoTooltipPaddingHorizontalPoints))
            .padding(.vertical, CGFloat(pluginInfoTooltipPaddingVerticalPoints))
            .frame(maxWidth: CGFloat(pluginInfoTooltipMaxWidthPoints), alignment: .leading)
            .background(
                T.tooltipBg,
                in: RoundedRectangle(cornerRadius: CGFloat(pluginInfoTooltipRadiusPoints), style: .continuous)
            )
            .accessibilityIdentifier("pluginInfoTooltip")
    }

    @ViewBuilder
    private var market: some View {
        let groups = pluginMarketGroups(bundles)
        let ordered = groups.official.enumerated().sorted {
            let lhs = pluginOptionalRank($0.element["name"].str())
            let rhs = pluginOptionalRank($1.element["name"].str())
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }.map(\.element)
        let basics = PluginBuiltinItem.available(in: namespaces)
        if moreOpen {
            VStack(spacing: 2) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, bundle in marketRow(bundle) }
            }
        } else {
            if !basics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    groupHeading(L.t("内置插件配置", "Built-in plugin settings"))
                    VStack(spacing: 2) {
                        ForEach(basics) { item in
                            Button { builtin = item } label: {
                                HStack(spacing: 14) {
                                    PluginArtwork(kind: item.artwork)
                                        .frame(width: 48, height: 48)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.borderL3, lineWidth: 0.5))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title).font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink).lineLimit(1)
                                            .frame(minHeight: 20, alignment: .leading)
                                        Text(item.description).font(.system(size: 13)).foregroundStyle(T.text3).lineLimit(1)
                                            .frame(minHeight: 18, alignment: .leading)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 8).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("pluginBuiltin.\(item.id)")
                        }
                    }
                }
                .accessibilityElement(children: .contain).accessibilityIdentifier("pluginGroup.basic")
            }
            if !ordered.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        groupHeading(L.t("实验性插件", "Experimental plugins"))
                        Spacer()
                        Button { moreOpen = true; showPluginInfo = false; addMenuOpen = false } label: {
                            HStack(spacing: 4) {
                                Text(L.t("更多", "More")).font(.system(size: 14))
                                OfficialGlyph(kind: .chevronRight, size: 14, color: T.text3)
                            }.foregroundStyle(T.text3)
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("pluginMore")
                    }
                    VStack(spacing: 2) {
                        ForEach(Array(ordered.filter {
                            pluginOptionalVisible(name: $0["name"].str(), enabled: $0["enabled"].bool() == true, expanded: false)
                        }.enumerated()), id: \.offset) { _, bundle in marketRow(bundle) }
                    }
                }
                .accessibilityElement(children: .contain).accessibilityIdentifier("pluginGroup.extensions")
            }
            if !groups.installed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    groupHeading(L.installedPlugins())
                    VStack(spacing: 2) {
                        ForEach(Array(groups.installed.enumerated()), id: \.offset) { _, bundle in marketRow(bundle) }
                    }
                }
                .accessibilityElement(children: .contain).accessibilityIdentifier("pluginGroup.bundles")
            }
            if !loading && error == nil && basics.isEmpty && groups.official.isEmpty && groups.installed.isEmpty {
                Text(pluginsEmptyLabel(english: L.en)).font(.system(size: 13)).foregroundStyle(T.text3)
            }
        }
    }

    private func groupHeading(_ title: String) -> some View {
        Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink)
            .frame(minHeight: 22, alignment: .leading)
    }

    private func canToggle(_ bundle: JSONValue) -> Bool {
        model.isOnline && managementAvailable && !locked && model.ops.contains("plugins.setEnabled")
            && bundle["readOnlyReason"].isNull
            && (bundle["enabled"].bool() == true || bundle["error"].isNull || pluginNeedsInstallToEnable(bundle))
    }

    private func marketRow(_ bundle: JSONValue) -> some View {
        let name = bundle["name"].str() ?? ""
        return HStack(spacing: 14) {
            Button { detail = name; showPluginInfo = false; addMenuOpen = false } label: {
                HStack(spacing: 14) {
                    PluginMetadataArtwork(icon: bundle["meta"]["icon"].str())
                        .frame(width: 48, height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.borderL3, lineWidth: 0.5))
                    VStack(alignment: .leading, spacing: 4) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { packageTitle(bundle); packageTags(bundle) }
                            VStack(alignment: .leading, spacing: 4) { packageTitle(bundle); packageTags(bundle) }
                        }
                        let description = pluginDescription(bundle, english: L.en)
                        if !description.isEmpty {
                            Text(description).font(.system(size: 13)).foregroundStyle(T.text3).lineLimit(1)
                                .frame(minHeight: 18, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("pluginPackage.\(name)")
            PluginEnableSwitch(isOn: bundle["enabled"].bool() == true, enabled: canToggle(bundle),
                               label: L.t("启用 ", "Enable ") + pluginTitle(bundle, english: L.en)) {
                toggleBundle(bundle, enabled: $0)
            }
            .accessibilityIdentifier("pluginToggle.\(name)")
        }
        .padding(.vertical, 8)
    }

    private func packageTitle(_ bundle: JSONValue) -> some View {
        Text(pluginTitle(bundle, english: L.en)).font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink).lineLimit(1)
            .frame(minHeight: 20, alignment: .leading)
    }

    private func packageTags(_ bundle: JSONValue) -> some View {
        HStack(spacing: 8) {
            if pluginExperimental(bundle) { packageTag(L.experimentalBadge(), tint: T.businessPrimary, fill: T.tint) }
            if !bundle["error"].isNull { packageTag(L.t("异常", "Problem"), tint: T.err, fill: T.err.opacity(0.1)) }
            if bundle["availability"].str() == "missing" {
                packageTag(bundle["installed"].bool() == true ? L.t("包不可用", "Package unavailable") : L.t("未安装", "Not installed"),
                           tint: T.text2, fill: T.fill2)
            }
        }
    }

    private func packageTag(_ text: String, tint: Color, fill: Color) -> some View {
        Text(text).font(.system(size: 10)).foregroundStyle(tint)
            .padding(.horizontal, 7).frame(height: 18).background(fill, in: Capsule())
    }

    private func bundleDetail(_ bundle: JSONValue) -> some View {
        PluginPackageDetail(bundle: bundle, plugins: plugins, namespaces: namespaces,
                            locked: locked, canToggle: canToggle(bundle),
                            canUninstall: model.isOnline && model.ops.contains("plugins.uninstall")
                                && bundle["removable"].bool() == true && bundle["readOnlyReason"].isNull,
                            canToggleRows: model.isOnline && model.ops.contains("plugins.setEnabled"),
                            onBack: { detail = nil }, onToggle: { toggleBundle(bundle, enabled: $0) },
                            onUninstall: { uninstall = bundle },
                            onToggleRow: { id, enabled in mutate { try await $0.pluginsSetEnabled(enabled: enabled, id: id) } },
                            onConfigure: { config = $0 },
                            backTitle: moreOpen ? L.t("实验性插件", "Experimental plugins") : L.pluginsNav())
    }

    private var installDialog: some View {
        PluginInstallDialog(
            spec: $installSpec, registry: $registry, registries: registries,
            resolvedRegistry: resolvedRegistry,
            checking: checking, installing: installing, pending: installRequest != nil,
            cancelling: cancelling,
            canInstall: model.isOnline && !busy && !loading && model.ops.contains("plugins.install"),
            canCancel: installRequest != nil && model.ops.contains("plugins.cancelInstall"),
            error: installError, result: installResult.map { pluginChangeText($0, en: L.en) },
            onInstall: runInstall,
            onCancel: { if let installRequest { cancelInstall(installRequest) } },
            onClose: closeInstall
        )
    }

    private func closeInstall() {
        if checking {
            installCheckTask?.cancel()
            installCheckTask = nil
            checking = false
        }
        installOpen = false
    }

    private func back() {
        if config != nil { config = nil }
        else if detail != nil { detail = nil }
        else if installRequest != nil || installing { installOpen = true }
        else { model.pop() }
    }

    private func toggleBundle(_ bundle: JSONValue, enabled: Bool) {
        let name = bundle["name"].str() ?? ""
        if enabled && pluginNeedsInstallToEnable(bundle), let spec = bundle["installTarget"]["spec"].str() {
            openInstall(spec: spec, enable: true)
            return
        }
        mutate { try await $0.pluginsSetEnabled(enabled: enabled, bundle: name) }
    }

    private func reload() {
        guard !locked else { return }
        Task { await refresh() }
    }

    private func refresh() async {
        loading = true
        error = nil
        defer { loading = false }
        guard model.ops.contains("plugins.list"), let client = model.clientOrNull() else { return }
        do {
            let data = try await client.pluginsList()
            managementAvailable = data["managementAvailable"].bool() != false
            if !managementAvailable {
                throw PocketError(code: "unavailable", message: L.t("本部署没有可管理的 profile，无法安装或启停插件。", "This deployment runs without a manageable profile, so plugins cannot be installed or switched here."))
            }
            bundles = (data["bundles"].arr() ?? []).filter { name in
                guard let name = name["name"].str() else { return true }
                return !hiddenProfileBundles.contains(name)
            }
            plugins = data["plugins"].arr() ?? []
            if detail != nil, bundles.contains(where: { $0["name"].str() == detail }) == false { detail = nil }
            if model.ops.contains("plugins.settingsDescribe") {
                do {
                    let settings = try await client.pluginsSettingsDescribe()
                    namespaces = settings["namespaces"].arr() ?? []
                    writable = settings["writable"].bool() == true
                    configError = nil
                } catch {
                    configError = error.localizedDescription
                    writable = false
                }
            } else {
                namespaces = []
                writable = false
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func mutate(_ block: @escaping (PocketClient) async throws -> JSONValue) {
        guard !locked, model.isOnline, let client = model.clientOrNull() else { return }
        busy = true
        error = nil
        Task {
            do {
                outcome = try await block(client)
                await refresh()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }

    private func openInstall(spec: String = "", enable: Bool = false) {
        showPluginInfo = false
        installOpen = true
        guard installRequest == nil, !installing, !checking else { return }
        if !spec.isEmpty { installSpec = spec }
        installResult = nil
        installError = nil
        catalogEnabled = enable
        guard model.ops.contains("plugins.registries"), model.isOnline, let client = model.clientOrNull() else { return }
        Task {
            do {
                let result = try await client.pluginsRegistries()
                var list = [result["registry"].str()].compactMap { $0 }
                list += (result["fallbackRegistries"].arr() ?? []).compactMap { $0.str() }
                if let resolved = result["resolved"].str() { list.append(resolved) }
                var seen = Set<String>()
                registries = list.filter { seen.insert($0).inserted }
                resolvedRegistry = result["resolved"].str()
            } catch {
                installError = error.localizedDescription
            }
        }
    }

    private func runInstall() {
        let spec = installSpec.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedRegistry = registry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spec.isEmpty, !locked, model.isOnline, model.ops.contains("plugins.install"),
              let client = model.clientOrNull() else { return }
        let enable = catalogEnabled
        checking = true
        installError = nil
        installResult = nil
        installCheckTask = Task {
            do {
                if model.ops.contains("plugins.inspect") {
                    let inspection = try await client.pluginsInspect(spec: spec, registry: selectedRegistry.isEmpty ? nil : selectedRegistry)
                    guard !Task.isCancelled else { return }
                    guard inspection["status"].str() == "accepted" else {
                        installError = inspection["reason"].str()
                            ?? L.t("无法安装此插件。", "This plugin cannot be installed.")
                        checking = false
                        installCheckTask = nil
                        return
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                installError = error.localizedDescription
                checking = false
                installCheckTask = nil
                return
            }
            guard !Task.isCancelled else { return }
            checking = false
            installCheckTask = nil
            let request = UUID().uuidString
            installRequest = request
            installing = true
            do {
                var options: [String: JSONValue] = [
                    "requestId": .string(request),
                    "enabled": .bool(enable),
                ]
                if !selectedRegistry.isEmpty { options["registry"] = .string(selectedRegistry) }
                installResult = try await client.pluginsInstall(spec: spec, options: .object(options))
                installRequest = nil
                await refresh()
            } catch {
                installError = L.t("未确认安装结果，请核对安装状态，勿重复提交。", "Installation outcome unconfirmed. Check its status before retrying.") + "\n" + error.localizedDescription
            }
            installing = false
        }
    }

    private func cancelInstall(_ requestId: String) {
        guard let client = model.clientOrNull() else { return }
        cancelling = true
        Task {
            do {
                installResult = try await client.pluginsCancelInstall(requestId: requestId)
                installRequest = nil
            } catch {
                installError = error.localizedDescription
            }
            cancelling = false
        }
    }
}

struct PluginConfigurationView: View {
    @ObservedObject var model: AppModel
    let namespace: JSONValue
    let writable: Bool
    var onBack: () -> Void
    @State private var values: JSONValue
    @State private var error: String?
    @State private var busy = false

    init(model: AppModel, namespace: JSONValue, writable: Bool, onBack: @escaping () -> Void) {
        self.model = model
        self.namespace = namespace
        self.writable = writable
        self.onBack = onBack
        _values = State(initialValue: namespace["user"].isNull ? namespace["value"] : namespace["user"])
    }

    var body: some View {
        VStack(spacing: 0) {
            header(namespace["ns"].str() ?? L.t("插件配置", "Plugin settings"), back: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let error { settingsMessage(error, error: true) }
                    ForEach(Array(pluginSchemaFields(namespace["schema"]).enumerated()), id: \.offset) { _, field in
                        schemaField(field)
                    }
                    Button(L.save()) { save() }
                        .disabled(!writable || busy)
                        .padding(.horizontal, 22)
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private func schemaField(_ field: PluginSchemaField) -> some View {
        let current = values.at(field.path)
        VStack(alignment: .leading, spacing: 6) {
            Text(field.path.joined(separator: ".")).foregroundStyle(T.ink)
            switch field.type {
            case "boolean":
                Toggle("", isOn: Binding(
                    get: { current.bool() == true },
                    set: { set(field.path, .bool($0)) }
                )).labelsHidden().disabled(!writable)
            case "number":
                TextField("", text: Binding(
                    get: { current.double().map { String($0) } ?? current.str() ?? "" },
                    set: { set(field.path, Double($0).map { .number($0) } ?? .string($0)) }
                )).keyboardType(.decimalPad).disabled(!writable)
            case "enum":
                Picker("", selection: Binding(
                    get: { current.str() ?? field.choices.first?.str() ?? "" },
                    set: { set(field.path, .string($0)) }
                )) {
                    ForEach(field.choices.compactMap { $0.str() }, id: \.self) { Text($0).tag($0) }
                }.disabled(!writable)
            default:
                if pluginSettingsReplacesSecret(path: field.path, secrets: secrets) {
                    SecureField("", text: Binding(get: { "" }, set: { set(field.path, .string($0)) }))
                        .disabled(!writable)
                } else {
                    TextField("", text: Binding(
                        get: { current.str() ?? "" },
                        set: { set(field.path, .string($0)) }
                    )).disabled(!writable)
                }
            }
        }
        .padding(.horizontal, 22)
    }

    private var secrets: [[String]] {
        (namespace["secrets"].arr() ?? []).compactMap { $0.arr()?.compactMap { $0.str() } }
    }

    private func set(_ path: [String], _ value: JSONValue) {
        values = setPath(values, path, value)
    }

    private func save() {
        guard let client = model.clientOrNull(), let revision = namespace["revision"].int(), let ns = namespace["ns"].str() else { return }
        busy = true
        Task {
            do {
                let fields = pluginSchemaFields(namespace["schema"])
                let ops = fields.compactMap { field -> JSONValue? in
                    let next = values.at(field.path)
                    let previous = namespace["user"].at(field.path)
                    if next == previous { return nil }
                    if pluginSettingsReplacesSecret(path: field.path, secrets: secrets) && next.str()?.isEmpty != false { return nil }
                    return jsonObjectKeeping(["op": .string("set"), "path": .array(field.path.map { .string($0) }), "value": next])
                }
                let result = try await client.pluginsSettingsMutate(ns: ns, ops: .array(ops), expectedRevision: revision)
                try requireSettingsSuccess(result)
                onBack()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}


private func setPath(_ root: JSONValue, _ path: [String], _ value: JSONValue) -> JSONValue {
    if path.isEmpty { return value }
    var object = root.obj() ?? [:]
    object[path[0]] = setPath(root[path[0]], Array(path.dropFirst()), value)
    return .object(object)
}

private struct PluginAddMenu: View {
    let enabled: Bool
    let creatorEnabled: Bool
    let creatorDescription: String
    @Binding var expanded: Bool
    var onOpen: () -> Void
    var onInstall: () -> Void
    var onCreatePlugin: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button {
                expanded = false
                onInstall()
            } label: {
                HStack(spacing: 6) {
                    OfficialGlyph(kind: .plusOutline, size: 13, color: T.onPrimary)
                    Text(L.addPlugin()).font(.system(size: 13))
                }
                .foregroundStyle(T.onPrimary)
                .padding(.horizontal, 12).frame(height: 32)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("pluginAddButton")
            Rectangle().fill(T.onPrimary.opacity(0.3)).frame(width: 0.5, height: 32)
            Button {
                onOpen()
                expanded.toggle()
            } label: {
                OfficialGlyph(kind: .chevronDown, size: 12, color: T.onPrimary)
                    .frame(width: 32, height: 32).contentShape(Rectangle())
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(pluginAddChooseMethod(english: L.en))
            .accessibilityIdentifier(pluginAddChevronSymbol())
        }
        .buttonStyle(.plain)
        .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 12))
        .opacity(enabled ? 1 : 0.4).disabled(!enabled)
        .anchorPreference(key: PluginHeaderAnchors.self, value: .bounds) {
            ["add": PluginHeaderPresentation(anchor: $0, content: expanded ? AnyView(menu) : nil)]
        }
        .onChange(of: enabled) { if !$0 { expanded = false } }
    }

    private var menu: some View {
        VStack(spacing: 0) {
            addRow(icon: .downloadOutline, title: pluginAddInstallExisting(english: L.en),
                   detail: pluginAddInstallExistingDescription(english: L.en), enabled: enabled) {
                expanded = false
                onInstall()
            }
            addRow(icon: .cordisPlugin, title: pluginAddCreatePlugin(english: L.en),
                   detail: creatorDescription, enabled: enabled && creatorEnabled) {
                expanded = false
                onCreatePlugin()
            }
        }
        .padding(4).frame(idealWidth: 320, maxWidth: 320)
        .background(T.surface2, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.borderL1, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.16), radius: 16, y: 4)
        .accessibilityElement(children: .contain).accessibilityIdentifier("pluginAddMenu")
    }

    private func addRow(icon: OfficialGlyph.Kind, title: String, detail: String, enabled: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                OfficialGlyph(kind: icon, size: 14, color: T.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13)).foregroundStyle(T.ink)
                    Text(detail).font(.system(size: 12)).foregroundStyle(T.text2).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12).frame(height: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.5)
    }
}

private struct PluginHeaderPresentation {
    let anchor: Anchor<CGRect>
    let content: AnyView?
}

private struct PluginHeaderAnchors: PreferenceKey {
    static var defaultValue: [String: PluginHeaderPresentation] = [:]
    static func reduce(value: inout [String: PluginHeaderPresentation], nextValue: () -> [String: PluginHeaderPresentation]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct PluginUninstallDialog: View {
    let title: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            T.scrim.ignoresSafeArea().onTapGesture(perform: onCancel)
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(L.t("卸载「\(title)」？", "Uninstall \"\(title)\"?"))
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(T.ink)
                    Spacer(minLength: 8)
                    Button(action: onCancel) {
                        OfficialGlyph(kind: .closeOutline, size: 14, color: T.text2).frame(width: 28, height: 28)
                    }.accessibilityLabel(L.close())
                }
                Text(L.t("卸载后它提供的功能会消失。", "What it provides goes away once it is uninstalled."))
                    .font(.system(size: 14)).foregroundStyle(T.ink)
                HStack(spacing: 8) {
                    Spacer()
                    Button(action: onCancel) {
                        OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink)
                            .frame(width: 28, height: 36).contentShape(Rectangle())
                    }
                    .accessibilityLabel(L.t("返回", "Back"))
                    .accessibilityIdentifier("pluginUninstallBack")
                    Button(L.t("卸载", "Uninstall"), action: onConfirm)
                        .foregroundStyle(T.onPrimary).padding(.horizontal, 16).frame(height: 36)
                        .background(T.err, in: RoundedRectangle(cornerRadius: 12))
                }
                .font(.system(size: 14))
            }
            .padding(24).frame(maxWidth: 380)
            .background(T.surface2, in: RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.16), radius: 24, y: 8)
            .padding(24)
            .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("pluginUninstallDialog")
        }
        .buttonStyle(.plain)
    }
}
