import SwiftUI
import DSHProtocol

enum ModelPane { case root, models, effort }

/// Desktop `ModelSelect` two-level MenuSurface, anchored above the composer chip.
struct ModelChipMenu: View {
    let catalog: ModelCatalog?
    let current: ModelChoice?
    var loading: Bool = false
    var error: String? = nil
    var pending: ModelChoice? = nil
    var enabled: Bool = true
    @Binding var open: Bool
    var onReload: () -> Void = {}
    var onPick: (ModelChoice, @escaping (Bool) -> Void) -> Void

    var body: some View {
        Button { if enabled { open.toggle() } } label: {
            HStack(spacing: 4) {
                Text(
                    composerModelDisplayName(choiceName: current?.name, catalog: catalog)
                        ?? composerModelFallback(english: L.en)
                )
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(T.text2)
                .lineLimit(1)
                if let effort = modelEffortLabel(
                    catalog: catalog,
                    provider: current?.provider,
                    model: current?.model,
                    effort: current?.effort
                ) {
                    Text(effort).font(.system(size: 13)).foregroundStyle(T.caption).lineLimit(1)
                }
                if pending != nil {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(T.caption)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
            }
            .frame(minHeight: CGFloat(composerChipHeightPoints))
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .popover(isPresented: $open, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            ModelPicker(
                catalog: catalog,
                current: current,
                loading: loading,
                error: error,
                pending: pending,
                enabled: enabled,
                onReload: onReload,
                onDismiss: { open = false },
                onPick: onPick
            )
            .frame(
                minWidth: CGFloat(modelPickerMenuMinWidthPoints),
                maxWidth: CGFloat(modelPickerMenuMaxWidthPoints),
                maxHeight: CGFloat(modelPickerMenuMaxHeightPoints)
            )
            .modifier(PopoverCompactAdaptation())
        }
    }
}

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
    private var showEffort: Bool {
        !modelPickerRootShowsEffortOnlyWhenReasoning || selectedModel?.hasReasoning == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selectionError {
                Text(selectionError).font(.system(size: 11)).foregroundStyle(T.err).padding(8)
            }
            if pane == .root {
                cell(modelPickerRootModelLabel(english: L.en), loading && catalog == nil ? L.loading() : (composerModelDisplayName(choiceName: current?.name ?? selectedModel?.name, catalog: catalog) ?? current?.model ?? composerModelFallback(english: L.en))) {
                    pane = .models
                }
                if showEffort {
                    cell(modelPickerRootEffortLabel(english: L.en), modelEffortLabel(catalog: catalog, provider: current?.provider, model: current?.model, effort: current?.effort) ?? "") {
                        pane = .effort
                    }
                }
            }
            if pane == .models {
                if showSearch {
                    HStack {
                        TextField(modelPickerSearchPlaceholder(english: L.en), text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .disabled(busy != nil)
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark").font(.caption).foregroundStyle(T.caption)
                            }
                            .disabled(busy != nil)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                }
                if loading { ProgressView().frame(maxWidth: .infinity).padding(8) }
                if let error { notice(error) }
                ForEach(catalog?.failures ?? [], id: \.id) { failure in
                    notice("\(failure.name): \(failure.message)")
                }
                if groups.isEmpty && !loading && error == nil {
                    Text(count == 0 ? modelPickerEmptyModels(english: L.en) : modelPickerSearchEmpty(english: L.en))
                        .font(.system(size: 12))
                        .foregroundStyle(T.text3)
                        .padding(8)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups) { group in
                            Text(modelPickerProviderLabel(group.id, hostName: group.name, english: L.en))
                                .font(.system(size: 12))
                                .foregroundStyle(T.text3)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 6)
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
            if pane == .effort {
                if selectedModel == nil || selectedModel?.hasReasoning != true || (selectedModel?.efforts.isEmpty == true && selectedModel?.defaultEffort == nil) {
                    Text(modelPickerEmptyEfforts(english: L.en))
                        .font(.system(size: 12))
                        .foregroundStyle(T.text3)
                        .padding(8)
                } else if let current, let selectedModel {
                    if selectedModel.defaultEffort == nil {
                        option(modelPickerEffortProviderDefault(english: L.en), selected: effectiveEffort == nil, pending: busy != nil && busy?.effort == nil) {
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
        }
        .padding(CGFloat(permissionMenuPaddingPoints))
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
            HStack(spacing: 6) {
                Text(label).foregroundStyle(T.ink)
                Spacer()
                Text(value).foregroundStyle(T.text3).lineLimit(1)
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(T.caption)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .frame(minHeight: CGFloat(modelPickerRowMinHeightPoints))
        }
        .buttonStyle(.plain)
    }

    private func option(_ label: String, selected: Bool, pending: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(enabled || selected ? T.ink : T.text3)
                    .lineLimit(1)
                Spacer()
                if pending { ProgressView().controlSize(.mini) }
                else if selected { Image(systemName: "checkmark").foregroundStyle(T.ink) }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .frame(minHeight: CGFloat(modelPickerRowMinHeightPoints))
            .background(Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading || busy != nil)
    }

    private func notice(_ message: String) -> some View {
        HStack {
            Text(message).font(.system(size: 11)).foregroundStyle(T.err)
            Spacer()
            Button(modelPickerReloadAction(english: L.en), action: onReload).disabled(loading).font(.system(size: 11, weight: .semibold))
        }
        .padding(7)
        .background(T.fill2, in: RoundedRectangle(cornerRadius: 8))
    }
}
