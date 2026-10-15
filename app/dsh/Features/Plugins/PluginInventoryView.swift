import SwiftUI
import DSHProtocol

struct PluginInventoryView: View {
    @ObservedObject var model: AppModel
    @State private var entries: [JSONValue] = []
    @State private var presets: [JSONValue] = []
    @State private var query = ""
    @State private var selected: JSONValue?
    @State private var error: String?
    @State private var loading = true
    @State private var selectedPreset: String?

    var body: some View {
        VStack(spacing: 0) {
            header(L.builtinPluginsNav()) { model.pop() }
            if let error {
                Text(error).foregroundStyle(T.err).padding()
                Button(L.retry()) { Task { await load() } }
            } else if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(T.text3)
                    TextField(L.search(), text: $query)
                        .textInputAutocapitalization(.never)
                }
                .padding(10)
                .background(T.fill, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                List {
                    ForEach(Array(visible.enumerated()), id: \.offset) { _, row in
                        Button { selected = row } label: {
                            HStack(spacing: 12) {
                                PluginMetadataArtwork(icon: row["meta"]["icon"].str())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(inventoryTitle(row, english: L.en)).foregroundStyle(T.ink)
                                    Text(stateLabel(row)).font(.caption).foregroundStyle(T.text3)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            if let selected { inventoryDetail(selected) }
        }
        .task { await load() }
        .onChange(of: model.pluginCatalogRevision) { _ in Task { await load() } }
    }

    private var visible: [JSONValue] {
        entries.filter { inventoryMatches($0, query: query, english: L.en) }
    }

    private func stateLabel(_ row: JSONValue) -> String {
        let via = !inventoryProviders(entry: row, presets: presets).isEmpty
        switch inventoryEnablement(row, viaPresets: via) {
        case "failed": return L.t("启动失败", "Failed to start")
        case "preset": return L.t("预设中启用", "Via presets")
        case "conditional": return L.t("条件启用", "Conditional")
        case "enabled": return L.t("已启用", "Enabled")
        default: return L.t("已停用", "Disabled")
        }
    }

    @ViewBuilder
    private func inventoryDetail(_ row: JSONValue) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PluginMetadataArtwork(icon: row["meta"]["icon"].str(), size: 48)
                    Text(inventoryTitle(row, english: L.en)).font(.headline).foregroundStyle(T.ink)
                    if let description = pluginLocalized(row["meta"]["description"], english: L.en) {
                        Text(description).foregroundStyle(T.text2)
                    }
                    Text(stateLabel(row)).foregroundStyle(T.text3)
                    if let phase = row["fiberPhase"].str() {
                        Text(phase).font(.caption).foregroundStyle(T.text3)
                    }
                }
                .padding(20)
            }
            .navigationTitle(L.builtinPluginsNav())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.close()) { selected = nil } } }
        }
    }

    private func load() async {
        guard model.ops.contains("plugins.inventory") else {
            loading = false
            return
        }
        loading = true
        do {
            let result = try await model.clientOrNull()?.pluginsInventory() ?? .null
            entries = result["entries"].arr() ?? result["plugins"].arr() ?? result["items"].arr() ?? []
            presets = result["presets"].arr() ?? []
            selectedPreset = inventorySelectedPreset(presets, selectedId: selectedPreset)?["id"].str()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
