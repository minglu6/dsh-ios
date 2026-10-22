import SwiftUI
import DSHProtocol

struct ModelsSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var rows: [JSONValue] = []
    @State private var namespaces: [JSONValue] = []
    @State private var protocols: [String] = []
    @State private var writable = false
    @State private var loading = true
    @State private var error: String?
    @State private var message: String?
    @State private var editor: JSONValue?
    @State private var adding = false
    @State private var busy = false
    @State private var setupConsidered = false

    var body: some View {
        VStack(spacing: 0) {
            header(L.modelsNav()) { if !busy { model.pop() } }
                .accessibilityIdentifier("modelsSettings")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    settingsMessage(modelsSettingsIntro(english: L.en))
                    if model.isOnline && !writable && !loading && error == nil {
                        settingsMessage(L.hostSettingsReadOnly())
                    }
                    if let error { settingsMessage(error, error: true) }
                    if let message { settingsMessage(message) }
                    if loading { ProgressView().frame(maxWidth: .infinity).padding() }
                    if error != nil {
                        Button(L.retry(), action: reload)
                            .disabled(!model.isOnline || !model.ops.contains("models.providers") || busy || loading)
                            .padding(.horizontal, 22)
                    }
                    ForEach(Array(configured.enumerated()), id: \.offset) { _, row in
                        providerCard(row)
                    }
                    if !adding {
                        Button {
                            adding = true
                            message = nil
                        } label: {
                            HStack {
                                OfficialGlyph(kind: .plusOutline, size: 16, color: canAdd ? T.ink : T.text3)
                                Text(L.t("添加模型提供商", "Add model provider"))
                            }
                            .foregroundStyle(canAdd ? T.ink : T.text3)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(style: StrokeStyle(lineWidth: 1, dash: [4])))
                        }
                        .disabled(!canAdd)
                        .accessibilityElement(children: .contain)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier(modelsAddProviderSymbol())
                        .padding(.horizontal, 18)
                        if !loading && !addOptions.offered {
                            settingsMessage(L.t("远程主机未提供可新增的模型提供商配置。", "The remote host has not exposed an add-provider configuration."))
                        } else if !loading && !addOptions.enabled(protocols: protocols) {
                            settingsMessage(L.t("当前没有可添加的目录提供商或自定义 API 协议。", "No catalog providers or custom API protocols are available to add."))
                        }
                    } else {
                        AddModelProviderView(
                            catalog: addOptions.catalog,
                            namespace: addOptions.customNamespace,
                            protocols: protocols,
                            taken: Array(providerTakenRoutes(rows: rows, namespace: addOptions.customNamespace)),
                            writable: writable,
                            model: model,
                            onBusy: { busy = $0 },
                            onClose: { changed in
                                adding = false
                                if changed {
                                    message = L.t("已保存；以提供商状态确认是否生效", "Saved; check provider status for activation")
                                    reload()
                                }
                            }
                        )
                        .padding(.horizontal, 18)
                    }
                    if let namespace = namespaces.first(where: { $0["ns"].str() == "llm-qoder" }) {
                        VStack(alignment: .leading, spacing: 10) {
                            QoderConnectionCard(
                                namespace: namespace,
                                online: model.isOnline,
                                writable: writable,
                                interactionEnabled: !busy && !loading && error == nil,
                                model: model,
                                onBusy: { busy = $0 },
                                onChanged: reload
                            )
                        }
                        .padding(14)
                        .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
                        .padding(.horizontal, 18)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        .task(id: "\(model.activeId ?? "")-\(model.modelSettingsRevision)-\(model.isOnline)") {
            await loadInitial()
        }
    }

    private var configured: [JSONValue] {
        rows.filter { $0["configured"].bool() == true }
    }

    private var addOptions: ProviderAddOptions {
        providerAddOptions(rows: rows, namespaces: namespaces)
    }

    private var canAdd: Bool {
        model.isOnline && !busy && !loading && writable && model.ops.contains("models.settingsMutate") && addOptions.enabled(protocols: protocols)
    }

    @ViewBuilder
    private func providerCard(_ row: JSONValue) -> some View {
        let route = row["provider"].str() ?? ""
        let expanded = editor?["provider"]["provider"].str() == route
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if expanded {
                        HStack(spacing: 8) {
                            Text(providerDisplayName(row, route: route, english: L.en)).foregroundStyle(T.ink)
                            Text(route).font(Font.system(size: 12)).foregroundStyle(T.text3).lineLimit(1)
                        }
                    } else {
                        HStack {
                            Text(providerDisplayName(row, route: route, english: L.en)).foregroundStyle(T.ink)
                            if row["declared"].bool() == true {
                                Text(L.t("自定义", "Custom")).font(Font.caption2).foregroundStyle(T.text2)
                                    .padding(.horizontal, 6).overlay(RoundedRectangle(cornerRadius: 4).stroke(T.border))
                            }
                            if route != "deepseek-account" {
                                let credential = row["apiKeyEnv"].str() != nil ? row["credential"] : row["derivedCredential"]
                                if credential["configured"].bool() == true {
                                    Circle().fill(T.ok).frame(width: 8, height: 8)
                                } else if row["apiKeyEnv"].str() != nil {
                                    Circle().fill(T.err).frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                    if let err = row["error"].str() { Text(err).font(Font.caption).foregroundStyle(T.err) }
                }
                Spacer()
                if !expanded {
                    Button(L.t("编辑", "Edit")) { open(row) }
                        .disabled(!model.isOnline || !model.ops.contains("models.providers") || !model.ops.contains("models.providerGet") || busy || loading)
                }
            }
            if expanded, let editor {
                ProviderSettingsEditorView(
                    initial: editor,
                    customNamespace: nil,
                    protocols: protocols,
                    taken: [],
                    writable: writable,
                    model: model,
                    onBusy: { busy = $0 },
                    onClose: { changed in
                        self.editor = nil
                        if changed {
                            message = L.t("已保存；以提供商状态确认是否生效", "Saved; check provider status for activation")
                            reload()
                        }
                    }
                )
            }
        }
        .padding(14)
        .background(expanded ? T.fill2 : T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(expanded ? Color.clear : T.settingsCardStroke, lineWidth: 0.5))
        .padding(.horizontal, 18)
    }

    private func reload() {
        guard model.isOnline, model.ops.contains("models.providers") else { return }
        loading = true
        Task {
            do { try await load(); error = nil }
            catch { self.error = settingsFailure(error) }
            loading = false
        }
    }

    private func load() async throws {
        guard let client = model.clientOrNull() else { throw PocketError(code: "transport", message: L.unavailable()) }
        let result = try await client.modelsProviders()
        rows = result["rows"].arr() ?? []
        namespaces = result["namespaces"].arr() ?? []
        protocols = result["protocols"].arr()?.compactMap { $0.str() }
            ?? providerProtocolChoices(namespaces.first { $0["ns"].str() == "llm-pi-ai" }?["schema"])
        writable = result["writable"].bool() == true
    }

    private func loadInitial() async {
        guard model.isOnline else { loading = false; return }
        loading = true
        do {
            guard model.ops.contains("models.providers") else { throw PocketError(code: "unavailable", message: L.unavailable()) }
            try await load()
            error = nil
            if !setupConsidered {
                setupConsidered = true
                let anyUsable = rows.contains {
                    $0["active"].bool() == true &&
                        ($0["provider"].str() == "deepseek-account" || $0["apiKeyEnv"].str() == nil || $0["credential"]["configured"].bool() == true)
                }
                let setup = rows.first {
                    $0["provider"].str() != "deepseek-account" && ($0["settingsPath"].arr()?.isEmpty == true)
                        && $0["credential"]["configured"].bool() != true
                }
                if !anyUsable, let setup, model.ops.contains("models.providerGet"), let route = setup["provider"].str() {
                    editor = try await model.clientOrNull()?.modelsProviderGet(provider: route)
                }
            }
        } catch {
            self.error = settingsFailure(error)
        }
        loading = false
    }

    private func open(_ row: JSONValue) {
        guard model.isOnline, model.ops.contains("models.providers"), model.ops.contains("models.providerGet"), !busy, !loading else { return }
        loading = true
        Task {
            do {
                try await load()
                editor = try await model.clientOrNull()?.modelsProviderGet(provider: row["provider"].str() ?? "")
                message = nil
                error = nil
            } catch { self.error = settingsFailure(error) }
            loading = false
        }
    }
}

private struct AddModelProviderView: View {
    let catalog: [JSONValue]
    let namespace: JSONValue?
    let protocols: [String]
    let taken: [String]
    let writable: Bool
    @ObservedObject var model: AppModel
    var onBusy: (Bool) -> Void
    var onClose: (Bool) -> Void
    @State private var custom = false
    @State private var target: JSONValue?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !catalog.isEmpty && namespace != nil {
                Picker("", selection: $custom) {
                    Text(L.t("第三方模型提供商", "Third-party provider")).tag(false)
                    Text(L.t("自定义模型 API", "Custom model API")).tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(protocols.isEmpty && custom == false)
            }
            Text(custom
                 ? L.t("连接中转站、自部署服务或其他兼容 OpenAI / Anthropic 协议的接口，需填写 API 地址、协议和模型。", "Connect a gateway, self-hosted service, or another OpenAI / Anthropic-compatible endpoint; provide its URL, protocol, and models.")
                 : L.t("从内置目录中选择模型提供商，填入其 API 密钥即可使用。", "Choose a model provider from the installed catalog and enter its API key."))
            .font(Font.caption).foregroundStyle(T.text3)
            if let error { Text(error).foregroundStyle(T.err).font(Font.caption) }
            if !custom, !catalog.isEmpty {
                Picker(L.t("模型提供商", "Model provider"), selection: Binding(
                    get: { target?["provider"]["provider"].str() ?? catalog.first?["provider"].str() ?? "" },
                    set: { select($0) }
                )) {
                    ForEach(catalog.compactMap { $0["provider"].str() }, id: \.self) { route in
                        Text(providerOptionLabel(row: catalog.first { $0["provider"].str() == route }, route: route)).tag(route)
                    }
                }
            }
            if let namespace, custom {
                ProviderSettingsEditorView(
                    initial: nil,
                    customNamespace: namespace,
                    protocols: protocols,
                    taken: taken,
                    writable: writable,
                    model: model,
                    onBusy: onBusy,
                    onClose: onClose
                )
            }
            if let target, !custom {
                ProviderSettingsEditorView(
                    initial: target,
                    customNamespace: nil,
                    protocols: protocols,
                    taken: taken,
                    writable: writable,
                    model: model,
                    onBusy: onBusy,
                    onClose: onClose
                )
            }
            if !custom && target == nil {
                Button { onClose(false) } label: {
                    OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink)
                        .frame(width: 28, height: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.t("返回", "Back"))
            }
        }
        .padding(14)
        .background(T.fill2, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            custom = catalog.isEmpty
            if let first = catalog.first?["provider"].str() { select(first) }
        }
    }

    private func select(_ route: String) {
        guard model.isOnline, model.ops.contains("models.providerGet") else { return }
        onBusy(true)
        Task {
            do {
                target = try await model.clientOrNull()?.modelsProviderGet(provider: route)
                error = nil
            } catch { self.error = settingsFailure(error) }
            onBusy(false)
        }
    }
}

struct ProviderSettingsEditorView: View {
    let initial: JSONValue?
    let customNamespace: JSONValue?
    let protocols: [String]
    let taken: [String]
    let writable: Bool
    @ObservedObject var model: AppModel
    var onBusy: (Bool) -> Void
    var onClose: (Bool) -> Void

    @State private var namespace: JSONValue?
    @State private var route = ""
    @State private var takenRoutes: Set<String> = []
    @State private var baseURL = ""
    @State private var displayName = ""
    @State private var api = ""
    @State private var models: [JSONValue] = []
    @State private var overridden = false
    @State private var modelsTouched = false
    @State private var keyDraft = ""
    @State private var busy = false
    @State private var committed = false
    @State private var error: String?
    @State private var revision: Int64?
    @State private var baseline: JSONValue?
    @State private var showKey = false
    @State private var confirmRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = initial?["provider"]["error"].str() { Text(err).foregroundStyle(T.err).font(Font.caption) }
            if let error { Text(error).foregroundStyle(T.err).font(Font.caption) }
            if !knownLayout {
                Text(L.t("此提供商由远程主机配置管理。", "This provider is managed in remote host configuration.")).font(Font.caption).foregroundStyle(T.text3)
            }
            if initial == nil {
                field(L.t("Provider ID", "Provider ID")) {
                    TextField("acme-gateway", text: $route).textInputAutocapitalization(.never).disabled(!profileEditable)
                    Text(L.t("以小写字母开头，仅含小写字母、数字和连字符。", "Start with a lowercase letter; use lowercase letters, numbers, and hyphens.")).font(Font.caption).foregroundStyle(T.text3)
                    if !route.isEmpty, let failure = routeFailure { Text(failure).font(Font.caption).foregroundStyle(T.err) }
                }
                field(L.t("显示名称", "Display name")) {
                    TextField(route, text: $displayName).disabled(!profileEditable)
                }
                field(L.t("API 地址", "Base URL")) {
                    TextField("https://gateway.example/v1", text: $baseURL).textInputAutocapitalization(.never).disabled(!profileEditable)
                    if let endpointFailure { Text(endpointFailure).font(Font.caption).foregroundStyle(T.err) }
                }
                field(L.t("API 协议", "API protocol")) {
                    Picker("", selection: $api) {
                        ForEach(protocols, id: \.self) { Text(protocolLabel($0)).tag($0) }
                    }.disabled(!profileEditable)
                }
            }
            if !account && knownLayout {
                field(L.t("API 密钥", "API key")) {
                    HStack {
                        Group {
                            if showKey { TextField("", text: $keyDraft) }
                            else { SecureField("", text: $keyDraft) }
                        }
                        .textInputAutocapitalization(.never)
                        .disabled(!keyWritable || !model.isOnline)
                        Button(showKey ? L.t("隐藏", "Hide") : L.t("显示", "Show")) { showKey.toggle() }
                    }
                    if let keyFailure, !keyDraft.isEmpty { Text(L.t("请只粘贴有效的 API 密钥", "Paste only a valid API key")).font(Font.caption).foregroundStyle(T.err); Text(keyFailure).hidden() }
                }
            }
            if knownLayout && (initial == nil || overridden || modelsTouched) {
                field(L.t("模型", "Models")) {
                    ForEach(Array(models.enumerated()), id: \.offset) { index, row in
                        TextField("id", text: Binding(
                            get: { row["id"].str() ?? "" },
                            set: { models[index] = patchModel(row, "id", .string($0)) }
                        )).textInputAutocapitalization(.never)
                    }
                    Button(L.t("添加模型", "Add model")) {
                        models.append(jsonObject(["id": .string(""), "name": .string("")]))
                        modelsTouched = true
                        overridden = true
                    }.disabled(!profileEditable)
                    if let modelFailure { Text(modelFailure).font(Font.caption).foregroundStyle(T.err) }
                }
            }
            HStack {
                Button(L.save(), action: save)
                    .disabled(!model.isOnline || busy || !writable)
                Spacer()
                Button { onClose(false) } label: {
                    OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink)
                        .frame(width: 28, height: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.t("返回", "Back"))
                .disabled(busy)
                if initial != nil, !account, model.ops.contains("models.settingsMutate") {
                    Button(L.delete(), role: .destructive) { confirmRemove = true }.disabled(busy || !writable)
                }
            }
        }
        .onAppear(perform: hydrate)
        .confirmationDialog(L.t("删除此提供商？", "Remove this provider?"), isPresented: $confirmRemove) {
            Button(L.delete(), role: .destructive, action: remove)
            Button(L.cancel(), role: .cancel) {}
        }
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).foregroundStyle(T.ink)
            content()
        }
    }

    private var row: JSONValue? { initial?["provider"] }
    private var ns: String { namespace?["ns"].str() ?? row?["settingsNs"].str() ?? "" }
    private var account: Bool { route == "deepseek-account" }
    private var custom: Bool { initial == nil || row?["declared"].bool() == true }
    private var knownLayout: Bool { account || ns == "llm-deepseek" || ns == "llm-pi-ai" }
    private var path: [String] {
        if initial == nil { return ["providers", route] }
        return (row?["settingsPath"].arr() ?? []).compactMap { $0.str() }
    }
    private var profileEditable: Bool { model.isOnline && writable && knownLayout && namespace != nil && model.ops.contains("models.settingsMutate") && !busy }
    private var keyWritable: Bool { writable && credential["writable"].bool() != false && model.ops.contains("credentials.set") }
    private var credential: JSONValue { row?["credential"] ?? row?["derivedCredential"] ?? .null }
    private var ref: String { effective["apiKeyEnv"].str() ?? row?["apiKeyEnv"].str() ?? providerKeyRef(route) }
    private var effective: JSONValue { settingsPathValue(namespace?["value"] ?? .null, path) }
    private var keyFailure: String? { providerKeyFailure(keyDraft) }
    private var modelFailure: String? { (overridden || initial == nil) ? validateProviderModels(models) : nil }
    private var routeFailure: String? { initial == nil && !committed ? providerRouteFailure(route, taken: takenRoutes) : nil }
    private var endpointFailure: String? {
        if baseURL.trimmingCharacters(in: .whitespaces).isEmpty || account { return nil }
        return providerEndpointValid(baseURL) ? nil : L.t("请输入有效的 HTTP(S) 地址", "Enter a valid HTTP(S) endpoint")
    }

    private func hydrate() {
        namespace = initial?["namespace"] ?? customNamespace
        route = row?["provider"].str() ?? ""
        takenRoutes = Set(taken)
        let original = settingsPathValue(namespace?["user"] ?? .null, path)
        baseline = original.isNull ? nil : original
        revision = namespace?["revision"].long()
        baseURL = original["baseURL"].str() ?? ""
        displayName = original["displayName"].str() ?? ""
        api = original["api"].str() ?? effective["api"].str() ?? (initial == nil ? protocols.first ?? "" : "")
        let inherited = initial?["inheritedModels"].arr() ?? []
        models = original["models"].arr() ?? inherited
        overridden = !original["models"].isNull
    }

    private func save() {
        guard model.isOnline, !busy else { return }
        busy = true
        onBusy(true)
        error = nil
        Task {
            do {
                try await persist()
                onClose(true)
            } catch {
                self.error = settingsFailure(error, secret: keyDraft.trimmingCharacters(in: .whitespaces))
            }
            busy = false
            onBusy(false)
        }
    }

    private func persist() async throws {
        guard let client = model.clientOrNull() else { throw PocketError(code: "transport", message: L.unavailable()) }
        if keyFailure != nil { throw PocketError(code: "invalid", message: L.t("请只粘贴有效的 API 密钥", "Paste only a valid API key")) }
        if let modelFailure { throw PocketError(code: "invalid", message: modelFailure) }
        let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let creating = initial == nil && !committed
        if creating {
            if let routeFailure { throw PocketError(code: "invalid", message: routeFailure) }
            guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty, protocols.contains(api), !models.isEmpty else {
                throw PocketError(code: "invalid", message: L.t("请填写端点、协议和至少一个模型", "Provide an endpoint, protocol, and at least one model"))
            }
        }
        if let endpointFailure { throw PocketError(code: "invalid", message: endpointFailure) }
        if !(initial == nil && committed) {
            var fields: [String: JSONValue] = [:]
            if !account { fields["baseURL"] = baseURL.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(baseURL.trimmingCharacters(in: .whitespaces)) }
            if custom {
                fields["displayName"] = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(displayName)
                fields["api"] = api.isEmpty ? .null : .string(api)
            }
            if modelsTouched || creating { fields["models"] = (overridden || creating) ? .array(models) : .null }
            if !account && ns == "llm-pi-ai" && !key.isEmpty && effective["apiKeyEnv"].str() == nil {
                fields["apiKeyEnv"] = .string(ref)
            }
            let changes: [JSONValue]
            if creating {
                let value = JSONValue.object(fields.filter { !$0.value.isNull })
                changes = [jsonObjectKeeping(["op": .string("set"), "path": .array(path.map { .string($0) }), "value": value])]
            } else {
                changes = providerFieldOps(path: path, before: baseline, after: fields)
            }
            if !changes.isEmpty {
                guard let revision else { throw PocketError(code: "invalid", message: L.t("缺少配置版本，请重新打开", "Configuration revision missing; reopen editor")) }
                let result = try await client.modelsSettingsMutate(ns: ns, ops: .array(changes), expectedRevision: revision)
                try requireSettingsSuccess(result)
                let written = result["ns"].str() == ns ? result : (result["view"].isNull ? result["namespace"] : result["view"])
                self.revision = written["revision"].long()
                baseline = settingsPathValue(written["user"], path)
                namespace = written
                committed = true
            }
        }
        if !account && !key.isEmpty {
            guard keyWritable else { throw PocketError(code: "invalid", message: L.t("密钥为只读", "API key is read-only")) }
            try requireSettingsSuccess(try await client.credentialsSet(ref: ref, value: key))
        }
        let confirmed = try await client.modelsProviderGet(provider: route)
        if initial == nil || row?["configured"].bool() == false {
            guard confirmed["provider"]["provider"].str() == route, confirmed["provider"]["configured"].bool() == true else {
                throw PocketError(code: "invalid", message: L.t("配置已写入，但尚未回读确认提供商；草稿已保留", "Configuration written, but provider is not confirmed; draft retained"))
            }
        }
        if !account && !key.isEmpty {
            let keyState = confirmed["provider"]["credential"].isNull ? confirmed["provider"]["derivedCredential"] : confirmed["provider"]["credential"]
            guard keyState["configured"].bool() == true else {
                throw PocketError(code: "invalid", message: L.t("写入已返回，但尚未回读确认密钥；草稿已保留", "Write returned, but key is not confirmed; draft retained"))
            }
        }
        keyDraft = ""
    }

    private func remove() {
        guard let client = model.clientOrNull() else { return }
        busy = true
        onBusy(true)
        Task {
            do {
                try await removeProviderSafely(
                    progress: ProviderRemovalProgress(),
                    onProgress: { _ in },
                    removeConfiguration: {
                        guard let revision else { throw PocketError(code: "invalid", message: L.unavailable()) }
                        let ops = [jsonObjectKeeping(["op": .string("unset"), "path": .array(path.map { .string($0) })])]
                        try requireSettingsSuccess(try await client.modelsSettingsMutate(ns: ns, ops: .array(ops), expectedRevision: revision))
                    },
                    confirmRemoval: {
                        _ = try await client.modelsProviderGet(provider: route)
                    },
                    clearManagedCredential: {
                        if model.ops.contains("credentials.unset") {
                            _ = try await client.credentialsUnset(ref: ref)
                        }
                    }
                )
                onClose(true)
            } catch {
                self.error = settingsFailure(error)
            }
            busy = false
            onBusy(false)
        }
    }
}

private func patchModel(_ model: JSONValue, _ field: String, _ value: JSONValue) -> JSONValue {
    var object = model.obj() ?? [:]
    object[field] = value
    return .object(object)
}
