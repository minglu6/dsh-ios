import SwiftUI
import DSHProtocol

struct MoreSheet: View {
    @ObservedObject var model: AppModel
    var onDismiss: () -> Void
    var onFeedback: () -> Void
    var onBrowser: () -> Void = {}
    var onInspector: () -> Void = {}

    @State private var renaming = false
    @State private var title = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if renaming, let chat = model.chat {
                        Text(L.renameSession()).font(.caption).foregroundStyle(T.text3).padding(.horizontal, 22).padding(.top, 12)
                        TextField(L.rename(), text: $title)
                            .padding(12)
                            .background(T.input, in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        Button {
                            model.rename(chat.sessionId, title: title.trimmingCharacters(in: .whitespacesAndNewlines))
                            onDismiss()
                        } label: {
                            Text(L.save())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(T.onPrimary)
                                .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!model.isOnline || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(22)
                    } else {
                        if model.chat != nil {
                            row(L.rename(), D.edit) {
                                title = model.chat?.title ?? ""
                                renaming = true
                            }
                            stats
                            Divider().padding(.vertical, 8)
                        }
                        row(
                            L.downloadSessionLog(),
                            D.download,
                            enabled: MoreSheetPolicy.exportEnabled(
                                online: model.isOnline,
                                ops: model.ops,
                                inChat: model.chat != nil
                            )
                        ) {
                            model.exportSession()
                            onDismiss()
                        }
                        if MoreSheetPolicy.showsFeedback(ops: model.ops) {
                            row(L.sessionFeedback(), D.paperPlane, enabled: MoreSheetPolicy.feedbackEnabled(inChat: model.chat != nil)) {
                                onFeedback()
                            }
                        }
                        if MoreSheetPolicy.showsBrowser(inChat: model.chat != nil) {
                            row(L.browser(), D.globe) {
                                onBrowser()
                            }
                        }
                        if MoreSheetPolicy.showsInspector(inChat: model.chat != nil) {
                            row(L.sessionInspector(), "viewfinder") {
                                onInspector()
                            }
                        }
                        if MoreSheetPolicy.showsFork(ops: model.ops, inChat: model.chat != nil) {
                            row(L.branch(), D.branch, detail: L.forkFromPrefix(), enabled: model.isOnline && model.chat?.running != true) {
                                model.forkCurrent(atSeq: nil)
                                onDismiss()
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .background(T.bg)
            .navigationTitle(L.moreActions())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel(), action: onDismiss)
                }
            }
        }
    }

    @ViewBuilder
    private var stats: some View {
        let metrics = model.chat?.composerMetrics
        Text(metrics?.activityIsWholeSession == true ? L.sessionStats() : L.loadedHistoryStats())
            .font(.caption)
            .foregroundStyle(T.text3)
            .padding(.horizontal, 22)
            .padding(.top, 12)
        VStack(alignment: .leading, spacing: 6) {
            if let activity = metrics?.activity {
                Text("\(activity.turns) 轮 · \(activity.steps) 步").foregroundStyle(T.text2).font(.subheadline)
            }
            if let tokens = metrics?.tokens {
                Text("输入 \(kfmt(tokens.billedInputTokens)) · 输出 \(kfmt(tokens.outputTokens))")
                    .foregroundStyle(T.text2).font(.subheadline)
                if let hit = tokens.cacheHitPercent {
                    Text("缓存命中 \(hit)%").foregroundStyle(T.text3).font(.caption)
                }
            }
            if metrics?.activity == nil && metrics?.tokens == nil {
                Text(L.noHostStats()).foregroundStyle(T.text3).font(.subheadline)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 4)
    }

    private func row(_ title: String, _ system: String, detail: String? = nil, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: system).foregroundStyle(enabled ? T.ink : T.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(enabled ? T.ink : T.caption)
                    if let detail {
                        Text(detail).font(.caption).foregroundStyle(T.text3)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }

    private func kfmt(_ n: Int64) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000.0) : "\(n)"
    }
}
