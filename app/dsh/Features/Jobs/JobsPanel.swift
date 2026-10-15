import SwiftUI
import DSHProtocol

/// Header chip. Retains the shared jobs poll for this conversation; scenePhase is not part of the task id.
struct JobsAction: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    var onClick: () -> Void

    private var available: Bool { model.canShowJobs }

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
        .task(id: "\(model.activeId ?? "")-\(sessionId)-\(available)") {
            await model.retainJobsWatch(hostId: model.activeId, sessionId: sessionId, available: available)
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
        ZStack {
            VStack(spacing: 0) {
                if let detail = model.jobDetail, let job = currentJob(detail.jobId) ?? fallback(detail) {
                    detailView(detail, job: job)
                } else {
                    roster
                }
            }
            if let job = stopping {
                killOverlay(job)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .task(id: "panel-\(model.activeId ?? "")-\(sessionId ?? "")-\(model.canShowJobs)") {
            guard let sessionId else { return }
            await model.retainJobsWatch(hostId: model.activeId, sessionId: sessionId, available: model.canShowJobs)
        }
        .onDisappear { model.clearJobSelection() }
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
            if let err = model.jobsPanelError {
                Text(err)
                    .foregroundStyle(T.err)
                    .padding(22)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let jobs = model.jobs, jobs.isEmpty, !model.jobsFailed, model.jobsPanelError == nil {
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

    /// Android JobsSheet detail: 「返回后台任务」+ title. No extra header close.
    private func detailView(_ detail: JobDetailState, job: JobRow) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(L.backToJobs()) { model.clearJobSelection() }
                    .foregroundStyle(T.accent)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            Text(job.title)
                .font(.headline)
                .foregroundStyle(T.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            if !detail.status.isEmpty {
                Text(detail.status)
                    .font(.caption)
                    .foregroundStyle(T.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
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

    private func killOverlay(_ job: JobRow) -> some View {
        ZStack {
            T.scrim.ignoresSafeArea()
                .onTapGesture { if !killing { stopping = nil } }
            VStack(alignment: .leading, spacing: 14) {
                Text(L.killBackgroundJobTitle())
                    .font(.headline)
                    .foregroundStyle(T.ink)
                Text(job.title)
                    .foregroundStyle(T.text2)
                if let err = model.jobsPanelError {
                    Text(err).foregroundStyle(T.err)
                }
                HStack {
                    Button(L.cancel()) {
                        if !killing { stopping = nil }
                    }
                    .disabled(killing)
                    .foregroundStyle(T.text2)
                    Spacer()
                    Button(L.killJob()) {
                        killing = true
                        model.killJob(jobId: job.id) { success in
                            killing = false
                            if success { stopping = nil }
                        }
                    }
                    .disabled(!canKill)
                    .foregroundStyle(canKill ? T.err : T.caption)
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(T.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.border, lineWidth: 0.5))
        }
    }

    private func currentJob(_ id: String) -> JobRow? {
        model.jobs?.first { $0.id == id }
    }

    private func fallback(_ detail: JobDetailState) -> JobRow? {
        JobRow(id: detail.jobId, status: detail.status, title: detail.jobId)
    }
}
