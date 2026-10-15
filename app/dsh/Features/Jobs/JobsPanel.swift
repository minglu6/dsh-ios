import SwiftUI
import DSHProtocol

/// Header chip. Polls only while this conversation is visible and the scene is active.
struct JobsAction: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    var onClick: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    private var available: Bool { model.canShowJobs }
    private var watching: Bool { available && scenePhase == .active }

    var body: some View {
        Group {
            if let chip = JobsActionLabel.chip(jobs: model.jobs, failed: model.jobsFailed) {
                Button(action: onClick) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                        Text(JobsActionLabel.text(chip, en: L.en))
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .foregroundStyle(chip == .unavailable ? T.err : T.text2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .accessibilityLabel(JobsActionLabel.text(chip, en: L.en))
            }
        }
        .task(id: "\(model.activeId ?? "")-\(sessionId)-\(watching)") {
            await model.watchJobs(hostId: model.activeId, sessionId: sessionId, available: watching)
        }
    }
}

struct JobsPanel: View {
    @ObservedObject var model: AppModel
    var onDismiss: (() -> Void)?
    @State private var stopping: JobRow?
    @State private var killing = false

    private var sessionId: String? { model.chat?.sessionId }
    private var online: Bool { model.isOnline }
    private var canKill: Bool { online && !killing && model.ops.contains("jobs.kill") }

    var body: some View {
        VStack(spacing: 0) {
            if let detail = model.jobDetail, let job = currentJob(detail.jobId) ?? fallback(detail) {
                detailView(detail, job: job)
            } else {
                roster
            }
        }
        .background(T.bg.ignoresSafeArea())
        .onDisappear { model.clearJobSelection() }
        .confirmationDialog(
            L.killBackgroundJobTitle(),
            isPresented: Binding(
                get: { stopping != nil },
                set: { if !$0 && !killing { stopping = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L.killJob(), role: .destructive) {
                guard let job = stopping else { return }
                killing = true
                model.killJob(jobId: job.id) { success in
                    killing = false
                    stopping = nil
                    if !success {
                        model.errorMessage = L.killJobFailed()
                    }
                }
            }
            .disabled(!canKill)
            Button(L.cancel(), role: .cancel) {
                if !killing { stopping = nil }
            }
        } message: {
            Text(stopping?.title ?? "")
        }
    }

    private var roster: some View {
        VStack(spacing: 0) {
            header(L.backgroundJobs()) {
                if let onDismiss { onDismiss() } else { model.pop() }
            }
            HStack {
                Button(L.refresh()) { model.refreshJobs() }
                    .disabled(!(online && sessionId != nil))
                    .foregroundStyle(online ? T.accent : T.text3)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            if model.jobs == nil && !model.jobsFailed {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
            if model.jobsFailed {
                Text(model.errorMessage ?? L.jobLoadFailed())
                    .foregroundStyle(T.err)
                    .padding(22)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let jobs = model.jobs, jobs.isEmpty, !model.jobsFailed {
                        Text(L.jobsZero()).foregroundStyle(T.text3).padding(22)
                    }
                    ForEach(model.jobs ?? []) { job in
                        HStack(spacing: 8) {
                            Button {
                                model.selectJob(job)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "clock").foregroundStyle(T.text2).font(.system(size: 16))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(job.title).foregroundStyle(T.ink).lineLimit(1)
                                        if !job.status.isEmpty {
                                            Text(job.status).font(.caption).foregroundStyle(T.text3)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if job.canKill {
                                Button(L.killJob()) { stopping = job }
                                    .foregroundStyle(canKill ? T.err : T.caption)
                                    .disabled(!canKill)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private func detailView(_ detail: JobDetailState, job: JobRow) -> some View {
        VStack(spacing: 0) {
            header(job.title) { model.clearJobSelection() }
            HStack {
                Button(L.backToJobs()) { model.clearJobSelection() }
                    .foregroundStyle(T.accent)
                Spacer()
                if !detail.status.isEmpty {
                    Text(detail.status).font(.caption).foregroundStyle(T.text3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            if let extra = job.detail, !extra.isEmpty {
                Text(extra)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(T.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            if let error = detail.error {
                Text(error).foregroundStyle(T.err).padding(.horizontal, 22).padding(.top, 8)
                Button(L.retry()) { model.retryJobFollow() }
                    .disabled(!online)
                    .padding(.bottom, 8)
            }
            if detail.output.isEmpty && detail.error == nil {
                Text(L.waitingJobOutput()).foregroundStyle(T.text3).padding(22)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(detail.output.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(T.text2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func currentJob(_ id: String) -> JobRow? {
        model.jobs?.first { $0.id == id }
    }

    private func fallback(_ detail: JobDetailState) -> JobRow? {
        JobRow(id: detail.jobId, status: detail.status, title: detail.jobId)
    }
}
