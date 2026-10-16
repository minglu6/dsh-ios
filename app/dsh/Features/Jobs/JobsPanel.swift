import Combine
import SwiftUI
import DSHProtocol

/// Header chip. Retains the shared jobs poll for this conversation; scenePhase is not part of the task id.
struct JobsAction: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    @State private var open = false

    private var available: Bool { model.canShowJobs }

    var body: some View {
        ZStack {
            Color.clear
                .frame(
                    width: CGFloat(jobsActionWatchAnchorPoints),
                    height: CGFloat(jobsActionWatchAnchorPoints)
                )
                .accessibilityHidden(true)
            if let chip = JobsActionLabel.chip(jobs: model.jobs, failed: model.jobsFailed) {
                Button(action: { open.toggle() }) {
                    HStack(spacing: 6) {
                        if case .live = chip {
                            Circle().fill(T.accent).frame(width: 6, height: 6)
                        }
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
                .popover(isPresented: $open, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    JobsPanel(model: model) { open = false }
                        .frame(width: 320, height: 420)
                        .modifier(PopoverCompactAdaptation())
                }
            }
        }
        .task(id: "\(model.activeId ?? "")-\(sessionId)-\(available)") {
            guard jobsActionShouldWatch(online: model.isOnline, hasListOp: model.ops.contains("jobs.list")) else { return }
            await model.retainJobsWatch(hostId: model.activeId, sessionId: sessionId, available: available)
        }
    }
}

/// Desktop `JobListAction`: live / settled sections, inline output, two-press kill.
struct JobsPanel: View {
    @ObservedObject var model: AppModel
    var onDismiss: (() -> Void)?

    @State private var expandedKey: String?
    @State private var settledOpen: Bool?
    @State private var clearedKeys: Set<String> = []
    @State private var killPhase: JobKillPhase = .idle
    @State private var nowMs = Int64(Date().timeIntervalSince1970 * 1000)

    private var sessionId: String? { model.chat?.sessionId }
    private var online: Bool { model.isOnline }
    private var canKill: Bool { online && model.ops.contains("jobs.kill") }
    private var rows: [JobRow] { orderedJobRows(model.jobs ?? []) }
    private var liveRows: [JobRow] { rows.filter(\.isLive) }
    private var settledRows: [JobRow] { rows.filter { !$0.isLive && !clearedKeys.contains($0.id) } }
    private var settledExpanded: Bool { settledOpen ?? liveRows.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header(L.backgroundJobs()) {
                if let onDismiss { onDismiss() } else { model.pop() }
            }
            if model.jobs == nil && !model.jobsFailed {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
            if let err = model.jobsPanelError {
                Text(err).foregroundStyle(T.err).padding(22)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if liveRows.isEmpty && settledRows.isEmpty && model.jobs != nil && !model.jobsFailed && model.jobsPanelError == nil {
                        Text(L.jobsZero()).foregroundStyle(T.text3).padding(22)
                    }
                    if !liveRows.isEmpty {
                        Text(jobSectionLive(english: L.en))
                            .font(.caption)
                            .foregroundStyle(T.text3)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        ForEach(liveRows) { job in
                            jobBlock(job)
                        }
                    }
                    if !settledRows.isEmpty {
                        HStack {
                            Button {
                                settledOpen = !settledExpanded
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: settledExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 11))
                                    Text(jobSectionSettled(count: settledRows.count, english: L.en))
                                }
                                .font(.caption)
                                .foregroundStyle(T.text3)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(jobSectionClear(english: L.en)) {
                                clearedKeys.formUnion(settledRows.map(\.id))
                                if let expandedKey, settledRows.contains(where: { $0.id == expandedKey }) {
                                    self.expandedKey = nil
                                    model.clearJobSelection()
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(T.text2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        if settledExpanded {
                            ForEach(settledRows) { job in
                                jobBlock(job)
                            }
                        }
                    }
                }
            }
        }
        .background(T.bg)
        .task(id: "panel-\(model.activeId ?? "")-\(sessionId ?? "")-\(model.canShowJobs)") {
            guard let sessionId else { return }
            await model.retainJobsWatch(hostId: model.activeId, sessionId: sessionId, available: model.canShowJobs)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            nowMs = Int64(date.timeIntervalSince1970 * 1000)
            killPhase = jobKillTick(
                phase: killPhase,
                nowMs: nowMs,
                runningKeys: Set(liveRows.filter { $0.status == "running" }.map(\.id))
            )
        }
        .onChange(of: rows.map(\.id).joined(separator: ",")) { _ in
            if let expandedKey, !rows.contains(where: { $0.id == expandedKey }) {
                self.expandedKey = nil
                model.clearJobSelection()
            }
        }
        .onDisappear { model.clearJobSelection() }
    }

    @ViewBuilder
    private func jobBlock(_ job: JobRow) -> some View {
        let expanded = expandedKey == job.id
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                if job.isObservable {
                    Button {
                        if expanded {
                            expandedKey = nil
                            model.clearJobSelection()
                        } else {
                            expandedKey = job.id
                            model.selectJob(job)
                        }
                    } label: {
                        jobRow(job, expanded: expanded)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        L.t(
                            expanded ? "收起 \(job.title) 的实时输出" : "展开 \(job.title) 的实时输出",
                            expanded ? "Hide live output of \(job.title)" : "Show live output of \(job.title)"
                        )
                    )
                } else {
                    jobRow(job, expanded: false)
                }
                if job.canKill {
                    killButton(job)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            if expanded, let detail = model.jobDetail, detail.jobId == job.id {
                outputPanel(detail, job: job)
            }
        }
    }

    private func jobRow(_ job: JobRow, expanded: Bool) -> some View {
        let duration = jobDurationText(elapsedMs: jobElapsedMs(job, nowMs: nowMs), english: L.en)
        let status = job.qualifier ?? jobStatusLabel(job.status, english: L.en)
        return HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(dotColor(job.status))
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                if job.isLive {
                    Text(job.title).foregroundStyle(T.ink).lineLimit(1)
                    HStack(spacing: 6) {
                        if !job.kind.isEmpty {
                            Text(job.kind).font(.caption).foregroundStyle(T.text3)
                        }
                        Text(status).font(.caption).foregroundStyle(T.text3).lineLimit(1)
                        Text(duration).font(.caption.monospacedDigit()).foregroundStyle(T.text3)
                    }
                } else {
                    HStack(spacing: 6) {
                        if !job.kind.isEmpty {
                            Text(job.kind).font(.caption).foregroundStyle(T.text3)
                        }
                        Text(job.title).foregroundStyle(T.ink).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(status).font(.caption).foregroundStyle(T.text3).lineLimit(1)
                        Text(duration).font(.caption.monospacedDigit()).foregroundStyle(T.text3)
                    }
                }
            }
            if job.isObservable {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(T.text3)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func killButton(_ job: JobRow) -> some View {
        let phase = killPhase.key == job.id ? killPhase : .idle
        let title: String = {
            switch phase {
            case .armed: return jobKillConfirmLabel(english: L.en)
            case .failed: return jobKillFailedLabel(english: L.en)
            default: return jobKillStopLabel(label: job.title, english: L.en)
            }
        }()
        return Button {
            let next = jobKillPress(phase: killPhase, key: job.id, nowMs: nowMs)
            killPhase = next
            if case .pending = next {
                model.killJob(jobId: job.id) { ok in
                    killPhase = jobKillAdmit(phase: killPhase, key: job.id, ok: ok, nowMs: nowMs)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "stop.fill").font(.system(size: 9))
                if case .armed = phase {
                    Text(jobKillConfirmAction(english: L.en)).font(.caption)
                }
            }
            .foregroundStyle(phase.stateName == "failed" ? T.err : T.text2)
            .padding(.horizontal, phase.stateName == "armed" ? 10 : 8)
            .frame(minWidth: 44, minHeight: 44)
            .background(phase.stateName == "armed" ? T.err.opacity(0.16) : T.fill, in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canKill || phase.stateName == "pending")
        .accessibilityLabel(title)
    }

    private func outputPanel(_ detail: JobDetailState, job: JobRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let error = detail.error {
                Text(error).foregroundStyle(T.err)
                Button(L.retry()) { model.retryJobFollow() }.disabled(!online)
            }
            if detail.output.isEmpty && detail.error == nil {
                Text(L.waitingJobOutput()).foregroundStyle(T.text3)
            } else {
                ForEach(Array(detail.output.enumerated()), id: \.offset) { _, line in
                    Text(line.isEmpty ? " " : line)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(T.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func dotColor(_ status: String) -> Color {
        switch status {
        case "running": return T.accent
        case "stopping", "killed": return T.warnText
        case "failed": return T.err
        case "completed": return T.ok
        default: return T.text3
        }
    }
}
