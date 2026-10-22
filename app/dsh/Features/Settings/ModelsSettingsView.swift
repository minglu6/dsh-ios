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
    @State private var savedRoute: String?
    @State private var editor: JSONValue?
    @State private var adding = false
    @State private var busy = false
    @State private var setupConsidered = false
    @State private var deleteTarget: JSONValue?
    @State private var deleteError: String?
    @State private var removalProgress = ProviderRemovalProgress()
    @State private var deleteSnapshot: JSONValue?

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
                    if let savedRoute {
                        let name = providerOptionLabel(row: rows.first { $0["provider"].str() == savedRoute }, route: savedRoute, english: L.en)
                        Text(L.t("已保存 \(name)。", "Saved \(name)."))
                            .font(.system(size: 13)).foregroundStyle(T.ok)
                            .padding(.horizontal, 22)
                            .accessibilityIdentifier("models.savedNotice")
                    }
                    if loading && rows.isEmpty { ProgressView().frame(maxWidth: .infinity).padding() }
                    if error != nil {
                        Button(L.retry(), action: reload)
                            .disabled(!model.isOnline || !model.ops.contains("models.providers") || busy || loading)
                            .padding(.horizontal, 22)
                    }
                    ForEach(configured, id: \.providerRouteID) { row in
                        providerCard(row)
                    }
                    if !adding {
                        Button {
                            adding = true
                            editor = nil
                            savedRoute = nil
                        } label: {
                            HStack {
                                OfficialGlyph(kind: .plusOutline, size: 16, color: canAdd ? T.ink : T.text3)
                                    .accessibilityIdentifier(modelsAddProviderSymbol())
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
                        .accessibilityIdentifier("models.add")
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
                            onClose: { route in
                                adding = false
                                if let route { reload(saved: route) }
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
        .providerModelPickerOverlay()
        .overlay(alignment: .bottomLeading) {
#if DEBUG
            ModelsSettingsFixtureStatus(model: model)
#endif
        }
        .overlay {
            if let deleteTarget { deletionDialog(deleteTarget) }
        }
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
        model.isOnline && !busy && !loading && error == nil && writable && model.ops.contains("models.settingsMutate") && addOptions.enabled(protocols: protocols)
    }

    private func providerCard(_ row: JSONValue) -> some View {
        let route = row["provider"].str() ?? ""
        let expanded = !adding && editor?["provider"]["provider"].str() == route
        let name = providerDisplayName(row, route: route, english: L.en)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(name).font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if row["declared"].bool() == true {
                    Text(L.t("自定义", "Custom")).font(.system(size: 11)).foregroundStyle(T.text2)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(T.border))
                }
                if route == "deepseek-account" {
                    Circle().fill(T.ok).frame(width: 7, height: 7)
                        .accessibilityLabel(L.t("已登录", "Signed in"))
                } else if row["credential"]["configured"].bool() == true {
                    Circle().fill(T.ok).frame(width: 7, height: 7)
                        .accessibilityLabel(L.t("API 密钥已配置", "API key configured"))
                } else if row["apiKeyEnv"].str() != nil && row["credential"]["configured"].bool() == false {
                    Circle().fill(T.err).frame(width: 7, height: 7)
                        .accessibilityLabel(L.t("API 密钥未配置", "API key missing"))
                }
                Spacer(minLength: 0)
                if route != "deepseek-account" {
                    Button(L.t("编辑", "Edit")) {
                        savedRoute = nil
                        adding = false
                        if expanded { editor = nil } else { open(row) }
                    }
                    .buttonStyle(ModelSettingsButtonStyle(compact: true))
                    .disabled(!model.isOnline || !model.ops.contains("models.providerGet") || busy || loading)
                    .accessibilityIdentifier("models.edit.\(route)")
                }
                if row["removable"].bool() == true, route != "deepseek-account" {
                    Button(L.delete()) {
                        savedRoute = nil
                        deleteError = nil
                        removalProgress = ProviderRemovalProgress()
                        deleteSnapshot = nil
                        deleteTarget = row
                    }
                    .buttonStyle(ModelSettingsButtonStyle(destructive: true, compact: true))
                    .disabled(!model.isOnline || !writable || !model.ops.contains("models.settingsMutate") || busy || loading)
                    .accessibilityIdentifier("models.delete.\(route)")
                }
            }
            if let error = row["error"].str() {
                Text(error).font(.system(size: 12)).foregroundStyle(T.err)
            }
            if expanded, let editor {
                ProviderSettingsEditorView(
                    initial: editor, customNamespace: nil, protocols: protocols, taken: [],
                    writable: writable, model: model, onBusy: { busy = $0 },
                    onClose: { route in
                        self.editor = nil
                        if let route { reload(saved: route) }
                    }
                )
                .id(route)
                .padding(14)
                .background(T.fill2, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
        .padding(.horizontal, 18)
    }

    private func reload() { reload(saved: nil) }

    private func reload(saved route: String?) {
        guard model.isOnline, model.ops.contains("models.providers") else { return }
        loading = true
        Task {
            do {
                try await load()
                error = nil
                if let route { savedRoute = route }
            }
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
                savedRoute = nil
                error = nil
            } catch { self.error = settingsFailure(error) }
            loading = false
        }
    }

    private func deletionDialog(_ row: JSONValue) -> some View {
        let route = row["provider"].str() ?? ""
        let name = providerOptionLabel(row: row, route: route, english: L.en)
        return GeometryReader { geometry in
            ZStack {
                T.scrim.ignoresSafeArea().onTapGesture { if !busy { deleteTarget = nil } }
                VStack(alignment: .leading, spacing: 18) {
                    Text(L.t("删除 \(name)？", "Remove \(name)?"))
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(T.ink)
                    Text(L.t("删除此提供商的自定义配置；如有默认配置，将恢复默认值。", "Remove this provider's custom configuration, restoring defaults where available."))
                        .font(.system(size: 13)).foregroundStyle(T.text2)
                    if let deleteError { Text(deleteError).font(.system(size: 12)).foregroundStyle(T.err) }
                    HStack {
                        Spacer()
                        Button(L.cancel()) { deleteTarget = nil }
                            .buttonStyle(ModelSettingsButtonStyle()).disabled(busy)
                        Button(busy ? L.t("正在删除…", "Removing…") : L.delete()) { remove(row) }
                            .buttonStyle(ModelSettingsButtonStyle(destructive: true))
                            .disabled(busy || !model.isOnline || !writable || !model.ops.contains("models.settingsMutate"))
                            .accessibilityIdentifier("models.delete.confirm")
                    }
                }
                .padding(24).frame(width: max(0, min(440, geometry.size.width - 40)))
                .background(T.surface2, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(T.borderL1, lineWidth: 0.5))
                .accessibilityAddTraits(.isModal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func remove(_ row: JSONValue) {
        guard !busy, model.isOnline, writable, model.ops.contains("models.settingsMutate"), let client = model.clientOrNull(),
              let route = row["provider"].str(), row["removable"].bool() == true else { return }
        busy = true
        deleteError = nil
        Task {
            defer { busy = false }
            do {
                let snapshot: JSONValue
                if removalProgress.configurationRemoved, let deleteSnapshot {
                    snapshot = deleteSnapshot
                } else {
                    snapshot = try await client.modelsProviderGet(provider: route)
                    deleteSnapshot = snapshot
                }
                let ns = snapshot["namespace"]["ns"].str() ?? ""
                let path = (snapshot["provider"]["settingsPath"].arr() ?? []).compactMap { $0.str() }
                guard !path.isEmpty, let revision = snapshot["namespace"]["revision"].long() else {
                    throw PocketError(code: "invalid", message: L.t("无法确认可删除的提供商配置", "Cannot confirm a removable provider configuration"))
                }
                try await removeProviderSafely(
                    progress: removalProgress,
                    onProgress: { removalProgress = $0 },
                    removeConfiguration: {
                        let ops = [jsonObjectKeeping(["op": .string("unset"), "path": .array(path.map { .string($0) })])]
                        try requireSettingsSuccess(try await client.modelsSettingsMutate(ns: ns, ops: .array(ops), expectedRevision: revision))
                    },
                    confirmRemoval: {
                        let listed = try await client.modelsProviders()
                        guard let namespace = listed["namespaces"].arr()?.first(where: { $0["ns"].str() == ns }),
                              settingsPathValue(namespace["user"], path).isNull else {
                            throw PocketError(code: "invalid", message: L.t("删除尚未回读确认，请重试", "Removal is not yet confirmed; retry"))
                        }
                    },
                    clearManagedCredential: {
                        let ref = providerKeyRef(route)
                        if row["apiKeyEnv"].str() == ref,
                           row["credential"]["configured"].bool() == true,
                           row["credential"]["writable"].bool() == true,
                           model.ops.contains("credentials.unset") {
                            try requireSettingsSuccess(try await client.credentialsUnset(ref: ref))
                        }
                    }
                )
                if editor?["provider"]["provider"].str() == route { editor = nil }
                try await load()
                deleteTarget = nil
            } catch {
                deleteError = settingsFailure(error)
            }
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
    var onClose: (String?) -> Void
    @State private var custom = false
    @State private var visitedCustom = false
    @State private var target: JSONValue?
    @State private var selectedRoute = ""
    @State private var selecting = false
    @State private var editorBusy = false
    @State private var error: String?
    private var busy: Bool { selecting || editorBusy }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !catalog.isEmpty && namespace != nil {
                Picker("", selection: Binding(
                    get: { custom },
                    set: { custom = $0; if $0 { visitedCustom = true } }
                )) {
                    Text(L.t("第三方模型提供商", "Third-party provider")).tag(false)
                    Text(L.t("自定义模型 API", "Custom model API")).tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(busy || protocols.isEmpty)
                .accessibilityIdentifier("models.add.mode")
            }
            Text(custom
                 ? L.t("连接中转站、自部署服务或其他兼容 OpenAI / Anthropic 协议的接口，需填写 API 地址、协议和模型。", "Connect a gateway, self-hosted service, or another OpenAI / Anthropic-compatible endpoint; provide its URL, protocol, and models.")
                 : L.t("从内置目录中选择模型提供商，填入其 API 密钥即可使用。", "Choose a model provider from the installed catalog and enter its API key."))
                .font(.system(size: 12)).foregroundStyle(T.text3)
            if let error { Text(error).foregroundStyle(T.err).font(.system(size: 12)) }
            if !custom, !catalog.isEmpty {
                Picker(L.t("提供商", "Provider"), selection: Binding(
                    get: { selectedRoute },
                    set: { select($0) }
                )) {
                    ForEach(catalog, id: \.providerRouteID) { row in
                        Text(providerDisplayName(row, route: row.providerRouteID, english: L.en))
                            .tag(row.providerRouteID)
                            .accessibilityIdentifier("models.add.catalog.\(row.providerRouteID)")
                    }
                }
                .tint(T.ink)
                .padding(.horizontal, 10).frame(minHeight: 36)
                .background(T.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.borderL3, lineWidth: 0.5))
                .disabled(busy)
                .accessibilityIdentifier("models.add.catalog")
            }
            if let namespace, visitedCustom {
                ProviderSettingsEditorView(
                    initial: nil, customNamespace: namespace, protocols: protocols, taken: taken,
                    writable: writable, model: model, onBusy: setBusy, onClose: onClose
                )
                .frame(height: custom ? nil : 0).clipped().opacity(custom ? 1 : 0)
                .accessibilityHidden(!custom).allowsHitTesting(custom)
            }
            if let target {
                ProviderSettingsEditorView(
                    initial: target, customNamespace: nil, protocols: protocols, taken: taken,
                    writable: writable, model: model, onBusy: setBusy, onClose: onClose
                )
                .id(target["provider"]["provider"].str())
                .frame(height: custom ? 0 : nil).clipped().opacity(custom ? 0 : 1)
                .accessibilityHidden(custom).allowsHitTesting(!custom)
            }
            if !custom && target == nil {
                HStack {
                    if busy { ProgressView() }
                    Spacer()
                    Button(L.cancel()) { onClose(nil) }
                        .buttonStyle(ModelSettingsButtonStyle()).disabled(busy)
                        .accessibilityIdentifier("models.cancel")
                }
            }
        }
        .padding(14)
        .background(T.fill2, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            custom = catalog.isEmpty
            visitedCustom = custom
            if let first = catalog.first?["provider"].str() { select(first) }
        }
    }

    private func setBusy(_ value: Bool) {
        editorBusy = value
        onBusy(busy)
    }

    private func select(_ route: String) {
        guard !busy, model.isOnline, model.ops.contains("models.providerGet"), let client = model.clientOrNull() else { return }
        selectedRoute = route
        target = nil
        selecting = true
        onBusy(true)
        Task {
            defer {
                selecting = false
                onBusy(busy)
            }
            do {
                target = try await client.modelsProviderGet(provider: route)
                error = nil
            } catch { self.error = settingsFailure(error) }
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
    var onClose: (String?) -> Void

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
    @State private var customized = false
    @State private var listBusy = false
    @State private var hydrated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let row, row["configured"].bool() == true {
                HStack(spacing: 8) {
                    Text(providerDisplayName(row, route: route, english: L.en))
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink)
                    if providerDisplayName(row, route: route, english: L.en) != route {
                        Text(route).font(.system(size: 12)).foregroundStyle(T.text3).lineLimit(1)
                    }
                }
            }
            if !knownLayout {
                Text(L.t("此提供商由远程主机配置管理。", "This provider is managed in remote host configuration."))
                    .font(.system(size: 12)).foregroundStyle(T.text3)
            } else {
                if initial == nil {
                    field("Provider ID") {
                        TextField("acme-gateway", text: $route)
                            .disabled(!profileEditable || committed)
                            .accessibilityIdentifier("models.add.route")
                        Text(L.t("以小写字母开头，仅含小写字母、数字和连字符。", "Start with a lowercase letter; use lowercase letters, numbers, and hyphens."))
                            .font(.system(size: 12)).foregroundStyle(T.text3)
                        if !route.isEmpty, let routeFailure { validation(routeFailure) }
                    }
                    profileFields
                }
                if !keylessNativeAuth {
                    field(L.t("API 密钥", "API key")) {
                        HStack(spacing: 8) {
                            Group {
                                if showKey { TextField(keyPlaceholder, text: $keyDraft) }
                                else { SecureField(keyPlaceholder, text: $keyDraft) }
                            }
                            .disabled(!keyWritable || !model.isOnline || busy || listBusy)
                            .accessibilityIdentifier("models.apiKey")
                            Button(showKey ? L.t("隐藏", "Hide") : L.t("显示", "Show")) { showKey.toggle() }
                                .font(.system(size: 12)).foregroundStyle(T.text2)
                                .disabled(busy || listBusy)
                        }
                        if !keyDraft.isEmpty, keyFailure != nil {
                            validation(L.t("请只粘贴有效的 API 密钥", "Paste only a valid API key"))
                        } else if keyDraft.isEmpty, credential["configured"].bool() == true {
                            Text(L.t("已配置密钥；留空保留现有密钥。", "A key is configured; leave blank to keep it."))
                                .font(.system(size: 12)).foregroundStyle(T.text3)
                        }
                    }
                }
                if initial != nil {
                    Button { customized.toggle() } label: {
                        HStack(spacing: 6) {
                            OfficialGlyph(kind: .chevronRight, size: 12, color: T.text2)
                                .rotationEffect(.degrees(customized ? 90 : 0))
                            Text(L.t("自定义设置", "Custom settings"))
                        }
                        .font(.system(size: 13)).foregroundStyle(T.text2)
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(busy || listBusy)
                    .accessibilityIdentifier("models.customSettings")
                    .accessibilityValue(customized ? L.t("已展开", "Expanded") : L.t("已折叠", "Collapsed"))
                }
                VStack(alignment: .leading, spacing: 14) {
                    if initial != nil { profileFields }
                    ProviderModelListEditor(
                        models: $models, inheritedModels: initial?["inheritedModels"].arr() ?? [],
                        overridden: $overridden, touched: $modelsTouched, namespace: namespace,
                        provider: initial == nil ? nil : route, declared: custom,
                        baseURL: baseURL.isEmpty ? effective["baseURL"].str() ?? row?["defaultBaseURL"].str() ?? "" : baseURL,
                        api: api, apiKey: keyDraft.trimmingCharacters(in: .whitespacesAndNewlines),
                        disabled: !model.isOnline || !writable || !knownLayout || namespace == nil || !model.ops.contains("models.settingsMutate") || busy,
                        model: model,
                        onBusy: { listBusy = $0; onBusy(busy || $0) }
                    )
                }
                .frame(height: initial == nil || customized ? nil : 0).clipped()
                .opacity(initial == nil || customized ? 1 : 0)
                .accessibilityHidden(initial != nil && !customized)
                .allowsHitTesting(initial == nil || customized)
            }
            if let error {
                validation(error).accessibilityIdentifier("models.error")
            }
            if let modelFailure { validation(modelFailure) }
            HStack(spacing: 8) {
                Spacer()
                Button(L.cancel()) { onClose(nil) }
                    .buttonStyle(ModelSettingsButtonStyle())
                    .disabled(busy || listBusy).accessibilityIdentifier("models.cancel")
                Button(busy ? L.t("正在保存…", "Saving…") : L.save(), action: save)
                    .buttonStyle(ModelSettingsButtonStyle(primary: true))
                    .disabled(!canSave).accessibilityIdentifier("models.save")
            }
        }
        .font(.system(size: 13))
        .textFieldStyle(ModelSettingsTextFieldStyle())
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .onAppear(perform: hydrate)
    }

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            if custom {
                field(L.t("显示名称", "Display name")) {
                    TextField(route, text: $displayName)
                        .disabled(!profileEditable).accessibilityIdentifier("models.displayName")
                }
            }
            field(L.t("API 地址", "Base URL")) {
                TextField(row?["defaultBaseURL"].str() ?? effective["baseURL"].str() ?? "https://gateway.example/v1", text: $baseURL)
                    .disabled(!profileEditable).accessibilityIdentifier("models.baseURL")
                if let endpointFailure { validation(endpointFailure) }
            }
            if custom {
                field(L.t("API 协议", "API protocol")) {
                    Picker("", selection: $api) {
                        if api.isEmpty { Text(L.t("选择协议", "Select protocol")).tag("") }
                        ForEach(protocols, id: \.self) { Text(protocolLabel($0)).tag($0) }
                    }
                    .tint(T.ink)
                    .padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .background(T.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.borderL3, lineWidth: 0.5))
                    .disabled(!profileEditable).accessibilityIdentifier("models.api")
                }
            }
        }
    }

    private func validation(_ message: String) -> some View {
        Text(message).font(.system(size: 12)).foregroundStyle(T.err)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13)).foregroundStyle(T.ink)
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
    private var profileEditable: Bool { model.isOnline && writable && knownLayout && namespace != nil && model.ops.contains("models.settingsMutate") && !busy && !listBusy }
    private var keyWritable: Bool { writable && credential["writable"].bool() != false && model.ops.contains("credentials.set") }
    private var credential: JSONValue {
        guard let row else { return .null }
        return row["credential"].isNull ? row["derivedCredential"] : row["credential"]
    }
    private var ref: String { effective["apiKeyEnv"].str() ?? row?["apiKeyEnv"].str() ?? providerKeyRef(route) }
    private var effective: JSONValue { settingsPathValue(namespace?["value"] ?? .null, path) }
    private var keyFailure: String? { providerKeyFailure(keyDraft) }
    private var modelFailure: String? {
        guard overridden || initial == nil else { return nil }
        if custom && ns == "llm-pi-ai" && !providerModelReasoningLevels(namespace?["schema"]).isEmpty {
            return providerModelListFailure(models)
        }
        return validateProviderModels(models)
    }
    private var routeFailure: String? { initial == nil && !committed ? providerRouteFailure(route, taken: takenRoutes) : nil }
    private var endpointFailure: String? {
        if baseURL.trimmingCharacters(in: .whitespaces).isEmpty || account { return nil }
        return providerEndpointValid(baseURL) ? nil : L.t("请输入有效的 HTTP(S) 地址", "Enter a valid HTTP(S) endpoint")
    }
    private var keylessNativeAuth: Bool {
        effective["apiKeyEnv"].str() == nil && row?["nativeAuth"]["env"].arr()?.isEmpty == true
            && row?["nativeAuth"]["oauth"].bool() == true
    }
    private var keyPlaceholder: String {
        credential["configured"].bool() == true
            ? L.t("已保存，留空不修改", "Saved; leave blank to keep")
            : L.t("输入 API 密钥", "Enter API key")
    }
    private var canSave: Bool {
        profileEditable && keyFailure == nil && modelFailure == nil && endpointFailure == nil
            && (keyDraft.isEmpty || keyWritable)
            && (initial != nil || (routeFailure == nil && !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && protocols.contains(api) && !models.isEmpty))
    }

    private func hydrate() {
        guard !hydrated else { return }
        hydrated = true
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
        guard canSave else { return }
        busy = true
        onBusy(true)
        error = nil
        Task {
            do {
                try await persist()
                busy = false
                onBusy(false)
                onClose(route)
                return
            } catch {
                self.error = settingsFailure(error, secret: keyDraft.trimmingCharacters(in: .whitespacesAndNewlines))
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
        do {
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

}

private extension JSONValue {
    var providerRouteID: String { self["provider"].str() ?? "" }
}

private struct ModelSettingsTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 13)).foregroundStyle(T.ink)
            .padding(.horizontal, 10).frame(height: 36)
            .background(T.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.borderL3, lineWidth: 0.5))
    }
}

private struct ModelSettingsButtonStyle: ButtonStyle {
    var primary = false
    var destructive = false
    var compact = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 14, weight: .medium))
            .foregroundStyle(primary ? T.onPrimary : destructive ? T.err : T.ink)
            .padding(.horizontal, compact ? 10 : 14).frame(height: compact ? 28 : 36)
            .background(primary ? T.primaryButton : configuration.isPressed ? T.fill : Color.clear, in: RoundedRectangle(cornerRadius: compact ? 8 : 10))
            .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 10).stroke(primary || destructive ? Color.clear : T.borderL3, lineWidth: 0.5))
            .opacity(enabled ? 1 : 0.4)
            .fixedSize()
    }
}
