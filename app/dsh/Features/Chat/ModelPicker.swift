import SwiftUI
import DSHProtocol

enum ModelPane { case root, models, effort }

struct ModelPicker: View {
    let catalog: ModelCatalog?
    let current: ModelChoice?
    var loading: Bool = false
    var error: String? = nil
    var pending: ModelChoice? = nil
    var enabled: Bool = true
    var openModels: Bool = false
    var onReload: () -> Void = {}
    var onDismiss: () -> Void
    var onPick: (ModelChoice, @escaping (Bool) -> Void) -> Void

    @State private var pane: ModelPane
    @State private var query = ""
    @State private var submitting: ModelChoice?
    @State private var selectionError: String?

    init(
        catalog: ModelCatalog?,
        current: ModelChoice?,
        loading: Bool = false,
        error: String? = nil,
        pending: ModelChoice? = nil,
        enabled: Bool = true,
        openModels: Bool = false,
        onReload: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void,
        onPick: @escaping (ModelChoice, @escaping (Bool) -> Void) -> Void
    ) {
        self.catalog = catalog
        self.current = current
        self.loading = loading
        self.error = error
        self.pending = pending
        self.enabled = enabled
        self.openModels = openModels
        self.onReload = onReload
        self.onDismiss = onDismiss
        self.onPick = onPick
        _pane = State(initialValue: openModels ? .models : .root)
    }

    private var busy: ModelChoice? { submitting ?? pending }
    private var selectedModel: ModelInfo? {
        current.flatMap { catalog?.find(provider: $0.provider, model: $0.model) }
    }
    private var effectiveEffort: String? { current?.effort ?? selectedModel?.defaultEffort }
    private var count: Int { catalog?.groups.reduce(0) { $0 + $1.models.count } ?? 0 }
    private var showSearch: Bool { count > 4 }
    private var groups: [ModelGroup] {
        modelPickerGroups(catalog?.groups ?? [], query: showSearch ? query : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let selectionError {
                Text(selectionError).font(.footnote).foregroundStyle(T.err).padding(12)
            }
            if pane == .root {
                cell(L.t("模型", "Model"), loading && catalog == nil ? L.loading() : (selectedModel?.name ?? L.t("选择模型", "Select model"))) {
                    pane = .models
                }
                if selectedModel?.hasReasoning == true {
                    cell(L.t("推理等级", "Reasoning effort"), modelEffortLabel(catalog: catalog, provider: current?.provider, model: current?.model, effort: current?.effort) ?? "") {
                        pane = .effort
                    }
                }
            }
            if pane == .models {
                if showSearch {
                    HStack {
                        TextField(L.t("搜索模型…", "Search models…"), text: $query)
                            .textFieldStyle(.plain)
                            .disabled(busy != nil)
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark").font(.caption).foregroundStyle(T.caption)
                            }
                            .disabled(busy != nil)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                }
                if loading { ProgressView().frame(maxWidth: .infinity) }
                if let error { notice(error) }
                ForEach(catalog?.failures ?? [], id: \.id) { failure in
                    notice("\(failure.name): \(failure.message)")
                }
                if groups.isEmpty && !loading && error == nil {
                    Text(count == 0 ? L.t("暂无可用模型", "No models available") : L.t("没有匹配的模型", "No matching models"))
                        .foregroundStyle(T.text3)
                        .padding(12)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups) { group in
                            Text(modelPickerProviderLabel(group.id, hostName: group.name, english: L.en))
                                .font(.caption)
                                .foregroundStyle(T.text3)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            ForEach(group.models) { model in
                                let selected = current?.provider == group.id && current?.model == model.id
                                option(model.name, selected: selected, pending: busy?.provider == group.id && busy?.model == model.id) {
                                    pick(ModelChoice(provider: group.id, model: model.id, name: model.name, effort: nil), unchanged: selected)
                                }
                            }
                        }
                    }
                }
            }
            if pane == .effort, let current, let selectedModel {
                if selectedModel.defaultEffort == nil {
                    option(L.t("默认", "Default"), selected: effectiveEffort == nil, pending: busy != nil && busy?.effort == nil) {
                        pick(ModelChoice(provider: current.provider, model: current.model, name: current.name, effort: nil), unchanged: effectiveEffort == nil)
                    }
                }
                ForEach(selectedModel.efforts, id: \.id) { effort in
                    option(effort.name, selected: effectiveEffort == effort.id, pending: busy?.effort == effort.id) {
                        pick(ModelChoice(provider: current.provider, model: current.model, name: current.name, effort: effort.id), unchanged: effectiveEffort == effort.id)
                    }
                }
            }
        }
        .padding(4)
        .frame(maxWidth: 360)
        .background(T.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
        .onChange(of: enabled) { value in
            if !value { submitting = nil }
        }
        .onChange(of: selectedModel?.hasReasoning) { value in
            if pane == .effort && value != true { pane = .root }
        }
    }

    private func pick(_ choice: ModelChoice, unchanged: Bool) {
        if busy != nil || !enabled || loading { return }
        if unchanged { onDismiss(); return }
        selectionError = nil
        submitting = choice
        onPick(choice) { success in
            submitting = nil
            if success { onDismiss() }
            else { selectionError = L.t("切换失败，当前选择未改变，请重试", "Could not switch. Your current selection is unchanged; try again.") }
        }
    }

    private func cell(_ label: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundStyle(T.ink)
                Spacer()
                Text(value).foregroundStyle(T.text3).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(T.caption)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
    }

    private func option(_ label: String, selected: Bool, pending: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundStyle(enabled || selected ? T.ink : T.text3)
                Spacer()
                if pending { ProgressView().controlSize(.mini) }
                else if selected { Image(systemName: "checkmark").foregroundStyle(T.ink) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 32)
            .background(selected ? T.fill2 : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading || busy != nil)
    }

    private func notice(_ message: String) -> some View {
        HStack {
            Text(message).font(.caption).foregroundStyle(T.err)
            Spacer()
            Button(L.retry(), action: onReload).disabled(loading).font(.caption)
        }
        .padding(8)
        .background(T.fill2, in: RoundedRectangle(cornerRadius: 8))
    }
}
