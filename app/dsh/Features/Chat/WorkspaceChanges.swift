import SwiftUI
import DSHProtocol

struct ChangesCard: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    let item: Item.Changes

    @State private var summary: WorkspaceChangesSummary?
    @State private var selected: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 0)
                .accessibilityHidden(true)
            if let summary, !summary.files.isEmpty {
                ChangesSummaryCard(
                    summary: summary,
                    identity: "\(model.activeId ?? "")/\(sessionId)/\(item.seq.map(String.init) ?? "")",
                    onOpen: model.ops.contains("workspaceChanges.diff") ? { selected = $0 } : nil
                )
            }
        }
        .task(id: changesCardFetchIdentity(
            hostId: model.activeId,
            sessionId: sessionId,
            seq: item.seq,
            hasSummaryOp: model.ops.contains("workspaceChanges.summary")
        )) {
            summary = nil
            let hasOp = model.ops.contains("workspaceChanges.summary")
            guard changesCardShouldFetch(seq: item.seq, hasSummaryOp: hasOp), let seq = item.seq else {
                #if DEBUG
                print("[dsh.changes] card skip session=\(sessionId) seq=\(item.seq.map(String.init) ?? "nil") op=\(hasOp)")
                #endif
                return
            }
            do {
                summary = try await model.fetchChangesSummary(sessionId: sessionId, seq: seq)
                #if DEBUG
                print("[dsh.changes] card session=\(sessionId) seq=\(seq) files=\(summary?.files.count ?? 0) turnClosed")
                #endif
            } catch is CancellationError {
                return
            } catch {
                #if DEBUG
                print("[dsh.changes] card fetch failed session=\(sessionId) seq=\(seq) error=\(error)")
                #endif
            }
        }
        .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            if let summary, let selected {
                ChangesReviewSheet(
                    model: model,
                    sessionId: sessionId,
                    seq: item.seq ?? 0,
                    summary: summary,
                    initialIndex: selected,
                    onDismiss: { self.selected = nil }
                )
            }
        }
    }
}

struct ChangesSummaryCard: View {
    let summary: WorkspaceChangesSummary
    let identity: String
    var onOpen: ((Int) -> Void)?

    @State private var expanded = false

    var body: some View {
        if summary.files.isEmpty {
            EmptyView()
        } else {
            let single = summary.total == 1 ? summary.files.first : nil
            VStack(spacing: 0) {
                Button {
                    onOpen?(0)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(T.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 1))
                            Image(systemName: single == nil ? "doc.on.doc" : "doc.text")
                                .font(.system(size: 18))
                                .foregroundStyle(T.text2)
                        }
                        .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(single == nil ? L.editedCount(summary.total) : L.editedName(single!.display.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? single!.display))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(T.ink)
                                .lineLimit(2)
                                .accessibilityLabel(single?.display ?? L.editedCount(summary.total))
                            ChangeCounts(added: summary.added, deleted: summary.deleted, file: single)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(T.fill2)
                }
                .buttonStyle(.plain)
                .disabled(onOpen == nil)
                .accessibilityHint(L.t("查看本轮改动", "Review turn changes"))

                if single == nil {
                    Divider()
                    let files = expanded ? summary.files : Array(summary.files.prefix(4))
                    ForEach(Array(files.enumerated()), id: \.offset) { index, file in
                        Button {
                            onOpen?(index)
                        } label: {
                            HStack {
                                Text(file.display)
                                    .font(.system(size: 14))
                                    .foregroundStyle(T.text3)
                                    .lineLimit(1)
                                    .accessibilityLabel(file.display)
                                Spacer(minLength: 12)
                                ChangeCounts(added: file.added, deleted: file.deleted, file: file)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(onOpen == nil)
                    }
                    if summary.files.count > 4 {
                        Button {
                            expanded.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Text(expanded ? L.t("收起", "Collapse") : L.t("全部 \(summary.files.count) 个文件", "All \(summary.files.count) files"))
                                    .font(.system(size: 14))
                                    .foregroundStyle(T.text3)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11))
                                    .foregroundStyle(T.text3)
                                    .rotationEffect(.degrees(expanded ? 180 : 0))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.border, lineWidth: 1))
            .onAppear { expanded = false }
            .id(identity)
        }
    }
}

private struct ChangeCounts: View {
    let added: Int
    let deleted: Int
    var file: WorkspaceChangedFile?

    var body: some View {
        if file?.binary == true {
            Text(L.t("二进制", "Binary")).font(.system(size: 12)).foregroundStyle(T.text3)
        } else if file?.oversized == true {
            Text(L.t("过大", "Too large")).font(.system(size: 12)).foregroundStyle(T.text3)
        } else {
            HStack(spacing: 8) {
                Text("+\(added)").font(.system(size: 12, design: .monospaced)).foregroundStyle(T.ok)
                Text("−\(deleted)").font(.system(size: 12, design: .monospaced)).foregroundStyle(T.err)
            }
        }
    }
}

private struct ChangesReviewSheet: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    let seq: Int64
    let summary: WorkspaceChangesSummary
    let initialIndex: Int
    var onDismiss: () -> Void

    @State private var index: Int
    @State private var retry = 0
    @State private var loading = true
    @State private var failure: String?
    @State private var diff: WorkspaceFileDiff?
    @State private var cache: [Int: WorkspaceFileDiff?] = [:]

    init(
        model: AppModel,
        sessionId: String,
        seq: Int64,
        summary: WorkspaceChangesSummary,
        initialIndex: Int,
        onDismiss: @escaping () -> Void
    ) {
        self.model = model
        self.sessionId = sessionId
        self.seq = seq
        self.summary = summary
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _index = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                if summary.files.indices.contains(index) {
                    let file = summary.files[index]
                    Menu {
                        ForEach(Array(summary.files.enumerated()), id: \.offset) { at, entry in
                            Button(entry.display) { index = at }
                        }
                    } label: {
                        HStack {
                            Text(file.display).lineLimit(2).foregroundStyle(T.ink)
                            Image(systemName: "chevron.down").font(.caption).foregroundStyle(T.text2)
                            Spacer()
                        }
                    }
                    ChangeCounts(added: file.added, deleted: file.deleted, file: file)
                }
                if loading {
                    Spacer()
                    ProgressView().tint(T.accent).frame(maxWidth: .infinity)
                    Spacer()
                } else if let failure {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(failure).foregroundStyle(T.err)
                        Button(L.docRetry()) { retry += 1 }
                    }
                    .padding(.vertical, 8)
                    Spacer()
                } else {
                    ChangesDiffBody(diff: diff)
                }
            }
            .padding(16)
            .background(T.bg)
            .navigationTitle(L.t("本轮改动 · \(summary.turn)", "Turn \(summary.turn) changes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close(), action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task(id: "\(sessionId)-\(seq)-\(index)-\(retry)") {
            loading = true
            failure = nil
            do {
                if let cached = cache[index] {
                    diff = cached
                } else {
                    let loaded = try await model.fetchChangesDiff(sessionId: sessionId, seq: seq, index: index)
                    cache[index] = loaded
                    diff = loaded
                }
            } catch is CancellationError {
                return
            } catch {
                failure = error.localizedDescription
            }
            loading = false
        }
    }
}

private struct ChangesDiffBody: View {
    let diff: WorkspaceFileDiff?

    var body: some View {
        let notice: String? = {
            guard let diff else { return L.t("远程主机已不再提供本轮改动", "The remote host no longer has this comparison") }
            if diff.kind == "binary" { return L.t("二进制文件，无法显示文本差异", "Binary file; no text comparison") }
            if diff.kind == "oversized" { return L.t("文件过大，未捕获文本差异", "File too large; comparison was not captured") }
            if !diff.before { return L.t("本轮新增文件", "File added in this turn") }
            if !diff.after { return L.t("本轮删除文件", "File deleted in this turn") }
            if diff.hunks.isEmpty { return L.t("文件内容相同", "File contents are identical") }
            if diff.coarse { return L.t("逐行对比超时，按整文件替换展示", "Comparison timed out; showing whole-file replacement") }
            return nil
        }()
        let lines = diff.map(changeDiffLines) ?? []
        let truncated = (diff?.hunks.reduce(0) { $0 + $1.lines.count } ?? 0) > 5000
        VStack(alignment: .leading, spacing: 0) {
            if let notice {
                Text(notice).foregroundStyle(T.text3).padding(.bottom, 8)
            }
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        let mark = line.text.first
                        let tint: Color = mark == "+" ? T.ok : mark == "-" ? T.err : T.text3
                        HStack(alignment: .top, spacing: 0) {
                            Text(line.old.map(String.init) ?? "")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(T.text3)
                                .frame(width: 38, alignment: .trailing)
                            Text(line.new.map(String.init) ?? "")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(T.text3)
                                .frame(width: 38, alignment: .trailing)
                            Text(line.text)
                                .font(LocalFonts.code())
                                .foregroundStyle(T.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                        .background(mark == " " || mark == nil ? Color.clear : tint.opacity(0.09))
                    }
                    if truncated {
                        Text(L.t("仅显示前 5000 行", "Showing the first 5000 lines"))
                            .foregroundStyle(T.text3)
                            .padding(.vertical, 16)
                    }
                }
            }
        }
    }
}

