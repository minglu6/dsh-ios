import SwiftUI
import DSHProtocol

struct AgentPresetSettingsView: View {
    @ObservedObject var model: AppModel
    var onCreator: (() -> Void)?

    @State private var data: JSONValue?
    @State private var loading = true
    @State private var revisionFresh = false
    @State private var busy = false
    @State private var error: String?
    @State private var viewRow: JSONValue?
    @State private var viewContent: String?
    @State private var viewRequest = 0
    @State private var guide: (String, PresetGuidePage)?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L.presetOnboarding()).font(.subheadline).foregroundStyle(T.text2).padding(.horizontal, 18)
                    if let error { Text(error).foregroundStyle(T.err).padding(.horizontal, 18) }
                    if busy { ProgressView().padding(.horizontal, 18) }
                    if loading {
                        Text(L.loading()).foregroundStyle(T.text3).padding(18)
                    } else if rows.isEmpty {
                        Text(L.unavailable()).foregroundStyle(T.text3).padding(18)
                        if canLoad {
                            Button(L.retry()) { Task { await load() } }.padding(.horizontal, 18)
                        }
                    } else {
                        groups
                    }
                    if model.isOnline && revisionFresh && !hostWritable {
                        Text(L.presetReadOnly()).font(.footnote).foregroundStyle(T.text3).padding(.horizontal, 18)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        .task(id: "\(model.isOnline)-\(model.modelSettingsRevision)-\(model.ops.contains("presets.settings"))") {
            await load(clearError: false)
        }
        .sheet(isPresented: Binding(get: { guide != nil }, set: { if !$0 { guide = nil } })) {
            if let guide {
                PresetGuideDialog(presetId: guide.0, initialPage: guide.1) { self.guide = nil }
            }
        }
        .sheet(isPresented: Binding(get: { viewContent != nil }, set: { if !$0 { viewContent = nil; viewRow = nil } })) {
            if let viewRow, let viewContent {
                PresetConfigurationSheet(row: viewRow, content: viewContent) {
                    viewRequest += 1
                    self.viewContent = nil
                    self.viewRow = nil
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: model.pop) { Image(systemName: "chevron.left").foregroundStyle(T.ink) }
            Text(L.agentPresets()).font(.headline).foregroundStyle(T.ink)
            Spacer()
            if error != nil {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(T.ink)
                }
                .disabled(!canLoad || busy || loading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(T.surface)
    }

    private var canLoad: Bool { PresetPolicy.canLoad(online: model.isOnline, ops: model.ops) }
    private var rows: [JSONValue] { PresetPolicy.parseRoster(data ?? .object([:])) }
    private var revision: Int64? { data?["namespace"]["revision"].long() }
    private var hostWritable: Bool { data.map { PresetPolicy.hostWritable(data: $0, ops: model.ops) } ?? false }
    private var writable: Bool { model.isOnline && revisionFresh && hostWritable }

    @ViewBuilder
    private var groups: some View {
        ForEach([true, false], id: \.self) { builtIn in
            let group = rows.filter { PresetPolicy.isBuiltIn($0) == builtIn && (model.showCodeWorkView || !PresetPolicy.requiresCodingTools($0)) }
            let creator = (!builtIn && PresetPolicy.canCreateWithCreator(rows, ops: model.ops, online: model.isOnline)) ? onCreator : nil
            if !group.isEmpty || creator != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text(builtIn ? L.builtIn() : L.custom())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(T.text3)
                    ForEach(Array(group.enumerated()), id: \.offset) { _, row in
                        PresetCard(
                            row: row,
                            builtIn: builtIn,
                            writable: writable,
                            busy: busy,
                            canRead: model.isOnline && model.ops.contains("presets.read"),
                            onSelect: { Task { await makeDefault(row) } },
                            onGuide: { page in if let id = row["id"].str() { guide = (id, page) } },
                            onView: { Task { await viewConfiguration(row) } }
                        )
                    }
                    if let creator {
                        Button(action: creator) {
                            HStack {
                                Image(systemName: D.plus)
                                Text(L.letAgentCreatePreset())
                            }
                            .foregroundStyle((model.isOnline && model.ops.contains("sessions.create") && !busy) ? T.ink : T.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(style: StrokeStyle(lineWidth: 1, dash: [4])))
                        }
                        .disabled(!(model.isOnline && model.ops.contains("sessions.create")) || busy)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func load(clearError: Bool = true) async {
        guard canLoad else {
            loading = false
            return
        }
        loading = true
        revisionFresh = false
        if clearError { error = nil }
        do {
            let roster = try await model.readPresetRoster()
            data = roster
            revisionFresh = true
            model.presetRoster = PresetPolicy.parseRoster(roster)
        } catch {
            self.error = settingsFailure(error)
        }
        loading = false
    }

    private func makeDefault(_ row: JSONValue) async {
        let id = row["id"].str() ?? ""
        guard writable, !busy, !loading, row["broken"].str() == nil, row["isDefault"].bool() != true, let expected = revision else { return }
        busy = true
        error = nil
        var writeFailure: Error?
        do {
            try requireSettingsSuccess(try await model.call("models.settingsMutate", args: jsonObject([
                "ns": .string(PresetPolicy.registryNamespace),
                "ops": PresetPolicy.defaultMutation(id: id),
                "expectedRevision": .number(Double(expected)),
            ])))
        } catch { writeFailure = error }
        revisionFresh = false
        var readFailure: Error?
        do {
            let confirmed = try await model.readPresetRoster()
            data = confirmed
            revisionFresh = true
            model.presetRoster = PresetPolicy.parseRoster(confirmed)
            if writeFailure == nil {
                let applied = PresetPolicy.parseRoster(confirmed).contains {
                    $0["id"].str() == id && $0["isDefault"].bool() == true
                }
                if !applied { throw PocketError(code: "conflict", message: L.defaultUnchanged()) }
            }
        } catch { readFailure = error }
        if let writeFailure {
            error = settingsFailure(writeFailure) + (readFailure.map { "\n" + settingsFailure($0) } ?? "")
        } else if let readFailure {
            error = settingsFailure(readFailure)
        }
        busy = false
    }

    private func viewConfiguration(_ row: JSONValue) async {
        guard model.ops.contains("presets.read"), let id = row["id"].str() else { return }
        viewRequest += 1
        let request = viewRequest
        error = nil
        do {
            let content = try await model.readPresetContent(id: id)
            if request == viewRequest {
                viewRow = row
                viewContent = content
            }
        } catch {
            if request == viewRequest { self.error = settingsFailure(error) }
        }
    }
}

private struct PresetCard: View {
    let row: JSONValue
    let builtIn: Bool
    let writable: Bool
    let busy: Bool
    let canRead: Bool
    var onSelect: () -> Void
    var onGuide: (PresetGuidePage) -> Void
    var onView: () -> Void

    var body: some View {
        let id = row["id"].str() ?? ""
        let name = PresetPolicy.name(row, english: L.en)
        let active = row["isDefault"].bool() == true
        let broken = row["broken"].str()
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(T.ink).lineLimit(1)
                        if broken != nil {
                            Text(L.loadFailed()).font(.caption2).foregroundStyle(T.onPrimary)
                                .padding(.horizontal, 8).background(T.err, in: Capsule())
                        }
                        Text(active ? L.newTaskDefault() : (builtIn ? L.builtIn() : L.custom()))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(active ? T.surface : T.text3)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(active ? T.ink : Color.clear, in: Capsule())
                            .overlay(Capsule().stroke(active ? Color.clear : T.border, lineWidth: 0.5))
                        Spacer()
                        Text(id).font(.system(size: 11, design: .monospaced)).foregroundStyle(T.text3).lineLimit(1)
                    }
                    Text(PresetPolicy.description(row, english: L.en) ?? L.noDescription())
                        .font(.footnote)
                        .foregroundStyle(T.text2)
                        .lineLimit(4)
                    if let broken { Text(broken).font(.caption).foregroundStyle(T.err) }
                }
                .padding(14)
            }
            .disabled(!writable || busy || active || broken != nil)
            .buttonStyle(.plain)
            Divider()
            HStack {
                if builtIn && PresetPolicy.guideAvailable(id) {
                    Button(L.modeExplanation()) { onGuide(.explanation) }.font(.caption).foregroundStyle(T.text3)
                    Button(L.howToUse()) { onGuide(.usage) }.font(.caption).foregroundStyle(T.text3)
                }
                Spacer()
                Button(action: onView) {
                    Image(systemName: D.browse).foregroundStyle(canRead ? T.text3 : T.caption)
                }
                .disabled(!canRead)
                .accessibilityLabel(L.viewConfiguration() + " · " + name)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(active ? T.fill2 : T.settingsCard, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(broken != nil ? T.err : T.settingsCardStroke, lineWidth: 0.5))
    }
}

private struct PresetConfigurationSheet: View {
    let row: JSONValue
    let content: String
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                ScrollView {
                    Text(content)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(T.text2)
                        .textSelection(.enabled)
                        .padding(12)
                }
            }
            .background(T.surface)
            .navigationTitle(L.viewConfiguration() + " · " + PresetPolicy.name(row, english: L.en))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.close(), action: onDismiss) }
            }
        }
    }
}

struct PresetSheet: View {
    @ObservedObject var model: AppModel
    let current: String
    let editable: Bool
    var onDismiss: () -> Void
    var onPick: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !editable {
                        Text(L.presetLocked()).font(.footnote).foregroundStyle(T.text3).padding(.horizontal, 18)
                    }
                    ForEach(Array(visible.enumerated()), id: \.offset) { _, row in
                        let id = row["id"].str() ?? ""
                        Button {
                            onPick(id)
                            onDismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(PresetPolicy.name(row, english: L.en)).foregroundStyle(T.ink)
                                    if let detail = PresetPolicy.description(row, english: L.en) {
                                        Text(detail).font(.caption).foregroundStyle(T.text3).lineLimit(2)
                                    }
                                }
                                Spacer()
                                if current == id { Image(systemName: "checkmark").foregroundStyle(T.accent) }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                        }
                        .disabled(!editable || !model.isOnline)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
            .navigationTitle(L.agentPresets())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.cancel(), action: onDismiss) } }
        }
    }

    private var visible: [JSONValue] {
        PresetPolicy.visibleRows(model.presetRoster, codingTools: model.showCodeWorkView)
    }
}
