import SwiftUI
import DSHProtocol

struct PluginBuiltinItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let artwork: String
    let namespace: String

    static func available(in namespaces: [JSONValue]) -> [PluginBuiltinItem] {
        let served = Set(namespaces.compactMap { $0["ns"].str() })
        var items: [PluginBuiltinItem] = []
        if served.contains("subagent") || served.contains("subagent-model-selection-settings") {
            items.append(.init(id: "subagent", title: L.t("子智能体", "Subagent"), description: L.t("设置子智能体的递归层级、数量和模型。", "Set Subagent recursion depth, count, and models."), artwork: "subagent", namespace: served.contains("subagent") ? "subagent" : "subagent-model-selection-settings"))
        }
        if served.contains("web-search-deepseek") {
            items.append(.init(id: "web-search", title: L.t("网页搜索", "Web search"), description: L.t("设置 DeepSeek 的搜索提供方。", "Set up the DeepSeek search provider."), artwork: "search", namespace: "web-search-deepseek"))
        }
        if served.contains("agent-loop") {
            items.append(.init(id: "agent-loop", title: L.t("Agent 循环", "Agent loop"), description: L.t("控制 Agent 派发工具调用的方式。", "Control how the Agent dispatches tool calls."), artwork: "loop", namespace: "agent-loop"))
        }
        if served.contains("bash-sandbox") || served.contains("pwsh-sandbox") {
            items.append(.init(id: "shell", title: L.t("终端", "Shell"), description: L.t("限制每条命令最多能跑多久、最多输出多少内容。", "Limit how long each command may run and how much it may output."), artwork: "terminal", namespace: served.contains("pwsh-sandbox") ? "pwsh-sandbox" : "bash-sandbox"))
        }
        return items
    }
}

private struct BuiltinField: Identifiable {
    let ns: String
    let key: String
    let label: String
    let hint: String
    var numeric = true
    var minimum: Double?
    var maximum: Double?
    var help = false
    var id: String { "\(ns).\(key)" }

    func parse(_ text: String) -> JSONValue? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .null }
        if !numeric { return .string(text) }
        guard let number = Double(text), number.isFinite else { return nil }
        if let minimum {
            guard number >= minimum, number.rounded() == number, number <= 9_007_199_254_740_991,
                  !(number == 0 && number.sign == .minus) else { return nil }
        }
        if let maximum, number > maximum { return nil }
        return .number(number)
    }

    var invalidLabel: String {
        if maximum == 50 { return L.t("请填 1–50 的整数；留空表示使用默认值。", "Enter an integer from 1 to 50, or leave blank to use the default.") }
        if minimum == 0 { return L.t("请输入不小于 0 的整数。", "Enter a whole number of 0 or more.") }
        if minimum == 1 { return L.t("请输入不小于 1 的整数。", "Enter a whole number of 1 or more.") }
        return L.t("请填数字；留空表示使用默认值。", "Enter a number, or leave blank to use the default.")
    }
}

private struct BuiltinDraft {
    var text: String
    var reset = false
}

struct PluginBuiltinConfiguration: View {
    @ObservedObject var model: AppModel
    let item: PluginBuiltinItem
    let namespaces: [JSONValue]
    let writable: Bool
    var onBack: () -> Void
    @State private var snapshots: [String: JSONValue]
    @State private var drafts: [String: BuiltinDraft] = [:]
    @State private var stagedValues: [String: [String: JSONValue]] = [:]
    @State private var helpFields: Set<String> = []
    @State private var saving = false
    @State private var error: String?
    @State private var catalog: ModelCatalog?
    @State private var catalogLoading = false
    @State private var catalogError: String?
    @State private var keyText = ""
    @State private var credential: JSONValue?
    @State private var credentialError: String?

    private let modelsNS = "subagent-model-selection-settings"

    init(model: AppModel, item: PluginBuiltinItem, namespaces: [JSONValue], writable: Bool, onBack: @escaping () -> Void) {
        self.model = model
        self.item = item
        self.namespaces = namespaces
        self.writable = writable
        self.onBack = onBack
        _snapshots = State(initialValue: Dictionary(namespaces.compactMap { value in value["ns"].str().map { ($0, value) } }, uniquingKeysWith: { _, last in last }))
    }

    private var fields: [BuiltinField] {
        switch item.id {
        case "subagent":
            guard snapshots["subagent"] != nil else { return [] }
            return [
                .init(ns: "subagent", key: "maxDepth", label: L.t("最大递归深度", "Maximum recursion depth"), hint: L.t("限制 Agent 创建子智能体的递归层级。", "Limits how many levels of Subagents an Agent can create."), minimum: 0, help: true),
                .init(ns: "subagent", key: "maxActiveSubagents", label: L.t("子智能体并行数量上限", "Subagent parallelism limit"), hint: L.t("同一主 Agent 下，所有递归层级同时存活的子智能体总数，主 Agent 不计入。达到上限时，新的启动请求会被拒绝。", "Total live Subagents under the same main Agent, across all recursion levels. The main Agent is excluded. New start requests are rejected when the limit is reached."), minimum: 1, help: true)
            ]
        case "agent-loop":
            return [.init(ns: item.namespace, key: "maxParallelToolCalls", label: L.t("并行工具调用数", "Parallel tool calls"), hint: L.t("同一步内最多同时运行多少个可并行的调用。", "Upper bound on parallel-safe calls running at once within one step."))]
        case "shell":
            return [
                .init(ns: item.namespace, key: "timeoutMs", label: L.t("命令超时（毫秒）", "Command timeout (ms)"), hint: L.t("单条命令允许运行多久，超时即终止。", "How long one command may run before it is terminated.")),
                .init(ns: item.namespace, key: "maxOutputBytes", label: L.t("单流输出上限（字节）", "Output cap per stream (bytes)"), hint: L.t("超出部分会转存到临时文件，而不是被丢弃。", "Output beyond this spills to a temporary file rather than being lost."))
            ]
        case "web-search":
            var result = [BuiltinField(ns: "web-search-deepseek", key: "baseURL", label: L.t("Messages API 基础地址", "Messages API base URL"), hint: L.t("填写含 API 前缀的地址，例如 https://api.deepseek.com/anthropic/v1；程序追加 /messages，留空恢复默认。", "Include the API prefix, such as https://api.deepseek.com/anthropic/v1. The provider appends /messages. Leave blank to restore the default."), numeric: false),
                          BuiltinField(ns: "web-search-deepseek", key: "maxUses", label: L.t("单次请求最多搜索次数", "Max searches per request"), hint: L.t("辅助模型在一次 Messages 请求内最多可执行的搜索次数，仅适用于 Messages API。", "How many searches the auxiliary model may run within one Messages request. Applies only to the Messages API."))]
            if snapshots["web-deepseek-api"] != nil {
                result += [BuiltinField(ns: "web-deepseek-api", key: "baseURL", label: L.t("Search / Fetch API 基础地址", "Search / Fetch API base URL"), hint: L.t("填写含 API 前缀的地址，例如 https://api.deepseek.com/v1/tools；程序追加 /search 或 /fetch，留空恢复默认。", "Include the API prefix, such as https://api.deepseek.com/v1/tools. The provider appends /search or /fetch. Leave blank to restore the default."), numeric: false),
                           BuiltinField(ns: "web-deepseek-api", key: "count", label: L.t("每次搜索结果数", "Results per search"), hint: L.t("每个查询返回的结果条数，须为 1–50 的整数，默认 10；不控制搜索调用次数。web_search 保留的来源数不超过其自身的结果上限。", "Results returned per query: an integer from 1 to 50, default 10. This controls result count, not search calls. web_search keeps no more sources than its own result limit."), minimum: 1, maximum: 50)]
            }
            return result
        default: return []
        }
    }

    private var switchAvailable: Bool { snapshots["web"] != nil && snapshots["web-deepseek-api"] != nil }
    private var searchAPI: Bool { switchAvailable && value("web", "searchProvider").str() == "deepseek-search-api" }
    private var searchNS: String { searchAPI ? "web-deepseek-api" : "web-search-deepseek" }
    private var modelsEnabled: Bool { value(modelsNS, "enabled").bool() == true }
    private var routes: [JSONValue] { value(modelsNS, "allowedModels").arr() ?? [] }
    private var credentialRef: String {
        let declared = value(searchNS, "apiKeyEnv").str() ?? ""
        return declared.isEmpty ? "DEEPSEEK_API_KEY" : declared
    }
    private var disabled: Bool { !writable || saving }
    private var invalid: Bool {
        fields.contains { field in drafts[field.id].map { !$0.reset && field.parse($0.text) == nil } ?? false }
            || (item.id == "subagent" && modelsEnabled && routes.isEmpty)
    }
    private var dirty: Bool {
        !keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || snapshots.keys.contains { !operations($0).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        OfficialGlyph(kind: .chevronLeft, size: 14, color: T.text3)
                        Text(L.pluginsNav()).font(.system(size: 12.5)).foregroundStyle(T.text3)
                    }
                }
                .buttonStyle(.plain).accessibilityIdentifier("pluginBuiltinBack")
                PluginArtwork(kind: item.artwork, size: 36)
                    .frame(width: 48, height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.borderL3, lineWidth: 0.5))
                    .padding(.top, 32)
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title).font(.system(size: 20, weight: .medium)).foregroundStyle(T.ink)
                    Text(item.description).font(.system(size: 14)).foregroundStyle(T.text2).lineSpacing(4)
                }
                .padding(.top, 20)
                VStack(alignment: .leading, spacing: 12) {
                    if !writable { hint(L.t("本部署的设置为只读。", "This deployment stores settings read-only.")) }
                    if let error { Text(error).font(.system(size: 13)).foregroundStyle(T.err).textSelection(.enabled) }
                    if snapshots[item.namespace] == nil {
                        hint(L.t("该插件当前未加载，暂时无法配置。", "This plugin is not loaded, so it cannot be configured right now."))
                    } else {
                        configurationFields
                        Button(action: save) {
                            Text(saving ? L.t("保存中…", "Saving…") : L.save())
                                .font(.system(size: 13)).foregroundStyle(T.surface3)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(T.ink, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(saving || invalid || !dirty || (!writable && keyText.isEmpty))
                        .opacity(saving || invalid || !dirty ? 0.4 : 1)
                        .padding(.top, 4)
                        .accessibilityIdentifier("pluginBuiltinSave")
                    }
                }
                .padding(.top, 32)
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(T.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pluginBuiltinConfiguration")
        .onChange(of: namespaces) { incoming in
            let served = Set(incoming.compactMap { $0["ns"].str() })
            snapshots = snapshots.filter { served.contains($0.key) }
            for namespace in incoming {
                guard let ns = namespace["ns"].str(),
                      !drafts.keys.contains(where: { $0.hasPrefix(ns + ".") }),
                      stagedValues[ns] == nil else { continue }
                snapshots[ns] = namespace
            }
        }
        .task(id: "\(modelsEnabled)-\(model.modelSettingsRevision)") {
            if item.id == "subagent" && modelsEnabled { await loadCatalog() }
        }
        .task(id: "\(credentialRef)-\(model.modelSettingsRevision)") {
            if item.id == "web-search" { await loadCredential() }
        }
    }

    @ViewBuilder private var configurationFields: some View {
        if item.id == "subagent" {
            if !fields.isEmpty {
                Text(L.t("运行限制", "Limits")).font(.system(size: 13, weight: .semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), alignment: .top)], alignment: .leading, spacing: 16) {
                    ForEach(fields) { fieldView($0) }
                }
            }
            if snapshots[modelsNS] != nil { modelSelection }
        } else {
            if item.id == "web-search" { webControls }
            VStack(spacing: 0) {
                ForEach(Array(fields.filter { item.id != "web-search" || $0.ns == searchNS }.enumerated()), id: \.element.id) { index, field in
                    if index > 0 { Rectangle().fill(T.border).frame(height: 0.5) }
                    fieldView(field)
                }
            }
        }
    }

    private func fieldView(_ field: BuiltinField) -> some View {
        let draft = drafts[field.id]
        let overridden = draft.map { !$0.reset && field.parse($0.text)?.isNull == false } ?? (snapshots[field.ns]?["user"].obj()?[field.key] != nil)
        let invalid = draft.map { !$0.reset && field.parse($0.text) == nil } ?? false
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(field.label).font(.system(size: 13, weight: .medium)).foregroundStyle(T.ink)
                if field.help {
                    Button {
                        if helpFields.contains(field.id) { helpFields.remove(field.id) } else { helpFields.insert(field.id) }
                    } label: { OfficialGlyph(kind: .infoOutline, size: 14, color: T.text3).frame(width: 24, height: 24) }
                    .buttonStyle(.plain).accessibilityLabel(field.label + L.t("说明", " help"))
                }
                Spacer(minLength: 0)
                if overridden {
                    Text(L.t("已覆盖", "Overridden")).font(.system(size: 11)).foregroundStyle(T.text3)
                    Button(L.t("恢复默认", "Reset to default")) {
                        drafts[field.id] = BuiltinDraft(text: format(snapshots[field.ns]?["base"][field.key] ?? .null), reset: true)
                        error = nil
                    }.font(.system(size: 12)).foregroundStyle(T.text2).buttonStyle(.plain).disabled(disabled)
                }
            }
            TextField("", text: Binding(get: { drafts[field.id]?.text ?? format(value(field.ns, field.key)) }, set: {
                drafts[field.id] = BuiltinDraft(text: $0)
                error = nil
            }))
            .font(.system(size: 13)).foregroundStyle(T.ink)
            .keyboardType(field.numeric ? .numbersAndPunctuation : .URL)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .padding(.horizontal, 12).frame(height: 34)
            .background(T.surface3, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(invalid ? T.err : T.borderStrong, lineWidth: 0.5))
            .disabled(disabled).accessibilityLabel(field.label)
            .accessibilityIdentifier("pluginBuiltinField.\(field.id)")
            if !field.help || helpFields.contains(field.id) {
                hint(field.hint)
                if field.key == "maxDepth" {
                    hint(L.t("0　禁用子智能体\n1　仅允许主 Agent 创建子智能体", "0  Disable Subagents\n1  Only the main Agent can create Subagents"))
                    hint(L.t("如果某个工具单独设置了最大递归深度，以该工具的设置为准。", "If a tool defines its own maximum recursion depth, that setting takes precedence."))
                }
            }
            if invalid { Text(field.invalidLabel).font(.system(size: 12)).foregroundStyle(T.err) }
        }.padding(.vertical, 12)
    }

    private var webControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if switchAvailable {
                toggleRow(L.t("启用新版 Web 搜索 API", "Use the new Web Search API"), on: searchAPI, blocked: disabled || invalid || error != nil) {
                    let enabled = !searchAPI
                    for (key, target) in [("searchProvider", enabled ? "deepseek-search-api" : "deepseek-official"), ("fetchProvider", enabled ? "deepseek-fetch-api" : "http")] {
                        stagedValues["web", default: [:]][key] = snapshots["web"]?["base"][key].str() == target ? .null : .string(target)
                    }
                    error = nil
                }
                hint(L.t("默认关闭，搜索通过 DeepSeek Messages 完成。新版 Web 搜索 API 功能与计费详见", "Off by default: search runs through DeepSeek Messages. For the new Web Search API's features and pricing, see the "))
                Link(L.t("网页搜索与抓取指南", "Search & Fetch guide"), destination: URL(string: L.en ? "https://api-docs.deepseek.com/guides/search" : "https://api-docs.deepseek.com/zh-cn/guides/search")!)
                    .font(.system(size: 12)).foregroundStyle(T.link)
            }
            Text(L.t("API Key", "API key")).font(.system(size: 13, weight: .medium))
            SecureField("", text: $keyText)
                .font(.system(size: 13)).textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(.horizontal, 12).frame(height: 34)
                .background(T.surface3, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.borderStrong, lineWidth: 0.5))
                .disabled(saving || credential?["writable"].bool() != true || !model.ops.contains("credentials.set"))
                .accessibilityLabel(L.t("API Key", "API key"))
            hint(L.t("不写入设置文件。留空表示保持当前密钥。", "Stored outside the settings file. Leave blank to keep the current key."))
            if let credential {
                hint(credential["configured"].bool() == true
                     ? L.t("已配置密钥。", "A key is configured.")
                     : L.t("未配置密钥；仅使用 DeepSeek 账号模型的对话可以通过默认接口地址搜索。", "No key is configured; only conversations using a DeepSeek Account model can search, through the default endpoint."))
            }
            if let credentialError {
                Text(credentialError).font(.system(size: 12)).foregroundStyle(T.err)
                Button(L.t("重试", "Retry")) { Task { await loadCredential() } }.font(.system(size: 12)).disabled(saving)
            }
        }
    }

    private var modelSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("模型选择", "Model selection")).font(.system(size: 13, weight: .semibold))
            toggleRow(L.t("允许 Agent 为子智能体选择模型", "Allow agents to choose models for Subagents"), on: modelsEnabled, blocked: disabled) {
                stagedValues[modelsNS, default: [:]]["enabled"] = .bool(!modelsEnabled)
                error = nil
            }
            hint(modelsEnabled
                 ? L.t("开启后，Agent 可以从下方授权模型中，为每个子智能体选择提供方、模型和推理强度。仅影响新会话。", "When enabled, agents can choose a provider, model, and reasoning effort for each Subagent from the authorized models below. Applies only to new sessions.")
                 : L.t("关闭后，子智能体使用配置的默认模型或继承父 Agent 的模型；已选模型会保留。", "Subagents use configured defaults or inherit the parent agent's model. Saved model choices are retained."))
            if modelsEnabled {
                if catalogLoading { hint(L.t("正在加载模型…", "Loading models…")) }
                if let catalogError {
                    Text(catalogError).font(.system(size: 12)).foregroundStyle(T.err)
                    Button(L.t("重试", "Retry")) { Task { await loadCatalog() } }.font(.system(size: 12)).disabled(saving)
                }
                if catalog?.failures.isEmpty == false { hint(L.t("部分模型提供方暂时无法加载；已保存的选择仍可移除。", "Some model providers could not be loaded; saved choices remain removable.")) }
                modelChoices
                if routes.isEmpty { Text(L.t("保存前请至少选择一个模型。", "Select at least one model before saving.")).font(.system(size: 12)).foregroundStyle(T.err) }
            }
        }.padding(.vertical, 16)
    }

    private var modelChoices: some View {
        let groups = catalog?.groups ?? []
        let stored = snapshots[modelsNS]?["value"]["allowedModels"].arr() ?? []
        let unavailable = (stored + routes).reduce(into: [JSONValue]()) { result, route in
            if !result.contains(route), !groups.contains(where: { group in group.id == route["provider"].str() && group.models.contains(where: { $0.id == route["model"].str() }) }) { result.append(route) }
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(L.t("Agent 可选择的模型", "Models agents may choose")).font(.system(size: 12)).foregroundStyle(T.text2)
            if groups.allSatisfy({ $0.models.isEmpty }) && unavailable.isEmpty && catalog != nil {
                hint(L.t("当前没有模型提供方公布模型。", "No model provider currently advertises a model."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(groups) { group in
                            Text(group.name).font(.system(size: 11, weight: .medium)).foregroundStyle(T.text3)
                            ForEach(group.models) { entry in
                                modelRow(provider: group.id, providerName: group.name, modelID: entry.id, name: entry.name, available: true)
                            }
                        }
                        if !unavailable.isEmpty {
                            Text(L.t("已保存但当前不可用", "Saved but currently unavailable")).font(.system(size: 11)).foregroundStyle(T.text3)
                            ForEach(Array(unavailable.enumerated()), id: \.offset) { _, route in
                                modelRow(provider: route["provider"].str() ?? "", providerName: route["provider"].str() ?? "", modelID: route["model"].str() ?? "", name: route["model"].str() ?? "", available: false)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 280)
            }
        }.padding(10).overlay(RoundedRectangle(cornerRadius: 8).stroke(T.borderStrong, lineWidth: 0.5))
    }

    private func modelRow(provider: String, providerName: String, modelID: String, name: String, available: Bool) -> some View {
        let route = jsonObject(["provider": .string(provider), "model": .string(modelID)])
        let selected = routes.contains(route)
        return Button {
            var next = routes
            if selected { next.removeAll { $0 == route } } else { next.append(route) }
            stagedValues[modelsNS, default: [:]]["allowedModels"] = .array(next)
            error = nil
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.square.fill" : "square").foregroundStyle(selected ? T.accent : T.text3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 13)).foregroundStyle(T.ink)
                    Text("\(providerName) · \(provider)/\(modelID)").font(.system(size: 11)).foregroundStyle(T.text3)
                }
                Spacer(minLength: 0)
                if !available { Text(L.t("当前不可用", "Currently unavailable")).font(.system(size: 11)).foregroundStyle(T.text3) }
            }.padding(6).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(disabled).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func toggleRow(_ label: String, on: Bool, blocked: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label).font(.system(size: 13)).foregroundStyle(T.ink)
            Spacer(minLength: 0)
            PluginEnableSwitch(isOn: on, enabled: !blocked, label: label) { _ in action() }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(T.text3).fixedSize(horizontal: false, vertical: true)
    }

    private func value(_ ns: String, _ key: String) -> JSONValue {
        if let staged = stagedValues[ns]?[key] {
            return staged.isNull ? snapshots[ns]?["base"][key] ?? .null : staged
        }
        return snapshots[ns]?["value"][key] ?? .null
    }

    private func format(_ value: JSONValue) -> String {
        if let text = value.str() { return text }
        if let number = value.double() {
            let text = String(number)
            return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
        }
        return ""
    }

    private func operations(_ ns: String) -> [JSONValue] {
        var changes: [String: JSONValue] = [:]
        for field in fields where field.ns == ns {
            guard let draft = drafts[field.id] else { continue }
            if !draft.reset && draft.text == format(snapshots[ns]?["value"][field.key] ?? .null) { continue }
            guard let next = draft.reset ? JSONValue.null : field.parse(draft.text) else { continue }
            if !next.isNull && next == snapshots[ns]?["value"][field.key] { continue }
            if next.isNull && snapshots[ns]?["user"].obj()?[field.key] == nil { continue }
            changes[field.key] = next
        }
        for (key, next) in stagedValues[ns] ?? [:] {
            if ns == modelsNS && key == "allowedModels",
               let current = snapshots[ns]?["value"][key].arr(), let desired = next.arr(),
               current.count == desired.count && current.allSatisfy({ desired.contains($0) }) { continue }
            if next.isNull {
                if snapshots[ns]?["user"].obj()?[key] != nil { changes[key] = next }
            } else if next != snapshots[ns]?["value"][key] { changes[key] = next }
        }
        return changes.keys.sorted().map { key in
            let value = changes[key]!
            return value.isNull
                ? jsonObject(["op": .string("unset"), "path": .array([.string(key)])])
                : jsonObject(["op": .string("set"), "path": .array([.string(key)]), "value": value])
        }
    }

    @MainActor private func loadCatalog() async {
        guard !model.uiTestFixture else { return }
        guard model.ops.contains("models.catalog"), let client = model.clientOrNull() else {
            catalogError = L.t("无法加载模型：Host 未提供模型目录接口。", "Models could not be loaded: the Host does not provide the model catalog API.")
            return
        }
        catalogLoading = true
        defer { catalogLoading = false }
        do {
            let result = try await client.modelCatalog()
            try Task.checkCancellation()
            catalog = result
            catalogError = nil
        } catch is CancellationError { return }
        catch { catalogError = error.localizedDescription }
    }

    @MainActor private func loadCredential() async {
        credential = nil
        credentialError = nil
        let ref = credentialRef
        guard !model.uiTestFixture else { return }
        guard model.ops.contains("credentials.describe"), let client = model.clientOrNull() else {
            credentialError = L.t("Host 未提供密钥状态接口，无法读取或更改密钥。", "The Host does not provide credential status; the key cannot be read or changed.")
            return
        }
        do {
            let result = try await client.credentialsDescribe(ref: ref)
            try Task.checkCancellation()
            guard ref == credentialRef else { return }
            guard result["configured"].bool() != nil, result["writable"].bool() != nil else {
                throw PocketError(code: "invalid", message: L.t("Host 未返回密钥状态。", "The Host returned no credential status."))
            }
            credential = result
        } catch is CancellationError { return }
        catch { if ref == credentialRef { credentialError = error.localizedDescription } }
    }

    private func save() {
        guard !saving, !invalid, dirty, let client = model.clientOrNull() else { return }
        saving = true
        error = nil
        Task { @MainActor in
            defer { saving = false }
            do {
                // Endpoint settings land before the web provider selection, as on desktop.
                let order = item.id == "web-search" ? ["web-search-deepseek", "web-deepseek-api", "web"] : ["subagent", modelsNS, item.namespace]
                var saved: Set<String> = []
                for ns in order where !saved.contains(ns) {
                    saved.insert(ns)
                    let ops = operations(ns)
                    guard !ops.isEmpty else { continue }
                    guard writable, let revision = snapshots[ns]?["revision"].int() else {
                        throw PocketError(code: "readonly", message: L.t("本部署的设置为只读。", "This deployment stores settings read-only."))
                    }
                    try requireSettingsSuccess(try await client.pluginsSettingsMutate(ns: ns, ops: .array(ops), expectedRevision: revision))
                    let description = try await client.pluginsSettingsDescribe()
                    guard let written = description["namespaces"].arr()?.first(where: { $0["ns"].str() == ns }),
                          ops.allSatisfy({ op in
                              guard let key = op["path"].arr()?.first?.str() else { return false }
                              return op["op"].str() == "unset" ? written["user"].obj()?[key] == nil : written["value"][key] == op["value"]
                          }) else {
                        throw PocketError(code: "invalid", message: L.t("本部署没有接受这些值，已保留供你修改。", "The deployment did not accept these values; they were left for you to correct."))
                    }
                    snapshots[ns] = written
                    drafts = drafts.filter { !$0.key.hasPrefix(ns + ".") }
                    stagedValues[ns] = nil
                }
                let secret = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !secret.isEmpty {
                    guard credential?["writable"].bool() == true, model.ops.contains("credentials.set") else {
                        throw PocketError(code: "readonly", message: L.t("密钥为只读", "API key is read-only"))
                    }
                    try requireSettingsSuccess(try await client.credentialsSet(ref: credentialRef, value: secret))
                    await loadCredential()
                    guard credential?["configured"].bool() == true else {
                        throw PocketError(code: "invalid", message: credentialError ?? L.t("未能确认密钥已保存。", "The saved credential could not be confirmed."))
                    }
                    keyText = ""
                }
            } catch {
                self.error = settingsFailure(error, secret: keyText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}
