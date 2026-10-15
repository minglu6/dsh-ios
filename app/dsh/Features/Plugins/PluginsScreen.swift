import SwiftUI
import DSHProtocol

struct PluginsScreen: View {
    @ObservedObject var model: AppModel
    @State private var hostUi = false
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
        if hostUi {
            HostUiView(model: model, title: L.pluginInterfaces(), onBack: { hostUi = false })
        } else if let config {
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
                    HStack {
                        Button(L.refresh()) { reload() }.disabled(!model.isOnline || locked)
                        Spacer()
                        if selected == nil && !moreOptional && managementAvailable && model.ops.contains("plugins.install") || installRequest != nil {
                            Button(installRequest != nil ? L.t("安装任务", "Installation") : L.addPlugin()) { openInstall() }
                                .disabled(!(installRequest != nil || (model.isOnline && !locked)))
                        }
                    }
                    .padding(.horizontal, 18)
                    if let error { settingsMessage(error, error: true) }
                    if let outcome { Text(pluginChangeText(outcome, en: L.en)).foregroundStyle(T.text2).padding(.horizontal, 22) }
                    if loading || busy { ProgressView().frame(maxWidth: .infinity) }
                    if model.ops.contains("ui.open") {
                        card {
                            nav(L.pluginInterfaces(), "puzzlepiece.extension", value: L.t("与桌面共用", "Shared with desktop"), divider: false) {
                                hostUi = true
                            }
                        }
                    } else {
                        settingsMessage(L.t("更新桌面端手机连接插件后，可在此加载插件原有的 Web 界面。", "Update the Host phone-connection plugin to load installed plugin Web interfaces here."))
                    }
                    if let selected {
                        bundleDetail(selected)
                    } else if moreOptional {
                        bundleGroup(official: true, expanded: true)
                    } else {
                        settingsMessage(L.t("安装、启用和配置插件", "Install, enable and configure plugins"))
                        if !namespaces.isEmpty {
                            Text(L.t("插件配置", "Plugin settings")).font(.caption).foregroundStyle(T.text3).padding(.horizontal, 22)
                        }
                        if let configError { settingsMessage(configError, error: true) }
                        ForEach(Array(namespaces.enumerated()), id: \.offset) { _, ns in
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

    @ViewBuilder
    private func bundleGroup(official: Bool, expanded: Bool) -> some View {
        let visible = bundles.filter { $0["installed"].bool() == true || $0["official"].bool() == true || !$0["error"].isNull }
        let all = visible.filter { ($0["official"].bool() == true) == official }
        if !all.isEmpty {
            HStack {
                Text(official ? L.t("实验性插件", "Experimental plugins") : L.t("已安装插件", "Installed plugins"))
                    .font(.caption).foregroundStyle(T.text3)
                Spacer()
                if official && !expanded {
                    Button(L.t("更多", "More")) { moreOptional = true }
                }
            }
            .padding(.horizontal, 22)
            let group = all.filter { !official || pluginOptionalVisible(name: $0["name"].str(), expanded: expanded) }
                .sorted { a, b in
                    official ? pluginOptionalRank(a["name"].str()) < pluginOptionalRank(b["name"].str()) : false
                }
            ForEach(Array(group.enumerated()), id: \.offset) { _, bundle in
                Button { detail = bundle["name"].str() } label: {
                    HStack {
                        PluginMetadataArtwork(icon: bundle["meta"]["icon"].str())
                        VStack(alignment: .leading) {
                            Text(pluginTitle(bundle)).foregroundStyle(T.ink)
                            Text(bundleState(bundle)).font(.caption).foregroundStyle(T.text3)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func bundleDetail(_ bundle: JSONValue) -> some View {
        let name = bundle["name"].str() ?? ""
        let rows = bundle["rows"].arr() ?? []
        let counts = pluginParts(rows: rows, plugins: plugins)
        Text(pluginTitle(bundle)).font(.headline).padding(.horizontal, 22)
        Text("\(counts.total) · \(counts.running)").font(.caption).foregroundStyle(T.text3).padding(.horizontal, 22)
        if let description = pluginLocalized(bundle["meta"]["description"], english: L.en) {
            Text(description).foregroundStyle(T.text2).padding(.horizontal, 22)
        }
        let live = pluginLiveRow(bundle, plugins: plugins) ?? bundle
        Toggle(L.t("启用", "Enable"), isOn: Binding(
            get: { live["enabled"].bool() == true },
            set: { enabled in
                mutate { try await $0.pluginsSetEnabled(enabled: enabled, bundle: name) }
            }
        ))
        .disabled(locked || !model.isOnline || !managementAvailable)
        .padding(.horizontal, 22)
        if model.ops.contains("plugins.uninstall"), bundle["official"].bool() != true {
            Button(L.t("卸载", "Uninstall"), role: .destructive) { uninstall = bundle }
                .padding(.horizontal, 22)
        }
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            let liveRow = pluginLiveRow(row, plugins: plugins)
            HStack {
                Text(row["moduleName"].str() ?? row["rowId"].str() ?? "").foregroundStyle(T.ink)
                Spacer()
                Text(phaseText(liveRow)).font(.caption).foregroundStyle(T.text3)
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

    private func openInstall() {
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
                    "enabled": .bool(false),
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

private func pluginTitle(_ value: JSONValue) -> String {
    pluginLocalized(value["meta"]["title"], english: L.en) ?? value["name"].str() ?? value["rowId"].str() ?? value["moduleName"].str() ?? ""
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
