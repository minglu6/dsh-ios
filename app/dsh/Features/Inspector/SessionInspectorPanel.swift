import SwiftUI
import DSHProtocol

@MainActor
final class InspectorNavigation: ObservableObject {
    static let shared = InspectorNavigation()

    @Published var sessionId: String?
    @Published var picking = false
    @Published var pickedItemKey: String?
    @Published var revealItemKey: String?

    func begin(sessionId: String) {
        self.sessionId = sessionId
        pickedItemKey = nil
        revealItemKey = nil
        picking = true
    }

    func pick(_ itemKey: String) {
        if !picking || itemKey.isEmpty { return }
        pickedItemKey = itemKey
        picking = false
    }

    func cancel() { picking = false }

    func reveal(sessionId: String, itemKey: String) {
        self.sessionId = sessionId
        picking = false
        pickedItemKey = nil
        revealItemKey = itemKey
    }

    func reset() {
        sessionId = nil
        picking = false
        pickedItemKey = nil
        revealItemKey = nil
    }
}

struct InspectorChatTarget<Content: View>: View {
    let itemKey: String
    var highlighted = false
    var reveal = false
    @ViewBuilder var content: () -> Content

    @ObservedObject private var nav = InspectorNavigation.shared

    var body: some View {
        let picking = nav.picking && nav.sessionId != nil
        content()
            .padding(highlighted || reveal ? 4 : 0)
            .background((highlighted || reveal) ? T.accent.opacity(0.08) : Color.clear)
            .overlay {
                if highlighted || reveal {
                    RoundedRectangle(cornerRadius: 8).stroke(T.accent.opacity(0.5), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .overlay {
                if picking {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { nav.pick(itemKey) }
                }
            }
    }
}

struct SessionInspectorPanel: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    var onDismiss: () -> Void

    @ObservedObject private var nav = InspectorNavigation.shared
    @StateObject private var state = InspectorViewState()

    var body: some View {
        Group {
            if let chat = model.chat, chat.sessionId == sessionId, !sessionId.isEmpty {
                NavigationStack {
                    SessionInspectorContent(model: model, sessionId: sessionId, state: state, onDismiss: onDismiss)
                        .background(T.bg)
                        .navigationTitle(L.sessionInspector())
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(action: onDismiss) {
                                    Text(L.close()).foregroundStyle(T.ink)
                                }
                            }
                        }
                        .tint(T.ink)
                }
            }
        }
        .onDisappear {
            if !nav.picking { nav.reset() }
        }
        .id(sessionId)
    }
}

@MainActor
final class InspectorViewState: ObservableObject {
    @Published var grouped = false
    @Published var filter = ""
    @Published var collapsed = Set<String>()
    @Published var expanded = Set<String>()
    @Published var selectedKey: String?
    @Published var follow = true
    @Published var scrollRequest = 0
    @Published var detailFraction: CGFloat = 0.4

    func mode(group: Bool) {
        grouped = group
        filter = ""
        collapsed = []
        expanded = []
        selectedKey = nil
        follow = true
    }

    func applyFilter(_ value: String) {
        filter = value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "*"))
        selectedKey = nil
        collapsed = []
        expanded = []
        follow = false
    }
}

private struct SessionInspectorContent: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    @ObservedObject var state: InspectorViewState
    var onDismiss: () -> Void
    @ObservedObject private var nav = InspectorNavigation.shared

    @State private var modesOpen = false
    @State private var filterOpen = false

    var body: some View {
        if let chat = model.chat, chat.sessionId == sessionId {
            inspectorBody(chat)
        }
    }

    private func inspectorChatState(_ chat: ChatState) -> InspectorChatState {
        InspectorChatState(
            sessionId: chat.sessionId,
            items: chat.items,
            turns: chat.turns,
            running: chat.running,
            hasMore: chat.hasMore
        )
    }

    @ViewBuilder
    private func inspectorBody(_ chat: ChatState) -> some View {
        let policy = presentationPolicyFor(model.transcriptView, collapseTiming: model.collapseTiming)
        let inspectorState = inspectorChatState(chat)
        let rows = state.grouped
            ? inspectorGroupRows(inspectorState, policy: policy)
            : inspectorRawRows(chat.inspectorRecords)
        let all = flatten(rows)
        let visible = inspectorVisibleRows(rows, filter: state.filter, collapsed: state.collapsed, expanded: state.expanded)
        let matchingCount = all.filter { inspectorTypeMatches($0.type, filter: state.filter) }.count
        let selected = all.first { $0.key == state.selectedKey }

        GeometryReader { geo in
            VStack(spacing: 0) {
                toolbar(chat: chat, allCount: all.count, matchingCount: matchingCount)
                Divider()
                table(visible: visible, chat: chat, inspectorState: inspectorState, rows: rows)
                if state.selectedKey != nil {
                    detail(selected: selected, height: geo.size.height * state.detailFraction, grouped: state.grouped)
                }
            }
            .onChange(of: nav.pickedItemKey) { key in
                guard nav.sessionId == chat.sessionId, let key else { return }
                let item = chat.items.first { $0.key == key }
                guard let item, let row = inspectorRowForItem(rows, item: item) else { return }
                state.filter = ""
                state.collapsed = []
                state.expanded = Set(all.map(\.key))
                state.selectedKey = row.key
                state.follow = false
                nav.pickedItemKey = nil
            }
        }
    }

    private func flatten(_ rows: [InspectorRow]) -> [InspectorRow] {
        var out: [InspectorRow] = []
        func visit(_ row: InspectorRow) {
            out.append(row)
            row.children.forEach(visit)
        }
        rows.forEach(visit)
        return out
    }

    private func toolbar(chat: ChatState, allCount: Int, matchingCount: Int) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Menu {
                    Button(L.t("原始数据", "Raw Log")) { state.mode(group: false) }
                    Button(L.t("对话分组", "Chat Group")) { state.mode(group: true) }
                } label: {
                    HStack(spacing: 4) {
                        Text(state.grouped ? L.t("对话分组", "Chat Group") : L.t("原始数据", "Raw Log"))
                            .font(.system(size: 11))
                            .foregroundStyle(T.ink)
                        Image(systemName: "chevron.down").font(.system(size: 9)).foregroundStyle(T.ink)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(T.fill2)
                }
                .accessibilityLabel(L.t("展示形式", "Presentation"))

                Button {
                    nav.begin(sessionId: chat.sessionId)
                    onDismiss()
                } label: {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 12))
                        .foregroundStyle(T.ink)
                        .frame(width: 22, height: 22)
                }
                .accessibilityLabel(L.t("在对话面板中选取元素", "Pick an element in Chat View"))

                Text("· " + (state.filter.isEmpty ? "\(allCount)" : "\(matchingCount) / \(allCount)"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(T.ink)
            }
            Spacer()
            if chat.hasMore {
                Button {
                    state.follow = false
                    if model.chat?.sessionId == chat.sessionId { model.loadOlderHistory() }
                } label: {
                    Text(loadOlderLabel(loading: chat.loadingOlder, english: L.en))
                        .font(.system(size: 11))
                        .foregroundStyle(chat.loadingOlder ? T.text3 : T.ink)
                }
                .disabled(chat.loadingOlder)
            }
            Button {
                state.follow = true
                state.scrollRequest += 1
            } label: {
                Text(L.t("跟踪最新", "Follow Latest")).font(.system(size: 11)).foregroundStyle(T.ink)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 34)
    }

    private func table(visible: [InspectorVisibleRow], chat: ChatState, inspectorState: InspectorChatState, rows: [InspectorRow]) -> some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow(rows: rows)
                    Divider()
                    if visible.isEmpty {
                        Text(L.t("暂无记录", "No records"))
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                            .padding(12)
                    } else {
                        ForEach(visible, id: \.row.key) { entry in
                            rowView(entry, chat: chat, inspectorState: inspectorState)
                                .id(entry.row.key)
                            Divider()
                        }
                    }
                }
                .frame(minWidth: 660, alignment: .leading)
            }
            .onChange(of: visible.last?.row.key) { key in
                if state.follow, let key { proxy.scrollTo(key, anchor: .bottom) }
            }
            .onChange(of: state.scrollRequest) { _ in
                if let key = visible.last?.row.key { proxy.scrollTo(key, anchor: .bottom) }
            }
            .onChange(of: state.filter) { _ in
                if !state.follow, let key = visible.first?.row.key { proxy.scrollTo(key, anchor: .top) }
            }
            .onChange(of: state.selectedKey) { key in
                if let key { proxy.scrollTo(key, anchor: .center) }
            }
        }
    }

    private func headerRow(rows: [InspectorRow]) -> some View {
        HStack(spacing: 0) {
            cell(L.t("序号", "Index"), width: 64, header: true)
            HStack(spacing: 6) {
                Text(L.t("类型", "Type")).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(T.ink)
                InspectorTypeFilter(value: state.filter, rows: rows) { state.applyFilter($0) }
            }
            .frame(width: 190, alignment: .leading)
            .padding(.horizontal, 8)
            cell("T/S", width: 65, header: true)
            if !state.grouped {
                cell(L.t("时间 (UTC)", "Time (UTC)"), width: 100, header: true)
            }
            Text(L.t("数据", "Data")).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(T.ink)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .frame(height: 30)
        .background(T.fill2)
    }

    private func rowView(_ entry: InspectorVisibleRow, chat: ChatState, inspectorState: InspectorChatState) -> some View {
        let row = entry.row
        let collapsed = state.collapsed.contains(row.key) || (state.filter.isEmpty && row.defaultCollapsed && !state.expanded.contains(row.key))
        let select = {
            state.selectedKey = row.key
            if let itemKey = inspectorItemForRow(inspectorState, row: row) {
                nav.reveal(sessionId: chat.sessionId, itemKey: itemKey)
            }
        }
        return HStack(spacing: 0) {
            cell(row.identity, width: 64, muted: true)
            HStack(spacing: 0) {
                if !row.children.isEmpty {
                    Button {
                        if collapsed {
                            state.collapsed.remove(row.key)
                            state.expanded.insert(row.key)
                        } else {
                            state.collapsed.insert(row.key)
                            state.expanded.remove(row.key)
                        }
                        state.follow = false
                    } label: {
                        Text(collapsed ? "▸" : "▾")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(T.ink)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(collapsed ? L.t("展开子行", "Expand children") : L.t("收起子行", "Collapse children"))
                }
                Button(action: select) {
                    Text(row.type)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(entry.matches ? T.ink : T.text3)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, CGFloat(8 + entry.depth * 20))
            .padding(.trailing, 8)
            .frame(width: 190, alignment: .leading)
            cell(row.location, width: 65)
            if !state.grouped {
                cell(inspectorTime(row.time), width: 100)
            }
            Button(action: select) {
                Text(row.summary.flatMap { row.type != "block-start" || collapsed ? $0 : nil } ?? inspectorPreview(row.value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(T.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 30)
        .background(state.selectedKey == row.key ? T.hoverBg : T.surface)
    }

    private func detail(selected: InspectorRow?, height: CGFloat, grouped: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(T.border)
                .frame(height: 5)
                .gesture(DragGesture().onChanged { value in
                    let parent = height / max(state.detailFraction, 0.01)
                    if parent > 0 {
                        state.detailFraction = min(0.8, max(0.15, state.detailFraction - value.translation.height / parent))
                    }
                })
                .accessibilityLabel(L.t("调整原始数据面板高度", "Resize raw data panel"))
            HStack {
                Text(L.t("原始数据", "Raw data")).font(.system(size: 11)).foregroundStyle(T.ink)
                Spacer()
                Button {
                    state.selectedKey = nil
                } label: {
                    Text(L.t("关闭", "Close")).font(.system(size: 11)).foregroundStyle(T.ink)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            Divider()
            if let selected {
                if grouped {
                    Text("\(selected.type) · \(selected.identity)")
                        .font(.system(size: 11))
                        .foregroundStyle(T.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    Divider()
                }
                InspectorValueTree(value: selected.value, grouped: grouped)
            } else {
                Text(L.t("该记录已移除或结算，请选择当前记录。", "This record was removed or settled. Select a current record."))
                    .font(.system(size: 11))
                    .foregroundStyle(T.ink)
                    .padding(8)
            }
        }
        .frame(height: height)
    }

    private func cell(_ text: String, width: CGFloat, header: Bool = false, muted: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11, weight: header ? .bold : .regular, design: .monospaced))
            .foregroundStyle(muted ? T.text3 : T.ink)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(width: width, alignment: .leading)
    }
}

private struct InspectorTypeFilter: View {
    let value: String
    let rows: [InspectorRow]
    var apply: (String) -> Void
    @State private var open = false
    @State private var draft = ""

    var body: some View {
        Button {
            draft = value
            open.toggle()
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11))
                .foregroundStyle(value.isEmpty ? T.ink : T.accent)
                .frame(width: 17, height: 17)
        }
        .accessibilityLabel(L.t("筛选类型", "Filter types"))
        .popover(isPresented: $open) {
            let suggestions = inspectorTypeSuggestions(rows, filter: draft)
            VStack(alignment: .leading, spacing: 6) {
                TextField(L.t("输入类型片段，如 delta", "Type a fragment, e.g. delta"), text: $draft)
                    .font(.system(size: 11))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(T.border, lineWidth: 0.5))
                    .accessibilityLabel(L.t("类型关键词", "Type keyword"))
                    .onSubmit { commit(draft) }
                Text(L.t("默认包含匹配（*关键词*）；Enter 确认，Esc 取消。", "Contains matching (*keyword*). Enter confirms; Esc cancels."))
                    .font(.system(size: 11))
                    .foregroundStyle(T.text2)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \.self) { type in
                            Button { commit(type) } label: {
                                Text(type).font(.system(size: 11, design: .monospaced)).foregroundStyle(T.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 180)
                .accessibilityLabel(L.t("类型候选", "Type suggestions"))
                if suggestions.isEmpty {
                    Text(L.t("没有匹配候选，仍可确认当前关键词。", "No suggestions. You can still apply this keyword."))
                        .font(.system(size: 11))
                        .foregroundStyle(T.ink)
                }
                HStack {
                    Spacer()
                    Button(L.t("清空", "Clear")) { draft = "" }
                    Button(L.t("取消", "Cancel")) { open = false }
                    Button(L.t("确认筛选", "Apply filter")) { commit(draft) }
                }
                .font(.system(size: 11))
            }
            .padding(10)
            .frame(width: 290)
            .background(T.surface)
        }
    }

    private func commit(_ query: String) {
        apply(query)
        open = false
    }
}

private struct InspectorValueTree: View {
    let value: JSONValue
    let grouped: Bool
    @State private var toggled: [String: Bool] = [:]
    @State private var limits: [String: Int] = [:]

    private func isOpen(_ path: String) -> Bool {
        toggled[path] ?? (!grouped || path == "$")
    }

    var body: some View {
        let entries = buildEntries()
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(entries, id: \.path) { entry in
                    row(entry)
                }
            }
            .padding(8)
        }
    }

    private struct Entry {
        var path: String
        var name: String
        var value: JSONValue?
        var depth: Int
        var more: Bool = false
    }

    private func buildEntries() -> [Entry] {
        var out: [Entry] = []
        func visit(path: String, name: String, node: JSONValue, depth: Int) {
            out.append(Entry(path: path, name: name, value: node, depth: depth))
            let open = isOpen(path)
            if !open { return }
            let children: [(String, JSONValue)]
            switch node {
            case .object(let object):
                children = object.keys.sorted().compactMap { key in
                    object[key].map { (key, $0) }
                }
            case .array(let array):
                children = array.enumerated().map { (String($0.offset), $0.element) }
            default:
                return
            }
            let limit = grouped ? (limits[path] ?? 50) : children.count
            if children.isEmpty {
                out.append(Entry(path: "\(path)/empty", name: "", value: nil, depth: depth + 1))
            }
            for (key, child) in children.prefix(limit) {
                visit(path: "\(path)/\(key.count):\(key)", name: key, node: child, depth: depth + 1)
            }
            if children.count > limit {
                out.append(Entry(path: path + "/more", name: path, value: nil, depth: depth + 1, more: true))
            }
        }
        visit(path: "$", name: "$", node: value, depth: 0)
        return out
    }

    private func row(_ entry: Entry) -> some View {
        let node = entry.value
        let container: Bool = {
            if case .object = node { return true }
            if case .array = node { return true }
            return false
        }()
        let open = isOpen(entry.path)
        let label: String = {
            switch node {
            case .object: return "Object"
            case .array(let array): return "Array(\(array.count))"
            case .some(let value): return value.description
            case .none: return ""
            }
        }()
        let text: String = {
            if entry.more { return L.t("显示更多", "Show more") }
            if node == nil { return L.t("空", "Empty") }
            return (container ? (open ? "▾ " : "▸ ") : "") + "\(entry.name): \(label)"
        }()
        return Group {
            if container || entry.more {
                Button {
                    if entry.more {
                        limits[entry.name] = (limits[entry.name] ?? 50) + 50
                    } else {
                        toggled[entry.path] = !open
                    }
                } label: {
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(entry.more ? T.accent : T.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(T.text2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, CGFloat(16 + entry.depth * 16))
        .padding(.vertical, 2)
    }
}
