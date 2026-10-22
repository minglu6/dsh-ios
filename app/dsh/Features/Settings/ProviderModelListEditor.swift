import SwiftUI
import DSHProtocol

struct ProviderModelListEditor: View {
    @Binding var models: [JSONValue]
    let inheritedModels: [JSONValue]
    @Binding var overridden: Bool
    @Binding var touched: Bool
    let namespace: JSONValue?
    let provider: String?
    let declared: Bool
    let baseURL: String
    let api: String
    let apiKey: String
    let disabled: Bool
    @ObservedObject var model: AppModel
    var onBusy: (Bool) -> Void

    @State private var expanded = Set<Int>()
    @State private var editing: [String: String] = [:]
    @State private var fetching = false
    @State private var failure: String?
    @State private var catalog: [JSONValue] = []
    @State private var catalogLoaded = false
    @State private var candidates: [JSONValue]?
    @State private var selected = Set<String>()
    @State private var query = ""
    @State private var requestID = UUID()

    private var ns: String { namespace?["ns"].str() ?? "" }
    private var inputField: String { ns == "llm-deepseek" ? "inputModalities" : "input" }
    private var locked: Bool { disabled || fetching || candidates != nil }
    private var levels: [String] {
        declared && ns == "llm-pi-ai" ? providerModelReasoningLevels(namespace?["schema"]) : []
    }
    private var profile: JSONValue {
        if ns == "llm-deepseek" { return namespace?["value"] ?? .null }
        guard let provider else { return .null }
        return namespace?["value"]["providers"][provider] ?? .null
    }
    private var canFetch: Bool {
        !locked && model.isOnline && model.ops.contains("models.discover") && !ns.isEmpty
            && (provider != nil || !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && providerKeyFailure(apiKey) == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L.t("模型目录", "Models")).font(.system(size: 13, weight: .medium)).foregroundStyle(T.ink)
                    if provider != nil {
                        Text(overridden ? L.t("已自定义模型目录", "Customized model catalog") : L.t("正在使用适配器默认模型", "Using the adapter defaults"))
                            .font(.system(size: 12)).foregroundStyle(T.text3)
                            .accessibilityIdentifier("providerModels.ownership")
                    }
                }
                Spacer(minLength: 0)
                if overridden && provider != nil {
                    Button(L.t("恢复默认模型", "Restore defaults"), action: reset)
                        .font(.system(size: 12)).disabled(locked)
                        .accessibilityIdentifier("providerModels.reset")
                }
            }
            if ns == "llm-pi-ai" {
                Button(action: fetchModels) {
                    HStack(spacing: 6) {
                        if fetching { ProgressView().controlSize(.small) }
                        Text(fetching ? L.t("正在获取…", "Fetching…") : L.t("获取可用模型", "Fetch available models"))
                    }
                }
                .font(.system(size: 13)).disabled(!canFetch)
                .accessibilityIdentifier("providerModels.discover")
            }
            if models.isEmpty {
                Text(L.t("模型选择器中将不显示任何模型；目录外 ID 仍可直接发送。", "No models will be shown in the selector. Unlisted IDs can still be sent directly."))
                    .font(.caption).foregroundStyle(T.text3)
            }
            ForEach(models.indices, id: \.self) { index in
                modelRow(index)
            }
            Button {
                models.append(.object(["id": .string("")]))
                markChanged()
            } label: {
                HStack(spacing: 6) {
                    OfficialGlyph(kind: .plusOutline, size: 14, color: T.text2)
                    Text(L.t("添加模型", "Add model"))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 9)
            }
            .font(.subheadline).disabled(locked)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.borderL1, style: StrokeStyle(lineWidth: 1, dash: [4])))
            .accessibilityIdentifier("providerModels.add")
            if let failure { Text(failure).font(.caption).foregroundStyle(T.err).accessibilityIdentifier("providerModels.failure") }
        }
        .buttonStyle(.plain)
        .preference(key: ProviderModelPickerPreference.self, value: candidates == nil ? nil : ProviderModelPickerPresentation(content: AnyView(candidateDialog)))
        .task(id: "\(ns):\(provider ?? ""):" + String(declared)) { await loadCatalog() }
        .onDisappear {
            requestID = UUID()
            fetching = false
            candidates = nil
            onBusy(false)
        }
    }

    private func modelRow(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 8) {
                    textField(L.t("模型 ID", "Model ID"), text: textBinding(index, "id"), id: "providerModels.row.\(index).id")
                    textField(L.t("名称（可选）", "Name (optional)"), text: textBinding(index, "name"), id: "providerModels.row.\(index).name")
                }
                Button {
                    if !expanded.insert(index).inserted { expanded.remove(index) }
                } label: {
                    OfficialGlyph(kind: expanded.contains(index) ? .chevronUp : .chevronDown, size: 14, color: T.text2)
                        .frame(width: 28, height: 36)
                }
                .accessibilityLabel(L.t("模型选项", "Model options") + " \(index + 1)")
                .accessibilityIdentifier("providerModels.row.\(index).options")
                Button(role: .destructive) { remove(index) } label: {
                    OfficialGlyph(kind: .trashOutline, size: 14, color: T.text2).frame(width: 28, height: 36)
                }
                .accessibilityLabel(L.t("删除模型", "Delete model") + " \(index + 1)")
                .accessibilityIdentifier("providerModels.row.\(index).delete")
            }
            if expanded.contains(index) {
                capacityField(index, "contextWindow", title: L.t("上下文窗口", "Context window"), fallback: "256K")
                capacityField(index, "maxTokens", title: L.t("最大输出", "Max output"), fallback: "32K")
                inputTypes(index)
                if !levels.isEmpty { reasoningEditor(index) }
            }
        }
        .padding(10)
        .background(T.bg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.borderL1, lineWidth: 0.5))
        .disabled(locked)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("providerModels.row.\(index)")
    }

    private func textField(_ title: String, text: Binding<String>, id: String) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .font(.system(size: 13)).foregroundStyle(T.ink)
            .padding(9).background(T.surface2, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(T.borderL1, lineWidth: 0.5))
            .accessibilityLabel(title).accessibilityIdentifier(id)
    }

    private func textBinding(_ index: Int, _ field: String) -> Binding<String> {
        Binding(get: { value(index)[field].str() ?? "" }, set: { text in
            patch(index, field, text.isEmpty && field != "id" ? nil : .string(text))
        })
    }

    private func capacityField(_ index: Int, _ field: String, title: String, fallback: String) -> some View {
        let current = value(index)[field]
        let key = "\(index):\(field)"
        let binding = Binding<String>(get: {
            editing[key] ?? providerModelCapacitySpelling(current)
        }, set: { text in
            editing[key] = text
            patch(index, field, providerModelCapacityValue(text))
        })
        let placeholder = providerModelCapacitySpelling(profile[field == "contextWindow" ? "defaultContextWindow" : field])
        return VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(T.text3)
            textField(placeholder.isEmpty ? fallback : placeholder, text: binding, id: "providerModels.row.\(index).\(field)")
                .accessibilityLabel(title + " \(index + 1)")
            if !current.isNull && !providerModelCapacityValid(current) {
                Text(L.t("请输入正整数，可使用 K / M（例如 256K、1M）", "Enter a positive whole number, optionally using K / M (256K, 1M)"))
                    .font(.caption).foregroundStyle(T.err)
            }
        }
    }

    private func inputTypes(_ index: Int) -> some View {
        let chosen = inputs(index)
        return VStack(alignment: .leading, spacing: 6) {
            Text(L.t("输入类型", "Input types")).font(.caption).foregroundStyle(T.text3)
            if !declared && ns == "llm-pi-ai" && !catalogLoaded {
                Text(L.t("正在读取目录能力…", "Loading catalog capabilities…")).font(.caption).foregroundStyle(T.text3)
            }
            HStack(spacing: 16) {
                ForEach(["text", "image"], id: \.self) { input in
                    Button {
                        var next = chosen
                        if let at = next.firstIndex(of: input) { next.remove(at: at) } else { next.append(input) }
                        guard !next.isEmpty else { return }
                        var row = value(index).obj() ?? [:]
                        row[inputField] = .array(next.map(JSONValue.string))
                        if inputField == "inputModalities" && !next.contains("image") {
                            row.removeValue(forKey: "imagePixelBudget")
                            row.removeValue(forKey: "imageMaxBytes")
                        }
                        replace(index, .object(row))
                    } label: {
                        Label(input == "text" ? L.t("文本", "Text") : L.t("图片", "Image"), systemImage: chosen.contains(input) ? "checkmark.square.fill" : "square")
                            .font(.subheadline).foregroundStyle(chosen.contains(input) ? T.accent : T.text3)
                    }
                    .disabled((chosen.count == 1 && chosen.contains(input)) || (!declared && ns == "llm-pi-ai" && !catalogLoaded))
                    .accessibilityValue(chosen.contains(input) ? L.t("已选择", "Selected") : L.t("未选择", "Not selected"))
                    .accessibilityIdentifier("providerModels.row.\(index).input.\(input)")
                }
            }
        }
    }

    private func inputs(_ index: Int) -> [String] {
        let row = value(index)
        if let own = row[inputField].arr(), !own.isEmpty { return own.compactMap { $0.str() } }
        if let inherited = catalog.first(where: { $0["id"] == row["id"] })?["inputModalities"].arr(), !inherited.isEmpty {
            return inherited.compactMap { $0.str() }
        }
        let fallback = profile["defaultInput"].arr()?.compactMap { $0.str() } ?? []
        return fallback.isEmpty ? ["text"] : fallback
    }

    private func reasoningEditor(_ index: Int) -> some View {
        let raw = value(index).obj()?["reasoningEfforts"]
        let enabled = raw?.obj() != nil || raw == .null
        let entries = raw?.obj() ?? [:]
        let ordered = levels.filter { entries[$0] != nil } + entries.keys.filter { !levels.contains($0) }.sorted()
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(L.t("推理等级", "Reasoning levels"), isOn: Binding(get: { enabled }, set: { on in
                editing = editing.filter { !$0.key.hasPrefix("\(index):reasoning:") }
                let initial = levels.filter { ["off", "low", "medium", "high"].contains($0) }
                patch(index, "reasoningEfforts", on ? .object(Dictionary(uniqueKeysWithValues: initial.map { ($0, effortDefault($0)) })) : nil)
            }))
            .font(.subheadline).toggleStyle(.switch).tint(T.accent)
            .accessibilityIdentifier("providerModels.row.\(index).reasoning")
            if enabled {
                Text(L.t("API 参数值默认与档位名相同；如有不同，以提供商 API 文档为准。Off 关闭思考，不需要参数值；配置中已有的值会保留。", "API values default to the level name; follow the provider's API documentation when different. Off disables reasoning and needs no value; existing configured values are preserved."))
                    .font(.caption).foregroundStyle(T.text3)
                ForEach(ordered, id: \.self) { level in
                    reasoningRow(index, level: level, entries: entries)
                }
                if let error = providerModelReasoningFailure(value(index)) {
                    Text(error).font(.caption).foregroundStyle(T.err)
                }
                Button {
                    let highest = levels.indices.filter { entries[levels[$0]] != nil }.max() ?? -1
                    let next = levels.enumerated().first { $0.offset > highest && entries[$0.element] == nil }?.element
                        ?? levels.first { entries[$0] == nil }
                    guard let next else { return }
                    var updated = entries
                    updated[next] = effortDefault(next)
                    patch(index, "reasoningEfforts", .object(updated))
                } label: { Label(L.t("添加档位", "Add level"), systemImage: "plus") }
                    .font(.caption).disabled(levels.allSatisfy { entries[$0] != nil })
                    .accessibilityIdentifier("providerModels.row.\(index).reasoning.add")
            }
        }
    }

    private func reasoningRow(_ index: Int, level: String, entries: [String: JSONValue]) -> some View {
        let wire = entries[level] ?? .null
        let key = "\(index):reasoning:\(level)"
        let choices = (levels.contains(level) ? [] : [level]) + levels.filter { $0 == level || entries[$0] == nil }
        return HStack(spacing: 8) {
            Menu {
                ForEach(choices, id: \.self) { choice in
                    Button(choice) {
                        var next = entries
                        next.removeValue(forKey: level)
                        let text = wire.str() ?? ""
                        let carry = !text.isEmpty && text != level && level != "off" && choice != "off"
                        next[choice] = carry ? wire : effortDefault(choice)
                        editing.removeValue(forKey: key)
                        patch(index, "reasoningEfforts", .object(next))
                    }
                }
            } label: {
                HStack(spacing: 4) { Text(level); Image(systemName: "chevron.down").font(.caption2) }
                    .font(.system(size: 12, design: .monospaced)).padding(8)
                    .background(T.surface2, in: RoundedRectangle(cornerRadius: 7))
            }
            .accessibilityLabel(L.t("档位", "Level"))
            .accessibilityIdentifier("providerModels.row.\(index).reasoning.\(level).level")
            TextField(level == "off" ? L.t("关闭思考", "Turns reasoning off") : level, text: Binding(get: {
                editing[key] ?? wire.str() ?? ""
            }, set: { text in
                editing[key] = text
                var next = entries
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                next[level] = trimmed.isEmpty ? effortDefault(level) : .string(trimmed)
                patch(index, "reasoningEfforts", .object(next))
            }), onEditingChanged: { active in
                if !active { editing.removeValue(forKey: key) }
            })
            .textInputAutocapitalization(.never).autocorrectionDisabled().font(.system(size: 12, design: .monospaced))
            .padding(8).background(T.surface2, in: RoundedRectangle(cornerRadius: 7))
            .disabled(level == "off")
            .accessibilityLabel(L.t("API 参数值", "API value") + " \(level)")
            .accessibilityIdentifier("providerModels.row.\(index).reasoning.\(level).value")
            Button(role: .destructive) {
                var next = entries
                next.removeValue(forKey: level)
                editing.removeValue(forKey: key)
                patch(index, "reasoningEfforts", .object(next))
            } label: { Image(systemName: "trash").frame(width: 30, height: 36) }
                .accessibilityLabel(L.t("删除档位", "Delete level") + " \(level)")
                .accessibilityIdentifier("providerModels.row.\(index).reasoning.\(level).delete")
        }
    }

    private func effortDefault(_ level: String) -> JSONValue { level == "off" ? .null : .string(level) }
    private func value(_ index: Int) -> JSONValue { models.indices.contains(index) ? models[index] : .null }
    private func markChanged() { overridden = true; touched = true }
    private func replace(_ index: Int, _ row: JSONValue) {
        guard models.indices.contains(index) else { return }
        models[index] = row
        markChanged()
    }
    private func patch(_ index: Int, _ field: String, _ value: JSONValue?) {
        var row = self.value(index).obj() ?? [:]
        row[field] = value
        replace(index, .object(row))
    }
    private func remove(_ index: Int) {
        guard models.indices.contains(index) else { return }
        models.remove(at: index)
        expanded = Set(expanded.compactMap { $0 == index ? nil : ($0 > index ? $0 - 1 : $0) })
        var shifted: [String: String] = [:]
        for (key, text) in editing {
            guard let colon = key.firstIndex(of: ":"), let row = Int(key[..<colon]), row != index else { continue }
            shifted["\(row > index ? row - 1 : row)" + key[colon...]] = text
        }
        editing = shifted
        markChanged()
    }
    private func reset() {
        editing = [:]
        expanded = []
        models = inheritedModels
        overridden = false
        touched = true
        failure = nil
    }

    private func loadCatalog() async {
        catalog = []
        catalogLoaded = false
        guard !declared, ns == "llm-pi-ai", let provider, model.isOnline,
              model.ops.contains("models.discover"), let client = model.clientOrNull() else {
            catalogLoaded = true
            return
        }
        do {
            let result = try await client.modelsDiscover(settingsNs: ns, request: .object(["provider": .string(provider)]))
            guard !Task.isCancelled else { return }
            guard let found = result["models"].arr() else {
                throw PocketError(code: "discovery", message: L.t("主机未返回模型目录", "The host did not return a model catalog"))
            }
            catalog = found
        } catch {
            guard !Task.isCancelled else { return }
            failure = settingsFailure(error, secret: apiKey)
        }
        catalogLoaded = true
    }

    private func fetchModels() {
        guard canFetch, let client = model.clientOrNull() else { return }
        fetching = true
        onBusy(true)
        failure = nil
        let token = UUID()
        requestID = token
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var request: [String: JSONValue] = [:]
        if let provider { request["provider"] = .string(provider) }
        let endpoint = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !endpoint.isEmpty { request["baseURL"] = .string(endpoint) }
        if !api.isEmpty { request["api"] = .string(api) }
        if !key.isEmpty { request["apiKey"] = .string(key) }
        let settingsNs = ns
        Task {
            do {
                let answer = try await client.modelsDiscover(settingsNs: settingsNs, request: .object(request))
                guard requestID == token else { return }
                guard let found = answer["models"].arr() else {
                    throw PocketError(code: "discovery", message: answer["message"].str() ?? L.t("主机未返回模型目录", "The host did not return a model catalog"))
                }
                var ids = Set<String>()
                let unique = found.filter { row in
                    guard let id = row["id"].str(), !id.isEmpty else { return false }
                    return ids.insert(id).inserted
                }
                if !declared { catalog = unique; catalogLoaded = true }
                if unique.isEmpty { failure = L.t("未找到可用模型，可手动添加。", "No models found. You can still add models manually.") }
                else {
                    let known = Set(models.compactMap { $0["id"].str() })
                    selected = Set(unique.compactMap { $0["id"].str() }.filter { !known.contains($0) })
                    query = ""
                    candidates = unique
                }
            } catch {
                guard requestID == token else { return }
                failure = settingsFailure(error, secret: key)
            }
            guard requestID == token else { return }
            fetching = false
            onBusy(candidates != nil)
        }
    }

    private var visibleCandidates: [JSONValue] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (candidates ?? []).filter { needle.isEmpty || ($0["id"].str() ?? "").localizedCaseInsensitiveContains(needle) || ($0["name"].str() ?? "").localizedCaseInsensitiveContains(needle) }
    }

    private var candidateDialog: some View {
        GeometryReader { geometry in
            ZStack {
                T.scrim.ignoresSafeArea().onTapGesture(perform: closePicker)
                ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(L.t("可用模型", "Available models")).font(.headline).foregroundStyle(T.ink)
                        Spacer()
                        Button(action: closePicker) {
                            OfficialGlyph(kind: .closeOutline, size: 16, color: T.text2).frame(width: 32, height: 32)
                        }
                            .accessibilityLabel(L.close()).accessibilityIdentifier("providerModels.picker.close")
                    }
                    Text(L.t("选择要添加的模型。已有模型及其自定义设置不会被覆盖。", "Choose models to add. Existing models and their custom settings will not be overwritten."))
                        .font(.caption).foregroundStyle(T.text3)
                    textField(L.t("搜索模型", "Search models"), text: $query, id: "providerModels.picker.search")
                    Button {
                        let ids = Set(visibleCandidates.compactMap { $0["id"].str() })
                        if ids.isSubset(of: selected) { selected.subtract(ids) } else { selected.formUnion(ids) }
                    } label: {
                        Text(Set(visibleCandidates.compactMap { $0["id"].str() }).isSubset(of: selected)
                             ? L.t("取消全选", "Deselect all") : L.t("全选", "Select all"))
                    }
                    .font(.subheadline).disabled(visibleCandidates.isEmpty).accessibilityIdentifier("providerModels.picker.selectAll")
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if visibleCandidates.isEmpty { Text(L.t("没有匹配的模型", "No matching models")).font(.caption).foregroundStyle(T.text3).padding(.vertical, 12) }
                            ForEach(visibleCandidates, id: \.providerModelID) { candidate in
                                let id = candidate["id"].str() ?? ""
                                Button {
                                    if !selected.insert(id).inserted { selected.remove(id) }
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: selected.contains(id) ? "checkmark.square.fill" : "square").foregroundStyle(T.accent)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(id).font(.system(size: 13, design: .monospaced)).foregroundStyle(T.ink).multilineTextAlignment(.leading)
                                            if let name = candidate["name"].str(), name != id { Text(name).font(.caption).foregroundStyle(T.text3) }
                                        }
                                        Spacer(minLength: 0)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10).contentShape(Rectangle())
                                }
                                .accessibilityValue(selected.contains(id) ? L.t("已选择", "Selected") : L.t("未选择", "Not selected"))
                                .accessibilityIdentifier("providerModels.picker.candidate.\(id)")
                            }
                        }
                    }
                    .frame(height: max(90, min(360, geometry.size.height - 280)))
                    HStack {
                        Spacer()
                        Button(L.cancel(), action: closePicker).accessibilityIdentifier("providerModels.picker.cancel")
                        Button(L.t("添加所选模型", "Add selected models"), action: adoptSelected)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(T.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityIdentifier("providerModels.picker.adopt")
                    }.font(.subheadline)
                }
                }
                .frame(maxHeight: max(0, min(600, geometry.size.height - 72)))
                .padding(20).frame(width: max(0, min(520, geometry.size.width - 32)))
                .background(T.surface2, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(T.borderL1, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.16), radius: 24, y: 8)
                .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
                .accessibilityIdentifier("providerModels.picker")
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.buttonStyle(.plain)
    }

    private func closePicker() {
        candidates = nil
        selected = []
        query = ""
        onBusy(false)
    }

    private func adoptSelected() {
        var known = Set(models.compactMap { $0["id"].str() })
        for candidate in candidates ?? [] {
            guard let id = candidate["id"].str(), selected.contains(id), known.insert(id).inserted else { continue }
            var row: [String: JSONValue] = ["id": .string(id)]
            for field in ["name", "contextWindow", "maxTokens"] where !candidate[field].isNull { row[field] = candidate[field] }
            if let input = candidate["inputModalities"].arr() { row[inputField] = .array(input) }
            models.append(.object(row))
        }
        markChanged()
        closePicker()
    }
}

private extension JSONValue {
    var providerModelID: String { self["id"].str() ?? "" }
}

private struct ProviderModelPickerPresentation {
    let content: AnyView
}

private struct ProviderModelPickerPreference: PreferenceKey {
    static var defaultValue: ProviderModelPickerPresentation? { nil }
    static func reduce(value: inout ProviderModelPickerPresentation?, nextValue: () -> ProviderModelPickerPresentation?) {
        value = nextValue() ?? value
    }
}

extension View {
    func providerModelPickerOverlay() -> some View {
        overlayPreferenceValue(ProviderModelPickerPreference.self) { presentation in
            if let presentation { presentation.content }
        }
    }
}

// Invalid text remains JSON text in the draft so saving cannot silently use an older count.
func providerModelCapacityValue(_ text: String) -> JSONValue? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed.range(of: #"^\d+(?:\.\d+)?[kKmM]?$"#, options: .regularExpression) != nil else { return .string(text) }
    let suffix = trimmed.last?.lowercased()
    let scaled = suffix == "k" || suffix == "m"
    let digits = scaled ? String(trimmed.dropLast()) : trimmed
    guard let number = Double(digits) else { return .string(text) }
    let count = number * (suffix == "k" ? 1_000 : suffix == "m" ? 1_000_000 : 1)
    let rounded = count.rounded()
    let result = abs(count - rounded) < 0.000001 ? rounded : count
    guard result.isFinite, result > 0, result.rounded() == result, result <= 9_007_199_254_740_991 else { return .string(text) }
    return .number(result)
}

func providerModelCapacitySpelling(_ value: JSONValue) -> String {
    guard let count = value.double() else { return value.str() ?? "" }
    guard count.isFinite else { return String(count) }
    if count > 0, count.rounded() == count {
        if count.truncatingRemainder(dividingBy: 1_000_000) == 0 { return String(format: "%.0fM", count / 1_000_000) }
        if count.truncatingRemainder(dividingBy: 1_000) == 0 { return String(format: "%.0fK", count / 1_000) }
        return String(format: "%.0f", count)
    }
    return String(count)
}

private func providerModelCapacityValid(_ value: JSONValue) -> Bool {
    guard let count = value.double() else { return false }
    return count.isFinite && count > 0 && count.rounded() == count && count <= 9_007_199_254_740_991
}

private func providerModelReasoningFailure(_ model: JSONValue) -> String? {
    guard let raw = model.obj()?["reasoningEfforts"] else { return nil }
    guard raw.obj() != nil || raw.isNull else { return nil }
    let entries = raw.obj() ?? [:]
    if entries.contains(where: { level, value in
        if let text = value.str() { return text.isEmpty }
        return !(level == "off" && value.isNull)
    }) {
        return L.t("Off 以外的档位都需要填写 API 参数值，且参数值不能为空字符串。", "Every level besides Off needs an API value, and no value can be empty.")
    }
    return entries.keys.contains(where: { $0 != "off" }) ? nil : L.t("至少添加一个 Off 以外的档位；不需要思考请关闭推理等级。", "Add at least one level besides Off, or turn reasoning levels off.")
}

func providerModelListFailure(_ models: [JSONValue]) -> String? {
    for (index, row) in models.enumerated() {
        for field in ["contextWindow", "maxTokens"] where row.obj()?[field] != nil {
            if !providerModelCapacityValid(row[field]) { return "Model \(index + 1): \(field) — " + L.t("请输入正整数，可使用 K / M", "Enter a positive whole number, optionally using K / M") }
        }
    }
    if let failure = validateProviderModels(models) { return failure }
    for (index, row) in models.enumerated() {
        if let failure = providerModelReasoningFailure(row) { return "Model \(index + 1): \(failure)" }
    }
    return nil
}

func providerModelReasoningLevels(_ envelope: JSONValue?) -> [String] {
    let refs = envelope?["refs"].obj() ?? [:]
    func resolve(_ value: JSONValue) -> JSONValue {
        if let id = value.refId(), let node = refs[id] { return node }
        return value
    }
    func at(_ raw: JSONValue, _ path: ArraySlice<String>, _ depth: Int) -> [JSONValue] {
        guard depth < 64 else { return [] }
        let node = resolve(raw)
        guard let key = path.first else { return [node] }
        switch node["type"].str() {
        case "object": return at(node["dict"][key], path.dropFirst(), depth + 1)
        case "dict", "array": return at(node["inner"], path.dropFirst(), depth + 1)
        case "union", "intersect": return (node["list"].arr() ?? []).flatMap { at($0, path, depth + 1) }
        default: return []
        }
    }
    func keys(_ raw: JSONValue, _ depth: Int) -> [String] {
        guard depth < 64 else { return [] }
        let node = resolve(raw)
        if node["type"].str() == "dict" {
            return (resolve(node["sKey"])["list"].arr() ?? []).compactMap { resolve($0)["value"].str() }
        }
        return (node["list"].arr() ?? []).flatMap { keys($0, depth + 1) }
    }
    let path = ["providers", "__probe__", "models", "0", "reasoningEfforts"]
    var seen = Set<String>()
    return at(envelope ?? .null, path[...], 0).flatMap { keys($0, 0) }.filter { seen.insert($0).inserted }
}
