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
    @State private var loaded = false
    @State private var busy = false
    @State private var error: String?
    @State private var moreOptional = false
    @State private var configError: String?
    @State private var outcome: JSONValue?
    @State private var detail: String?
    @State private var partsQuery = ""
    @State private var catalogSelection: Bool?
    @State private var config: JSONValue?
    @State private var installOpen = false
    @State private var installSpec = ""
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
            header(selected.map { pluginTitle($0) } ?? (moreOptional ? L.t("实验性插件", "Experimental plugins") : L.pluginsNav())) {
                back()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    settingsDisconnectedBanner(model)
                    HStack {
                        Button(L.refresh()) { reload() }.disabled(!model.isOnline || locked)
                        Spacer()
                        if selected == nil && !moreOptional && (managementAvailable && model.ops.contains("plugins.install") || installRequest != nil) {
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
                    .padding(.horizontal, 18)
                    if let error { settingsMessage(error, error: true) }
                    if let outcome { PluginOutcome(outcome) }
                    if loading || busy { ProgressView().frame(maxWidth: .infinity) }
                    if let selected {
                        bundleDetail(selected)
                    } else if moreOptional {
                        bundleGroup(official: true, expanded: true)
                    } else {
                        PluginPageIntro()
                        let configurations = namespaces.filter { officialConfigurations.contains($0["ns"].str() ?? "") }
                        if !configurations.isEmpty {
                            Text(L.t("内置插件配置", "Built-in plugin settings")).font(.caption).foregroundStyle(T.text3).padding(.horizontal, 22)
                        }
                        if let configError { settingsMessage(configError, error: true) }
                        ForEach(Array(configurations.sorted { officialConfigurations.firstIndex(of: $0["ns"].str() ?? "") ?? .max < officialConfigurations.firstIndex(of: $1["ns"].str() ?? "") ?? .max }.enumerated()), id: \.offset) { _, ns in
                            let nsId = ns["ns"].str() ?? ""
                            Button { config = ns } label: {
                                HStack(spacing: 12) {
                                    PluginArtwork(kind: configurationArtwork(nsId))
                                    VStack(alignment: .leading) {
                                        Text(configurationTitle(nsId, plugins: plugins)).foregroundStyle(T.ink)
                                        Text(configurationDescription(nsId)).font(.caption).foregroundStyle(T.text3)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 18)
                            }
                        }
                        bundleGroup(official: true, expanded: false)
                        bundleGroup(official: false, expanded: false)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: $installOpen) { installSheet }
        .confirmationDialog(L.t("卸载插件？", "Uninstall plugin?"), isPresented: Binding(get: { uninstall != nil }, set: { if !$0 { uninstall = nil } }), titleVisibility: .visible) {
            Button(L.t("确认卸载", "Uninstall"), role: .destructive) {
                if let name = uninstall?["name"].str() {
                    mutate { try await $0.pluginsUninstall(bundle: name) }
                }
                uninstall = nil
            }
            Button(L.cancel(), role: .cancel) { uninstall = nil }
        } message: {
            if let uninstall {
                Text(pluginTitle(uninstall) + "\n" + L.t("将从当前主机 profile 移除，插件功能将不可用。", "Removes this package from the host profile. Its functionality will no longer be available."))
            }
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
        .onChange(of: detail) { _ in partsQuery = "" }
    }

    private var selected: JSONValue? {
        bundles.first { $0["name"].str() == detail }
    }

    private var creatorPresent: Bool {
        model.presetRoster.contains { $0["id"].str() == "cordis" }
    }

    private var creatorDescription: String {
        switch creatorState {
        case "idle", "loading": return L.t("正在确认创造模式是否可用", "Checking whether Creator mode is available")
        case "ready":
            return creatorPresent
                ? L.t("进入创造模式，制作属于你的 DSH 插件", "Enter Creator mode and make your own DSH plugin")
                : L.t("当前配置未提供创造模式", "Creator mode is not included in this configuration")
        default:
            return L.t("暂时不可用，请重新打开菜单重试", "Temporarily unavailable. Reopen this menu to retry")
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

    @ViewBuilder
    private func bundleGroup(official: Bool, expanded: Bool) -> some View {
        let visible = bundles.filter { $0["installed"].bool() == true || $0["official"].bool() == true || !$0["error"].isNull }
        let all = visible.filter { ($0["official"].bool() == true) == official }
        if !all.isEmpty {
            HStack {
                Text(official ? L.t("实验性插件", "Experimental plugins") : L.t("已安装插件", "Installed plugins"))
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink)
                Spacer()
                if official && !expanded {
                    Button(L.t("更多", "More")) { moreOptional = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            let group = all.filter { !official || pluginOptionalVisible(name: $0["name"].str(), expanded: expanded) }
                .sorted { a, b in
                    official ? pluginOptionalRank(a["name"].str()) < pluginOptionalRank(b["name"].str()) : false
                }
            if group.isEmpty && loaded && !loading && error == nil {
                settingsMessage(L.t("没有匹配的插件", "No matching plugins"))
            }
            ForEach(Array(group.enumerated()), id: \.offset) { _, bundle in
                pluginCard(bundle)
            }
        }
    }

    @ViewBuilder
    private func pluginCard(_ bundle: JSONValue) -> some View {
        let name = bundle["name"].str() ?? ""
        let reason = bundle["readOnlyReason"].str()
        let missing = bundle["availability"].str() == "missing"
        let switchAvailable = model.isOnline && !locked && reason == nil && model.ops.contains("plugins.setEnabled")
            && (!missing || bundle["installTarget"]["spec"].str() != nil)
        let summary = (bundle["rows"].arr()?.isEmpty == false) ? partsSummary(bundle["rows"].arr() ?? [], plugins: plugins) : nil
        let status = [bundleState(bundle).nilIfBlank, summary].compactMap { $0 }.joined(separator: " · ")
        HStack(alignment: .center, spacing: 12) {
            Button { detail = name } label: {
                HStack(alignment: .center, spacing: 12) {
                    PluginMetadataArtwork(icon: bundle["meta"]["icon"].str())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(pluginTitle(bundle)).font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink)
                        let description = pluginDescription(bundle)
                        if !description.isEmpty {
                            Text(description).font(.system(size: 12)).foregroundStyle(T.text3)
                        }
                        if !status.isEmpty {
                            Text(status).font(.system(size: 11)).foregroundStyle(T.text3)
                        }
                        if let version = bundle["version"].str() {
                            Text("v\(version)").font(.system(size: 11)).foregroundStyle(T.text3)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            Toggle("", isOn: Binding(
                get: { bundle["enabled"].bool() == true },
                set: { enabled in
                    if enabled && missing {
                        if let spec = bundle["installTarget"]["spec"].str() { openInstall(spec, true) }
                    } else {
                        mutate { try await $0.pluginsSetEnabled(enabled: enabled, bundle: name) }
                    }
                }
            ))
            .labelsHidden()
            .disabled(!switchAvailable)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func bundleDetail(_ bundle: JSONValue) -> some View {
        let name = bundle["name"].str() ?? ""
        let reason = bundle["readOnlyReason"].str()
        let rows = bundle["rows"].arr() ?? []
        VStack(alignment: .leading, spacing: 10) {
            Text(pluginDescription(bundle)).foregroundStyle(T.text3)
            Text(name).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
            HStack {
                Text(L.t("启用插件", "Enable plugin"))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { bundle["enabled"].bool() == true },
                    set: { enabled in
                        mutate { try await $0.pluginsSetEnabled(enabled: enabled, bundle: name) }
                    }
                ))
                .labelsHidden()
                .disabled(!(model.isOnline && !locked && reason == nil && bundle["availability"].str() != "missing" && model.ops.contains("plugins.setEnabled")))
            }
            if let reason {
                Text(pluginReadOnlyText(reason)).foregroundStyle(T.text3)
            }
            if !bundle["error"].isNull {
                Text(pluginPretty(bundle["error"])).font(.system(size: 12)).foregroundStyle(T.err).textSelection(.enabled)
            }
            if let metaError = bundle["meta"]["error"].str() {
                Text(L.t("包元信息错误：", "Package metadata error: ") + metaError).font(.system(size: 12)).foregroundStyle(T.err)
            }
            Text(L.t("来源：", "Source: ") + (bundle["source"].str() ?? (bundle["availability"].str() == "installation" ? L.t("内置", "Built-in") : name)))
                .font(.system(size: 12))
            if let version = bundle["version"].str() {
                Text(L.t("当前版本：", "Version: ") + version).font(.system(size: 12))
            }
            let target = bundle["installTarget"]
            if target["spec"].str() != nil && (bundle["availability"].str() == "missing" || target["version"].str() != bundle["version"].str()) {
                Button(L.t("安装 / 更新至 ", "Install / update to ") + (target["version"].str() ?? "")) {
                    openInstall(target["spec"].str() ?? "", bundle["enabled"].bool() == true || bundle["availability"].str() == "missing")
                }
                .disabled(!(model.isOnline && !locked))
            }
            if bundle["removable"].bool() == true && bundle["optional"].bool() != true && reason == nil && bundle["availability"].str() != "installation" {
                Button(L.t("卸载", "Uninstall"), role: .destructive) { uninstall = bundle }
                    .disabled(!(model.isOnline && !locked && model.ops.contains("plugins.uninstall")))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
        .padding(.horizontal, 16)
        Text(L.t("包含的组件", "Components")).font(.system(size: 14, weight: .medium)).padding(.horizontal, 20).padding(.top, 8)
        if rows.isEmpty {
            settingsMessage(L.t("这个插件包不包含任何组件。", "This bundle contains no components."))
        }
        if !rows.isEmpty {
            settingsMessage(partsSummary(rows, plugins: plugins))
        }
        if rows.count > 10 {
            TextField(L.t("筛选组件", "Filter components"), text: $partsQuery)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 18)
        }
        let shown = rows.filter { row in
            let q = partsQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty { return true }
            return [pluginTitle(row), pluginDescription(row), row["rowId"].str() ?? "", row["moduleName"].str() ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(q) }
        }
        if !rows.isEmpty && shown.isEmpty {
            settingsMessage(L.t("没有匹配的组件", "No matching components"))
        }
        ForEach(Array(shown.enumerated()), id: \.offset) { _, row in
            componentCard(row)
        }
        if !model.ops.contains("ui.open") {
            settingsMessage(L.t("更新桌面端手机连接插件后，可在此加载插件原有的 Web 界面。", "Update the Host phone-connection plugin to load installed plugin Web interfaces here."))
        }
    }

    @ViewBuilder
    private func componentCard(_ row: JSONValue) -> some View {
        let live = pluginLiveRow(row, plugins: plugins)
        let ns = namespaces.first { $0["ns"].str() == row["rowId"].str() }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                PluginMetadataArtwork(icon: row["meta"]["icon"].str())
                VStack(alignment: .leading) {
                    Text(pluginTitle(row)).font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink)
                    Text(phaseText(live))
                        .font(.system(size: 12))
                        .foregroundStyle(live?["fiberPhase"].str() == "failed" ? T.err : T.text3)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { live?["enabled"].bool() == true },
                    set: { enabled in
                        mutate { try await $0.pluginsSetEnabled(enabled: enabled, id: row["entryId"].str()) }
                    }
                ))
                .labelsHidden()
                .disabled(!(model.isOnline && !locked && live != nil && live?["readOnlyReason"].str() == nil && model.ops.contains("plugins.setEnabled")))
            }
            if !pluginDescription(row).isEmpty {
                Text(pluginDescription(row)).font(.system(size: 13)).foregroundStyle(T.text3)
            }
            if let rowId = row["rowId"].str(), rowId != pluginTitle(row) {
                Text(rowId).font(.system(size: 11, design: .monospaced))
            }
            if let module = row["moduleName"].str(), module != pluginTitle(row), module != row["rowId"].str() {
                Text(module).font(.system(size: 11, design: .monospaced))
            }
            if let metaError = row["meta"]["error"].str() {
                Text(L.t("包元信息错误：", "Package metadata error: ") + metaError).font(.system(size: 12)).foregroundStyle(T.err)
            }
            if let reason = live?["readOnlyReason"].str() {
                Text(pluginReadOnlyText(reason)).font(.system(size: 12))
            }
            if ns != nil {
                Button(L.t("配置组件", "Configure component")) { config = ns }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private var catalogUpdate: Bool {
        catalogSelection != nil
            && inspection?["problem"].str() == "already-installed"
            && bundles.contains {
                $0["official"].bool() == true
                    && $0["installed"].bool() == true
                    && $0["availability"].str() != "installation"
                    && $0["installTarget"]["spec"].str() == installSpec.trimmingCharacters(in: .whitespaces)
            }
    }

    private var installSheet: some View {
        NavigationStack {
            Form {
                Text(L.t("输入 npm 包名、Git 仓库、tarball 地址或主机目录路径。路径属于主机，不是手机。", "Enter an npm package, Git repository, tarball URL or host directory path. Paths refer to the host, not this phone."))
                    .font(.system(size: 13))
                Text(L.t("只安装可信插件：插件在主机以你的权限运行，可访问你的数据。", "Only install trusted plugins: they execute with your host permissions and can access your data."))
                    .font(.system(size: 12))
                    .foregroundStyle(T.err)
                TextField(L.t("包名或地址", "Package or address"), text: $installSpec)
                    .textInputAutocapitalization(.never)
                    .disabled(locked)
                if !registries.isEmpty {
                    Picker(L.t("安装源", "Registry"), selection: $registry) {
                        Text(L.t("主机配置的默认安装源", "Host-configured default registry")).tag("")
                        ForEach(registries, id: \.self) { Text($0).tag($0) }
                    }
                    .disabled(locked)
                }
                if let inspection {
                    Text(inspection["status"].str() ?? "").foregroundStyle(T.text2)
                    if let problem = inspection["problem"].str() { Text(problem).foregroundStyle(T.err) }
                }
                if let installError { Text(installError).foregroundStyle(T.err) }
                if let installResult { PluginOutcome(installResult) }
                if installing { ProgressView() }
                Button(L.t("检视", "Inspect")) { inspect() }
                    .disabled(installSpec.trimmingCharacters(in: .whitespaces).isEmpty || checking || !model.ops.contains("plugins.inspect") || locked)
                Button(L.t("安装", "Install")) { runInstall() }
                    .disabled(!(model.isOnline && !locked && model.ops.contains("plugins.install") && (inspection?["status"].str() == "accepted" || catalogUpdate)))
                if let installRequest, model.ops.contains("plugins.cancelInstall") {
                    Button(L.cancel()) { cancelInstall(installRequest) }.disabled(cancelling)
                }
            }
            .navigationTitle(L.addPlugin())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(installRequest != nil || installing ? L.t("收起", "Hide") : L.close()) { installOpen = false }
                }
            }
        }
    }

    private func back() {
        if config != nil { config = nil }
        else if detail != nil { detail = nil }
        else if installRequest != nil || installing { installOpen = true }
        else if moreOptional { moreOptional = false }
        else { model.pop() }
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
            loaded = true
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

    private func openInstall(_ spec: String = "", _ selection: Bool? = nil) {
        if installRequest == nil && !installing && !spec.isEmpty {
            installSpec = spec
            inspection = nil
            installResult = nil
            installError = nil
            catalogSelection = selection
        }
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
        let spec = installSpec.trimmingCharacters(in: .whitespaces)
        guard !locked, model.isOnline, let client = model.clientOrNull() else { return }
        guard inspection?["status"].str() == "accepted" || catalogUpdate else { return }
        let request = UUID().uuidString
        installRequest = request
        installing = true
        installError = nil
        installResult = nil
        Task {
            do {
                var options: [String: JSONValue] = [
                    "requestId": .string(request),
                    "enabled": .bool(catalogSelection ?? false),
                ]
                if catalogSelection != nil && !spec.hasPrefix("link:") {
                    options["saveExact"] = .bool(true)
                }
                if !registry.trimmingCharacters(in: .whitespaces).isEmpty {
                    options["registry"] = .string(registry.trimmingCharacters(in: .whitespaces))
                }
                installResult = try await client.pluginsInstall(spec: spec, options: jsonObjectKeeping(options))
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

private func pluginTitle(_ value: JSONValue) -> String {
    pluginLocalized(value["meta"]["title"], english: L.en) ?? value["name"].str() ?? value["rowId"].str() ?? value["moduleName"].str() ?? ""
}

private func pluginDescription(_ value: JSONValue) -> String {
    pluginLocalized(value["meta"]["description"], english: L.en) ?? value["description"].str() ?? ""
}

private func pluginReadOnlyText(_ reason: String) -> String {
    switch reason {
    case "management-required": return L.t("管理界面依赖此组件，不能关闭或卸载。", "Required by plugin management; cannot disable or remove.")
    case "unaddressable": return L.t("此组件不能通过当前 profile 修改。", "This component cannot be changed through this profile.")
    default: return reason
    }
}

private func partsSummary(_ rows: [JSONValue], plugins: [JSONValue]) -> String {
    let counts = pluginParts(rows: rows, plugins: plugins)
    var parts = [L.en ? "\(counts.total) components" : "\(counts.total) 个组件"]
    if counts.running > 0 { parts.append(L.en ? "\(counts.running) running" : "\(counts.running) 个运行中") }
    if counts.off > 0 { parts.append(L.en ? "\(counts.off) disabled" : "\(counts.off) 个已停用") }
    if counts.failed > 0 { parts.append(L.en ? "\(counts.failed) failed" : "\(counts.failed) 个异常") }
    return parts.joined(separator: " · ")
}

private func pluginPretty(_ value: JSONValue) -> String {
    (try? value.encodeString()) ?? ""
}

private struct PluginOutcome: View {
    let result: JSONValue
    @State private var expanded = false

    init(_ result: JSONValue) { self.result = result }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            settingsMessage(pluginChangeText(result, en: L.en), error: result["application"].str() == "failed")
            if !result["error"].isNull {
                settingsMessage(pluginPretty(result["error"]), error: true)
            }
            let warnings = (result["warnings"].arr() ?? []).compactMap { $0.str() }
            if !warnings.isEmpty {
                settingsMessage(warnings.joined(separator: "\n"))
            }
            if !result["packageResult"].isNull || !result["pendingBuilds"].isNull {
                Button(expanded ? L.t("收起安装详情", "Hide installation details") : L.t("查看安装详情", "Show installation details")) {
                    expanded.toggle()
                }
                .padding(.horizontal, 22)
                if expanded {
                    Text(pluginPretty(result))
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.horizontal, 18)
                }
            }
        }
    }
}

private func configurationTitle(_ ns: String, plugins: [JSONValue]) -> String {
    let runtime = plugins.first { $0["patchId"].str() == ns }
    switch ns {
    case "shell", "bash-sandbox", "pwsh-sandbox": return L.t("终端", "Terminal")
    case "agent-loop": return L.t("Agent 循环", "Agent loop")
    case "subagent": return L.t("子智能体", "Subagents")
    case "web-search", "web-search-deepseek": return L.t("网页搜索", "Web search")
    default: return pluginLocalized(runtime?["meta"]["title"], english: L.en) ?? ns
    }
}

private func configurationDescription(_ ns: String) -> String {
    switch ns {
    case "subagent": return L.t("设置子智能体的递归层级、数量和模型。", "Set Subagent recursion depth, count, and models.")
    case "web-search-deepseek": return L.t("设置 DeepSeek 的搜索提供方。", "Set up the DeepSeek search provider.")
    case "agent-loop": return L.t("控制 Agent 派发工具调用的方式。", "Control how the Agent dispatches tool calls.")
    case "bash-sandbox", "pwsh-sandbox": return L.t("限制每条命令最多能跑多久、最多输出多少内容。", "Limit how long each command may run and how much it may output.")
    default: return L.t("插件高级配置", "Advanced plugin configuration")
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

private struct PluginPageIntro: View {
    @State private var tooltip = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(L.t("安装、启用和配置插件", "Install, enable, and configure plugins"))
                .font(.system(size: 13))
                .foregroundStyle(T.text3)
            Button { tooltip.toggle() } label: {
                Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(T.text3)
            }
            .accessibilityLabel(L.t("插件说明", "About plugins"))
            .popover(isPresented: $tooltip) {
                Text(L.t("在这里配置官方插件，安装和管理其他插件。内置插件列表及运行状态可在「设置 → 内置插件」中查看", "Configure official plugins and install or manage other plugins here. View the built-in plugin list and runtime status in Settings → Built-in plugins."))
                    .font(.system(size: 13))
                    .foregroundStyle(T.ink)
                    .frame(maxWidth: 300)
                    .padding(12)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
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
                expanded = true
                onOpen()
            } label: {
                Image(systemName: "chevron.down").font(.system(size: 12)).foregroundStyle(T.ink).frame(width: 32, height: 32)
            }
            .disabled(!enabled)
            .accessibilityLabel(L.t("选择添加插件方式", "Choose how to add a plugin"))
            .confirmationDialog(L.addPlugin(), isPresented: $expanded, titleVisibility: .hidden) {
                Button(L.t("安装第三方插件", "Install a third-party plugin")) { onInstall() }
                    .disabled(!enabled)
                Button(L.t("让 Agent 创建插件", "Let the agent create a plugin")) { onCreatePlugin() }
                    .disabled(!(enabled && creatorEnabled))
                Button(L.cancel(), role: .cancel) {}
            } message: {
                Text(L.t("支持 npm 包、Git 仓库和本地目录", "Supports npm packages, Git repositories, and local directories") + "\n" + creatorDescription)
            }
        }
    }
}
