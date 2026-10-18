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
    @State private var config: JSONValue?
    @State private var installOpen = false
    @State private var installSpec = ""
    @State private var catalogEnabled = false
    @State private var registry = ""
    @State private var registries: [String] = []
    @State private var inspection: JSONValue?
    @State private var installResult: JSONValue?
    @State private var installError: String?
    @State private var installRequest: String?
    @State private var installing = false
    @State private var checking = false
    @State private var cancelling = false
    @State private var uninstall: JSONValue?
    @State private var showPluginInfo = false

    var body: some View {
        if let config {
            PluginConfigurationView(model: model, namespace: config, writable: model.isOnline && writable && model.ops.contains("plugins.settingsMutate"), onBack: { self.config = nil })
        } else {
            list
        }
    }

    private var locked: Bool { busy || loading || installing || checking || installRequest != nil }

    private var list: some View {
        VStack(spacing: 0) {
            pluginsHeader(selected.map { pluginTitle($0, english: L.en) } ?? L.pluginsNav())
            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let error { settingsMessage(error, error: true) }
                        if let outcome { Text(pluginChangeText(outcome, en: L.en)).foregroundStyle(T.text2).padding(.horizontal, 22) }
                        if loading || busy { ProgressView().frame(maxWidth: .infinity) }
                        if let selected {
                            if let configError { settingsMessage(configError, error: true) }
                            bundleDetail(selected)
                        } else {
                            Text(L.pluginsHint())
                                .font(.footnote)
                                .foregroundStyle(T.text3)
                                .padding(.horizontal, 22)
                            market
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(T.bg)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8).onChanged { _ in
                        if showPluginInfo { showPluginInfo = false }
                    }
                )
                if showPluginInfo {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { showPluginInfo = false }
                    pluginInfoTooltip
                        .padding(.top, CGFloat(pluginInfoTooltipGapPoints))
                        .padding(.horizontal, CGFloat(pluginInfoTooltipScreenInsetPoints))
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: showPluginInfo)
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: $installOpen) { installSheet }
        .confirmationDialog(L.t("卸载此插件？", "Uninstall this plugin?"), isPresented: Binding(get: { uninstall != nil }, set: { if !$0 { uninstall = nil } })) {
            Button(L.delete(), role: .destructive) {
                if let name = uninstall?["name"].str() {
                    mutate { try await $0.pluginsUninstall(bundle: name) }
                }
                uninstall = nil
            }
            Button(L.cancel(), role: .cancel) { uninstall = nil }
        }
        .task(id: "\(model.activeId ?? "")-\(model.pluginCatalogRevision)") {
            if model.isOnline { await refresh() }
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

    private func pluginsHeader(_ title: String) -> some View {
        HStack(spacing: 10) {
            Button(action: back) { Image(systemName: "chevron.left").foregroundStyle(T.ink) }
            Text(title).font(.headline).foregroundStyle(T.ink).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            if selected == nil {
                Button { showPluginInfo.toggle() } label: {
                    OfficialGlyph(
                        kind: .infoOutline,
                        size: CGFloat(pluginInfoIconSizePoints),
                        color: T.ink
                    )
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pluginInfoLabel(english: L.en))
                .accessibilityIdentifier("pluginInfoButton")
            }
            Button(action: reload) {
                OfficialGlyph(kind: .refreshOutline, size: 16, color: T.ink)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.refresh())
            .disabled(!model.isOnline || locked)
            if selected == nil && ((managementAvailable && model.ops.contains("plugins.install")) || installRequest != nil) {
                PluginAddMenu(
                    enabled: installRequest != nil || (model.isOnline && !locked),
                    creatorEnabled: creatorState == "ready" && creatorPresent && model.ops.contains("sessions.create"),
                    creatorDescription: creatorDescription,
                    onOpen: loadCreator,
                    onInstall: { openInstall() },
                    onCreatePlugin: onCreatePlugin
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(T.surface)
    }

    /// Desktop `Tooltip`: fade-in bubble under `(i)`, never a system popover.
    /// Anchored below the header so it cannot cover Add plugin / refresh.
    private var pluginInfoTooltip: some View {
        Text(pluginInfoDescription(english: L.en))
            .font(.system(size: CGFloat(pluginInfoTooltipFontSizePoints)))
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

    private func titleLine(_ title: String, experimental: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(T.ink)
                if experimental { experimentalBadge }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(T.ink)
                if experimental { experimentalBadge }
            }
        }
    }

    private var experimentalBadge: some View {
        Text(L.experimentalBadge())
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(T.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(T.tint, in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var market: some View {
        let groups = pluginMarketGroups(bundles)
        if !loading && error == nil && bundles.isEmpty {
            Text(pluginsEmptyLabel(english: L.en))
                .font(.footnote)
                .foregroundStyle(T.text3)
                .padding(.horizontal, 22)
        }
        if !groups.official.isEmpty {
            Text(L.officialPlugins(groups.official.count))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(T.text2)
                .padding(.horizontal, 22)
                .padding(.top, 8)
            ForEach(Array(groups.official.enumerated()), id: \.offset) { _, bundle in
                marketRow(bundle)
            }
        }
        if !groups.installed.isEmpty {
            Text(L.installedPlugins())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(T.text2)
                .padding(.horizontal, 22)
                .padding(.top, 8)
            ForEach(Array(groups.installed.enumerated()), id: \.offset) { _, bundle in
                marketRow(bundle)
            }
        }
    }

    private func marketRow(_ bundle: JSONValue) -> some View {
        let name = bundle["name"].str() ?? ""
        let enabled = bundle["enabled"].bool() == true
        let canSwitch = model.isOnline && !locked && bundle["readOnlyReason"].str() == nil
            && model.ops.contains("plugins.setEnabled")
            && (bundle["availability"].str() != "missing" || bundle["installTarget"]["spec"].str() != nil)
        let description = pluginDescription(bundle, english: L.en)
        let state = bundleState(bundle)
        return HStack(alignment: .center, spacing: 12) {
            Button { detail = name } label: {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(T.border, lineWidth: 0.5)
                            .frame(width: 46, height: 46)
                        PluginMetadataArtwork(icon: bundle["meta"]["icon"].str())
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        titleLine(pluginTitle(bundle, english: L.en), experimental: pluginExperimental(bundle))
                        if !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(T.text3)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                        if !state.isEmpty {
                            Text(state).font(.caption).foregroundStyle(T.err)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Toggle("", isOn: Binding(
                get: { enabled },
                set: { toggleBundle(bundle, enabled: $0) }
            ))
            .labelsHidden()
            .disabled(!canSwitch)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func bundleDetail(_ bundle: JSONValue) -> some View {
        let rows = bundle["rows"].arr() ?? []
        let counts = pluginParts(rows: rows, plugins: plugins)
        Text(pluginTitle(bundle, english: L.en)).font(.headline).padding(.horizontal, 22)
        Text("\(counts.total) · \(counts.running)").font(.caption).foregroundStyle(T.text3).padding(.horizontal, 22)
        let description = pluginDescription(bundle, english: L.en)
        if !description.isEmpty {
            Text(description).foregroundStyle(T.text2).padding(.horizontal, 22)
        }
        Toggle(L.t("启用", "Enable"), isOn: Binding(
            get: { bundle["enabled"].bool() == true },
            set: { toggleBundle(bundle, enabled: $0) }
        ))
        .disabled(locked || !model.isOnline || !managementAvailable || !model.ops.contains("plugins.setEnabled") || bundle["readOnlyReason"].str() != nil)
        .padding(.horizontal, 22)
        if model.ops.contains("plugins.uninstall"), bundle["official"].bool() != true {
            Button(L.t("卸载", "Uninstall"), role: .destructive) { uninstall = bundle }
                .padding(.horizontal, 22)
        }
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            let liveRow = pluginLiveRow(row, plugins: plugins)
            let ns = namespaces.first { $0["ns"].str() == row["rowId"].str() }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PluginMetadataArtwork(icon: row["meta"]["icon"].str(), size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pluginTitle(row, english: L.en)).foregroundStyle(T.ink)
                        Text(phaseText(liveRow)).font(.caption).foregroundStyle(T.text3)
                    }
                    Spacer()
                }
                if ns != nil {
                    Button(L.configureComponent()) { config = ns }
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private var installSheet: some View {
        NavigationStack {
            Form {
                TextField(L.t("插件 spec", "Plugin spec"), text: $installSpec)
                    .textInputAutocapitalization(.never)
                if !registries.isEmpty {
                    Picker(L.t("来源库", "Registry"), selection: $registry) {
                        ForEach(registries, id: \.self) { Text($0).tag($0) }
                    }
                }
                if let inspection {
                    Text(inspection["status"].str() ?? "").foregroundStyle(T.text2)
                    if let problem = inspection["problem"].str() { Text(problem).foregroundStyle(T.err) }
                }
                if let installError { Text(installError).foregroundStyle(T.err) }
                if let installResult { Text(pluginChangeText(installResult, en: L.en)) }
                if installing { ProgressView() }
                Button(L.t("检视", "Inspect")) { inspect() }
                    .disabled(installSpec.trimmingCharacters(in: .whitespaces).isEmpty || checking || !model.ops.contains("plugins.inspect"))
                Button(L.t("安装", "Install")) { runInstall() }
                    .disabled(installing || installRequest != nil || !model.ops.contains("plugins.install"))
                if let installRequest, model.ops.contains("plugins.cancelInstall") {
                    Button(L.cancel()) { cancelInstall(installRequest) }.disabled(cancelling)
                }
            }
            .navigationTitle(L.addPlugin())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.close()) { installOpen = false } } }
        }
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
        if !spec.isEmpty {
            installSpec = spec
            inspection = nil
            installResult = nil
            installError = nil
        }
        catalogEnabled = enable
        installOpen = true
        guard model.ops.contains("plugins.registries"), model.isOnline, let client = model.clientOrNull() else { return }
        Task {
            do {
                let result = try await client.pluginsRegistries()
                var list = [result["registry"].str()].compactMap { $0 }
                list += (result["fallbackRegistries"].arr() ?? []).compactMap { $0.str() }
                if let resolved = result["resolved"].str() { list.append(resolved) }
                var seen = Set<String>()
                registries = list.filter { seen.insert($0).inserted }
                if registry.isEmpty { registry = result["registry"].str() ?? "" }
            } catch {
                installError = error.localizedDescription
            }
        }
    }

    private func inspect() {
        guard let client = model.clientOrNull() else { return }
        checking = true
        Task {
            do {
                inspection = try await client.pluginsInspect(spec: installSpec.trimmingCharacters(in: .whitespaces), registry: registry.isEmpty ? nil : registry)
                installError = nil
            } catch {
                installError = error.localizedDescription
            }
            checking = false
        }
    }

    private func runInstall() {
        guard !locked, model.isOnline, let client = model.clientOrNull() else { return }
        let request = UUID().uuidString
        installRequest = request
        installing = true
        installError = nil
        installResult = nil
        Task {
            do {
                var options: [String: JSONValue] = [
                    "requestId": .string(request),
                    "enabled": .bool(catalogEnabled),
                ]
                if !registry.trimmingCharacters(in: .whitespaces).isEmpty {
                    options["registry"] = .string(registry.trimmingCharacters(in: .whitespaces))
                }
                installResult = try await client.pluginsInstall(spec: installSpec.trimmingCharacters(in: .whitespaces), options: .object(options))
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

private func bundleState(_ bundle: JSONValue) -> String {
    if !bundle["error"].isNull { return L.t("异常", "Problem") }
    if bundle["availability"].str() == "missing" {
        return bundle["installed"].bool() == true ? L.t("包不可用", "Package unavailable") : L.t("未安装", "Not installed")
    }
    return ""
}

private func phaseText(_ row: JSONValue?) -> String {
    if row?["enabled"].bool() != true { return L.t("已停用", "Disabled") }
    switch row?["fiberPhase"].str() {
    case "active": return L.t("运行中", "Running")
    case "pending": return L.t("等待依赖", "Waiting for dependencies")
    case "loading": return L.t("加载中", "Loading")
    case "unloading": return L.t("卸载中", "Unloading")
    case "failed": return L.t("异常", "Failed")
    default: return L.t("未运行", "Not running")
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
    var onOpen: () -> Void
    var onInstall: () -> Void
    var onCreatePlugin: () -> Void
    @State private var expanded = false

    var body: some View {
        HStack(spacing: 0) {
            Button {
                expanded = false
                onInstall()
            } label: {
                Text(L.addPlugin()).font(.system(size: 13)).foregroundStyle(T.onPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!enabled)
            Button {
                onOpen()
                if pluginAddMenuUsesMenuSurface { expanded.toggle() }
            } label: {
                Image(systemName: "chevron.down").font(.system(size: 12)).foregroundStyle(T.ink).frame(width: 32, height: 32)
            }
            .disabled(!enabled)
            .accessibilityLabel(pluginAddChooseMethod(english: L.en))
            .popover(isPresented: $expanded, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    addRow(
                        title: pluginAddInstallExisting(english: L.en),
                        detail: pluginAddInstallExistingDescription(english: L.en),
                        enabled: enabled
                    ) {
                        expanded = false
                        onInstall()
                    }
                    addRow(
                        title: pluginAddCreatePlugin(english: L.en),
                        detail: creatorDescription,
                        enabled: enabled && creatorEnabled
                    ) {
                        expanded = false
                        onCreatePlugin()
                    }
                }
                .padding(CGFloat(permissionMenuPaddingPoints))
                .frame(minWidth: 220, maxWidth: 320)
                .modifier(PopoverCompactAdaptation())
            }
        }
    }

    private func addRow(
        title: String,
        detail: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(enabled ? T.ink : T.text3)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(T.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
