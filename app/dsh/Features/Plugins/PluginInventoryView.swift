import SwiftUI
import DSHProtocol

struct PluginInventoryView: View {
    @ObservedObject var model: AppModel
    @State private var snapshot: JSONValue?
    @State private var query = ""
    @State private var selectedId: String?
    @State private var presetOpen = true
    @State private var globalOpen = false
    @State private var expanded: String?
    @State private var error: String?
    @State private var loading = true
    @State private var refresh = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.pop() } label: { OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink) }
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isButton)
                Text(L.builtinPluginsNav()).font(.headline).foregroundStyle(T.ink)
                Spacer()
                Button { refresh += 1 } label: {
                    OfficialGlyph(kind: .refreshOutline, size: 16, color: T.text2)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .disabled(!model.isOnline || loading || !model.ops.contains("plugins.inventory"))
                .accessibilityLabel(L.refresh())
                .accessibilityIdentifier(builtinPluginRefreshSymbol())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(T.surface)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    settingsMessage(L.t("查看内置部署的插件列表", "View plugins in the built-in deployment"))
                    if model.isOnline && !model.ops.contains("plugins.inventory") {
                        settingsMessage(L.t("远程主机未提供内置插件目录，请检查远程主机插件是否已加载。", "The remote host does not provide a built-in plugin inventory. Check that its plugin is loaded."), error: true)
                    }
                    if let error { settingsMessage(error, error: true) }
                    if loading { ProgressView().frame(maxWidth: .infinity).padding() }
                    if let snapshot { content(snapshot) }
                }
                .padding(.bottom, 24)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        .task(id: "\(model.activeId ?? "")-\(model.isOnline)-\(model.pluginCatalogRevision)-\(refresh)-\(model.ops.contains("plugins.inventory"))") {
            await load()
        }
    }

    @ViewBuilder
    private func content(_ snapshot: JSONValue) -> some View {
        let english = L.en
        let presets = snapshot["agentPresets"].arr() ?? []
        let entries = snapshot["entries"].arr() ?? []
        let selected = inventorySelectedPreset(presets, selectedId: selectedId)
        let searching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let globalRows = entries.filter { inventoryMatches($0, query: query, english: english) }
            .sorted { ($0["fiberPhase"].str() == "failed" ? 0 : 1) < ($1["fiberPhase"].str() == "failed" ? 0 : 1) }
        let selectedRows = selected?["rows"].arr() ?? []
        let otherMatches = searching
            ? presets.filter { preset in
                preset["id"].str() != selected?["id"].str()
                    && (preset["rows"].arr() ?? []).contains { inventoryMatches($0, query: query, english: english) }
            }
            : []

        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(T.text3)
            TextField(L.t("搜索插件", "Search plugins"), text: $query)
                .textInputAutocapitalization(.never)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(T.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.borderStrong, lineWidth: 0.5))
        .padding(.horizontal, 18)
        .padding(.top, 8)

        if entries.isEmpty && presets.isEmpty {
            settingsMessage(L.t("暂无插件。", "No plugins are available."))
        }
        if searching && globalRows.isEmpty && !selectedRows.contains(where: { inventoryMatches($0, query: query, english: english) }) && otherMatches.isEmpty {
            settingsMessage(L.t("没有匹配的插件。", "No matching plugins."))
        }
        if let selected {
            let rows = selectedRows.filter { inventoryMatches($0, query: query, english: english) }
            inventoryGroup(
                L.t("会话插件", "Session plugins"),
                L.t("由 Agent 预设按会话组成", "Composed per session by agent presets"),
                rows.count,
                presetOpen || searching,
                { presetOpen.toggle() }
            ) {
                Menu {
                    ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                        Button {
                            selectedId = preset["id"].str()
                        } label: {
                            if preset["id"].str() == selected["id"].str() {
                                Label(presetLabel(preset), systemImage: "checkmark")
                            } else {
                                Text(presetLabel(preset))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(presetLabel(selected)).foregroundStyle(T.ink).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 12)).foregroundStyle(T.ink)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(T.fill2, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel(L.t("选择要查看的 Agent 预设", "Choose the agent preset to inspect"))
            }
            if presetOpen || searching {
                if let broken = selected["broken"].str() { settingsMessage(broken, error: true) }
                ForEach(Array(selectedRows.enumerated()), id: \.offset) { index, row in
                    if inventoryMatches(row, query: query, english: english) {
                        let rowKey = "preset:\(selected["id"].str() ?? ""):\(index)"
                        inventoryRow(row, english: english, expanded: expanded == rowKey, preset: selected) {
                            expanded = expanded == rowKey ? nil : rowKey
                        }
                    }
                }
                if !otherMatches.isEmpty {
                    settingsMessage(L.t("其他预设中也有匹配的插件：", "Matching plugins in other presets:"))
                    ForEach(Array(otherMatches.enumerated()), id: \.offset) { _, preset in
                        Button(PresetPolicy.name(preset, english: english)) { selectedId = preset["id"].str() }
                            .padding(.horizontal, 18)
                    }
                }
            }
        }
        if !entries.isEmpty {
            inventoryGroup(
                L.t("全局插件", "Global plugins"),
                L.t("系统与所有会话共用", "Shared by the system and every session"),
                globalRows.count,
                globalOpen || searching,
                { globalOpen.toggle() }
            )
            if globalOpen || searching {
                ForEach(Array(globalRows.enumerated()), id: \.offset) { _, row in
                    let rowKey = "global:\(row["entryId"].str() ?? "")"
                    let providers = inventoryProviders(entry: row, presets: presets)
                    inventoryRow(row, english: english, expanded: expanded == rowKey, providers: providers, onPreset: { selectedId = $0["id"].str(); presetOpen = true }) {
                        expanded = expanded == rowKey ? nil : rowKey
                    }
                }
            }
        }
    }

    private func presetLabel(_ preset: JSONValue) -> String {
        let name = PresetPolicy.name(preset, english: L.en)
        if preset["broken"].str() != nil { return name + L.t("（加载失败）", " (failed to load)") }
        if preset["isDefault"].bool() == true { return name + L.t("（默认）", " (default)") }
        return name
    }

    @ViewBuilder
    private func inventoryGroup(
        _ title: String,
        _ subtitle: String,
        _ count: Int,
        _ open: Bool,
        _ toggle: @escaping () -> Void
    ) -> some View {
        inventoryGroup(title, subtitle, count, open, toggle) { EmptyView() }
    }

    @ViewBuilder
    private func inventoryGroup<Action: View>(
        _ title: String,
        _ subtitle: String,
        _ count: Int,
        _ open: Bool,
        _ toggle: @escaping () -> Void,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button(action: toggle) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .rotationEffect(.degrees(open ? 0 : -90))
                            .foregroundStyle(T.ink)
                        Text(title).foregroundStyle(T.ink).font(.system(size: 14))
                    }
                    .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(open ? L.t("收起", "Collapse") : L.t("展开", "Expand"))
                action()
            }
            Text("\(subtitle) · \(count) \(L.t("个", "plugins"))")
                .font(.system(size: 12))
                .foregroundStyle(T.text3)
                .padding(.leading, 20)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func inventoryRow(
        _ row: JSONValue,
        english: Bool,
        expanded: Bool,
        preset: JSONValue? = nil,
        providers: [JSONValue] = [],
        onPreset: ((JSONValue) -> Void)? = nil,
        onToggle: @escaping () -> Void
    ) -> some View {
        let state = inventoryEnablement(row, viaPresets: !providers.isEmpty)
        let title = inventoryTitle(row, english: english)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(T.ink).lineLimit(1)
                        Spacer()
                        if row["enabled"].bool() == true {
                            switch row["fiberPhase"].str() {
                            case "pending":
                                Circle().fill(T.text3).frame(width: 5, height: 5)
                            case "loading", "unloading":
                                ProgressView().controlSize(.mini)
                            default:
                                EmptyView()
                            }
                        }
                        if state != "enabled" {
                            Text(stateLabel(state))
                                .font(.system(size: 11))
                                .foregroundStyle(stateColor(state))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((state == "disabled" ? T.fill2 : stateColor(state).opacity(0.08)), in: RoundedRectangle(cornerRadius: 4))
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .foregroundStyle(T.text3)
                    }
                    if let description = pluginLocalized(row["meta"]["description"], english: english), !description.isEmpty {
                        Text(description).font(.system(size: 12)).foregroundStyle(T.text3).lineLimit(expanded ? nil : 2)
                    }
                    if let entry = row["entryId"].str()?.replacingOccurrences(of: "include:", with: "", options: [.anchored]), entry != title {
                        Text(entry)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(T.text2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(T.fill2, in: RoundedRectangle(cornerRadius: 4))
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            if let metaError = row["meta"]["error"].str() {
                settingsMessage(L.t("包元信息错误：", "Package metadata error: ") + metaError, error: true)
            }
            if expanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    if let entry = row["entryId"].str() {
                        Text(entry).font(.system(size: 12, design: .monospaced)).foregroundStyle(T.ink)
                    }
                    fact(L.t("完整名称", "Module"), row["moduleName"].str() ?? "")
                    if let preset { fact(L.t("来自", "From"), PresetPolicy.name(preset, english: english)) }
                    fact(
                        L.t("配置状态", "Configuration"),
                        providers.isEmpty
                            ? stateLabel(state)
                            : L.t("全局已停用，由 Agent 预设按会话提供", "Disabled globally; agent presets provide it per session")
                    )
                    let showRuntime = preset != nil ? row["fiberPhase"].str() != nil : (providers.isEmpty && row["enabled"].bool() == true)
                    if showRuntime { fact(L.t("运行状态", "Status"), phaseLabel(row)) }
                    if let condition = row["condition"].str() { fact(L.t("禁用条件", "Disabled when"), condition) }
                    if !providers.isEmpty {
                        fact(L.t("启用于", "Enabled in"), providers.map { PresetPolicy.name($0, english: english) }.joined(separator: " · "))
                    }
                }
                .padding(14)
                if !providers.isEmpty, let first = providers.first, let onPreset {
                    Button(L.t("去预设分组查看", "View in the preset group")) { onPreset(first) }
                        .padding(.horizontal, 8)
                }
            }
        }
        .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label).foregroundStyle(T.text3).font(.system(size: 12)).frame(width: 76, alignment: .leading)
            Text(value).foregroundStyle(T.ink).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stateLabel(_ state: String) -> String {
        switch state {
        case "failed": return L.t("启动失败", "Failed to start")
        case "preset": return L.t("预设中启用", "Via presets")
        case "conditional": return L.t("条件启用", "Conditional")
        case "enabled": return L.t("已启用", "Enabled")
        default: return L.t("已停用", "Disabled")
        }
    }

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "failed": return T.err
        case "conditional": return T.warnText
        case "preset": return T.accent
        default: return T.text2
        }
    }

    private func phaseLabel(_ row: JSONValue) -> String {
        switch row["fiberPhase"].str() {
        case "active": return L.t("运行中", "Running")
        case "pending": return L.t("等待依赖", "Waiting for dependencies")
        case "loading": return L.t("加载中", "Loading")
        case "unloading": return L.t("卸载中", "Unloading")
        case "failed": return L.t("启动失败", "Failed to start")
        default: return L.t("未运行", "Not running")
        }
    }

    private func load() async {
        guard model.isOnline, model.ops.contains("plugins.inventory") else {
            loading = false
            return
        }
        loading = true
        error = nil
        do {
            snapshot = try await model.clientOrNull()?.pluginsInventory()
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription.isEmpty ? L.t("读取插件列表失败", "Could not load plugin inventory") : error.localizedDescription
        }
        loading = false
    }
}
