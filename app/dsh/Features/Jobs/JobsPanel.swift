import Combine
import SwiftUI
import UIKit
import DSHProtocol

/// A host/session change replaces the entire action state, including pending receipts.
struct JobsAction: View {
    @ObservedObject var model: AppModel
    let sessionId: String

    var body: some View {
        JobsActionContent(model: model, scope: JobsScope(hostId: model.activeId, sessionId: sessionId))
            .id(JobsScope(hostId: model.activeId, sessionId: sessionId))
    }
}

private struct JobsActionContent: View {
    @ObservedObject var model: AppModel
    let scope: JobsScope
    @State private var open = false
    @State private var state = JobListState()

    private var visibleRows: [JobRow] { state.visibleRows(model.jobs ?? []) }
    private var chip: JobChip? {
        JobsActionLabel.chip(jobs: model.jobs == nil ? nil : visibleRows, failed: model.jobsFailed)
    }

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: CGFloat(jobsActionWatchAnchorPoints), height: CGFloat(jobsActionWatchAnchorPoints))
                .accessibilityHidden(true)
            if let chip {
                let tint = chip == .unavailable ? T.err : T.text3
                Button { open.toggle() } label: {
                    HStack(spacing: 3) {
                        if case .live = chip {
                            SidebarActivitySpinner(color: T.text3)
                                .frame(width: 14, height: 14)
                                .accessibilityHidden(true)
                        }
                        Text(JobsActionLabel.text(chip, en: L.en))
                            .font(.system(size: 12))
                            .lineSpacing(0)
                            .lineLimit(1)
                            .frame(height: 18)
                            .padding(.horizontal, 5)
                        OfficialGlyph(kind: .jobsChevron, size: CGFloat(jobsActionTriggerIconSizePoints), color: tint)
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(JobsActionLabel.text(chip, en: L.en))
                .accessibilityIdentifier(jobsActionTriggerSymbol())
                .popover(isPresented: $open, attachmentAnchor: .rect(.bounds), arrowEdge: jobsPopoverArrowPointsDown ? .top : .bottom) {
                    JobsPanel(model: model, state: $state, scope: scope, showsNavigationHeader: false) { open = false }
                        .frame(width: CGFloat(jobsPopoverWidth(screenWidth: UIScreen.main.bounds.width)))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxHeight: CGFloat(jobsPopoverMaxHeight(screenHeight: UIScreen.main.bounds.height)), alignment: .top)
                        .modifier(PopoverCompactAdaptation())
                }
            }
        }
        .task(id: model.canShowJobs) {
            guard jobsActionShouldWatch(online: model.isOnline, hasListOp: model.ops.contains("jobs.list")) else { return }
            guard let sessionId = scope.sessionId else { return }
            await model.retainJobsWatch(hostId: scope.hostId, sessionId: sessionId, available: model.canShowJobs)
        }
        .onChange(of: visibleRows.isEmpty) { empty in
            if empty && !model.jobsFailed { open = false }
        }
    }
}

/// The full Host panel retains the same list/output/stop surface.
struct JobsHostPanel: View {
    @ObservedObject var model: AppModel
    var onDismiss: (() -> Void)?

    var body: some View {
        JobsHostPanelContent(model: model, scope: JobsScope(hostId: model.activeId, sessionId: model.chat?.sessionId), onDismiss: onDismiss)
            .id(JobsScope(hostId: model.activeId, sessionId: model.chat?.sessionId))
    }
}

private struct JobsHostPanelContent: View {
    @ObservedObject var model: AppModel
    let scope: JobsScope
    var onDismiss: (() -> Void)?
    @State private var state = JobListState()

    var body: some View {
        JobsPanel(model: model, state: $state, scope: scope, onDismiss: onDismiss)
    }
}

/// Desktop `JobListAction`: live / settled sections, inline output, two-press kill.
struct JobsPanel: View {
    @ObservedObject var model: AppModel
    @Binding var state: JobListState
    let scope: JobsScope
    var showsNavigationHeader: Bool = true
    var onDismiss: (() -> Void)?

    @State private var nowMs = Int64(Date().timeIntervalSince1970 * 1000)
    private var sessionId: String? { scope.sessionId }
    private var online: Bool { model.isOnline }
    private var canKill: Bool { online && model.ops.contains("jobs.kill") }
    private var rows: [JobRow] { state.visibleRows(model.jobs ?? []) }
    private var liveRows: [JobRow] { rows.filter(\.isLive) }
    private var settledRows: [JobRow] { rows.filter { !$0.isLive } }
    private var settledExpanded: Bool {
        jobsSettledSectionExpanded(explicit: state.settledOpen, liveCount: liveRows.count)
    }
    private var clockRuns: Bool {
        jobsPopoverClockRuns(open: true, liveCount: liveRows.count) || state.killPhase != .idle
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsNavigationHeader {
                header(L.backgroundJobs()) {
                    if let onDismiss { onDismiss() } else { model.pop() }
                }
            }
            if model.jobs == nil && !model.jobsFailed {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
            if let err = model.jobsPanelError {
                Text(err).foregroundStyle(T.err).padding(22)
            }
            if showsNavigationHeader {
                ScrollView { jobList }
            } else {
                JobsPopoverRoster(maxHeight: CGFloat(jobsPopoverMaxHeight(screenHeight: UIScreen.main.bounds.height))) {
                    jobList
                }
            }
        }
        .background(T.bg)
        .task(id: "panel-\(model.activeId ?? "")-\(sessionId ?? "")-\(model.canShowJobs)") {
            guard let sessionId else { return }
            await model.retainJobsWatch(hostId: scope.hostId, sessionId: sessionId, available: model.canShowJobs)
        }
        .background(clockSubscription)
        .task(id: state.killPhase) {
            let deadline: Int64
            switch state.killPhase {
            case .armed(_, let until), .failed(_, let until): deadline = until
            default: return
            }
            let delay = max(0, deadline - Int64(Date().timeIntervalSince1970 * 1000))
            do { try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000) } catch { return }
            state.reconcile(model.jobs ?? [], nowMs: Int64(Date().timeIntervalSince1970 * 1000))
        }
        .onAppear {
            nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            state.reconcile(model.jobs ?? [], nowMs: nowMs)
            updateObservation()
        }
        .onChange(of: model.jobs) { jobs in
            state.reconcile(jobs ?? [], nowMs: Int64(Date().timeIntervalSince1970 * 1000))
        }
        .onChange(of: state.expandedKey) { _ in updateObservation() }
        .onDisappear {
            if JobsScope(hostId: model.activeId, sessionId: model.chat?.sessionId) == scope {
                model.clearJobSelection()
            }
        }
    }

    @ViewBuilder
    private var clockSubscription: some View {
        if clockRuns {
            Color.clear
                .frame(width: 0, height: 0)
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                    nowMs = Int64(date.timeIntervalSince1970 * 1000)
                    state.reconcile(model.jobs ?? [], nowMs: nowMs)
                }
                .accessibilityHidden(true)
        }
    }

    private func updateObservation() {
        guard JobsScope(hostId: model.activeId, sessionId: model.chat?.sessionId) == scope else { return }
        if let job = rows.first(where: { $0.id == state.expandedKey && $0.isObservable }) {
            model.selectJob(job)
        } else {
            model.clearJobSelection()
        }
    }

    private var jobList: some View {
        VStack(alignment: .leading, spacing: 1) {
            if rows.isEmpty && model.jobs != nil && !model.jobsFailed && model.jobsPanelError == nil {
                Text(L.jobsZero()).foregroundStyle(T.text3).padding(22)
            }
            if !liveRows.isEmpty {
                sectionHeader(first: true) {
                    Text(jobSectionLive(english: L.en))
                        .frame(height: 16)
                }
                ForEach(liveRows) { job in jobBlock(job) }
            }
            if !settledRows.isEmpty {
                sectionHeader(first: liveRows.isEmpty) {
                    HStack(spacing: 0) {
                        Button {
                            state.settledOpen = jobsSettledSectionToggled(explicit: state.settledOpen, liveCount: liveRows.count)
                        } label: {
                            HStack(spacing: 3) {
                                OfficialGlyph(kind: .chevronDown, size: CGFloat(jobsRowChevronIconSizePoints), color: T.text3)
                                    .rotationEffect(.degrees(settledExpanded ? jobsSettledChevronOpenRotationDegrees : jobsSettledChevronCollapsedRotationDegrees))
                                Text(jobSectionSettled(count: settledRows.count, english: L.en))
                                    .frame(height: 16)
                            }
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .contain)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("jobs.settled.toggle")
                        .accessibilityValue(settledExpanded ? "expanded" : "collapsed")
                        Spacer(minLength: 0)
                        Button(jobSectionClear(english: L.en)) {
                            state.clearSettled(model.jobs ?? [])
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .accessibilityIdentifier("jobs.settled.clear")
                    }
                }
                if settledExpanded {
                    ForEach(settledRows) { job in jobBlock(job) }
                }
            }
        }
        .padding(4)
        .accessibilityIdentifier("jobs.roster")
    }

    private func sectionHeader<Content: View>(first: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: 11))
            .foregroundStyle(T.text3)
            .padding(.top, 4)
            .padding(.bottom, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                if !first { Rectangle().fill(T.borderL1).frame(height: 0.5) }
            }
            .padding(.horizontal, 4)
            .padding(.top, first ? 0 : 4)
            .padding(.bottom, 1)
    }

    private func jobBlock(_ job: JobRow) -> some View {
        let expanded = state.expandedKey == job.id
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                if job.isObservable {
                    Button {
                        state.expandedKey = jobsToggledExpandedKey(current: state.expandedKey, jobId: job.id)
                    } label: {
                        jobRow(job, expanded: expanded)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(L.t(
                        expanded ? "收起 \(job.title) 的实时输出" : "展开 \(job.title) 的实时输出",
                        expanded ? "Hide live output of \(job.title)" : "Show live output of \(job.title)"
                    ))
                    .accessibilityIdentifier("jobs.row.\(job.id)")
                    .accessibilityValue(expanded ? "expanded" : "collapsed")
                } else {
                    jobRow(job, expanded: false)
                        .accessibilityIdentifier("jobs.row.\(job.id)")
                }
                if job.canKill { killButton(job) }
            }
            .padding(.leading, job.isLive ? 2 : 0)
            .padding(.trailing, job.isLive ? 8 : 0)
            .padding(.vertical, job.isLive ? 4 : 0)
            .background(job.isLive ? T.fill : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            if expanded, let detail = model.jobDetail, detail.jobId == job.id {
                outputPanel(detail, job: job)
            }
        }
    }

    private func jobRow(_ job: JobRow, expanded: Bool) -> some View {
        HStack(alignment: .center, spacing: 6) {
            statusDot(job.status)
            if job.isLive {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(T.ink)
                        .lineLimit(1)
                        .frame(height: 17)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        kindBadge(job)
                        if let detail = job.qualifier { qualifier(detail) }
                        durationCell(job)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                kindBadge(job)
                Text(job.title)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(T.text3)
                    .lineLimit(1)
                    .frame(height: 17)
                    .frame(maxWidth: .infinity, alignment: .leading)
                qualifier(jobRowStatusText(job, english: L.en))
                durationCell(job)
            }
            if job.isObservable {
                OfficialGlyph(kind: .chevronDown, size: CGFloat(jobsRowChevronIconSizePoints), color: T.text3)
                    .rotationEffect(.degrees(expanded ? jobsRowChevronOpenRotationDegrees : 0))
                    .frame(width: 20, height: 20)
                    .background(T.bg, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(T.border, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func kindBadge(_ job: JobRow) -> some View {
        Text(job.kind)
            .font(.system(size: 10))
            .foregroundStyle(T.text2)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(job.isLive ? T.bg : T.fill, in: RoundedRectangle(cornerRadius: 2))
    }

    private func qualifier(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(T.text3)
            .lineLimit(1)
            .frame(height: 16)
            .truncationMode(.tail)
            .frame(maxWidth: CGFloat(jobsPopoverWidth(screenWidth: UIScreen.main.bounds.width)) * 0.6, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func durationCell(_ job: JobRow) -> some View {
        let duration = jobDurationText(elapsedMs: jobElapsedMs(job, nowMs: nowMs), english: L.en)
        return Text(duration)
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(T.text3)
            .lineLimit(1)
            .frame(height: 18)
            .fixedSize()
            .accessibilityLabel(L.t(job.isLive ? "已运行 \(duration)" : "耗时 \(duration)", job.isLive ? "Running for \(duration)" : "Took \(duration)"))
    }

    @ViewBuilder
    private func statusDot(_ status: String) -> some View {
        if status == "running" {
            SidebarActivitySpinner(color: T.text3)
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
        } else {
            Circle().fill(dotColor(status))
                .frame(width: 6, height: 6)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
        }
    }

    private func killButton(_ job: JobRow) -> some View {
        let phase = state.killPhase.key == job.id ? state.killPhase : .idle
        let armed = phase.stateName == "armed"
        let danger = armed || phase.stateName == "failed"
        let title: String = {
            switch phase {
            case .armed: return jobKillConfirmLabel(english: L.en)
            case .failed: return jobKillFailedLabel(english: L.en)
            default: return jobKillStopLabel(label: job.title, english: L.en)
            }
        }()
        return Button {
            let clock = Int64(Date().timeIntervalSince1970 * 1000)
            state.killPhase = jobKillPress(phase: state.killPhase, key: job.id, nowMs: clock)
            if case .pending = state.killPhase {
                let requestScope = scope
                model.killJob(jobId: job.id) { ok in
                    guard JobsScope(hostId: model.activeId, sessionId: model.chat?.sessionId) == requestScope else { return }
                    state.killPhase = jobKillAdmit(
                        phase: state.killPhase, key: job.id, ok: ok,
                        nowMs: Int64(Date().timeIntervalSince1970 * 1000)
                    )
                    state.reconcile(model.jobs ?? [], nowMs: Int64(Date().timeIntervalSince1970 * 1000))
                }
            }
        } label: {
            HStack(spacing: 4) {
                OfficialGlyph(kind: .stopFill, size: 10, color: danger ? T.err : T.text2)
                if armed { Text(jobKillConfirmAction(english: L.en)).font(.system(size: 11)).frame(height: 18) }
            }
            .foregroundStyle(danger ? T.err : T.text2)
            .padding(.horizontal, armed ? 7 : 0)
            .frame(minWidth: 20, minHeight: 20)
            .background(armed ? T.err.opacity(0.12) : T.bg, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(armed ? T.err.opacity(0.45) : T.border, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .disabled(!canKill || phase.stateName == "pending")
        .accessibilityLabel(title)
        .accessibilityIdentifier("jobs.stop.\(job.id)")
        .accessibilityValue(phase.stateName)
    }

    private func outputPanel(_ detail: JobDetailState, job: JobRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let error = detail.error {
                Text(L.t("实时输出流中断：\(error)", "Live output stream interrupted: \(error)"))
                    .font(.system(size: 11)).foregroundStyle(T.err)
                Button(L.retry()) { model.retryJobFollow() }.disabled(!online)
            }
            HStack(alignment: .top, spacing: 8) {
                Text(job.title)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                Button(L.t("复制", "Copy")) { UIPasteboard.general.string = job.title }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
            }
            .foregroundStyle(T.text2)
            JobsPopoverRoster(maxHeight: 288) {
                VStack(alignment: .leading, spacing: 0) {
                    if detail.output.isEmpty && detail.error == nil {
                        Text(L.t("（无输出）", "(no output)")).foregroundStyle(T.text3)
                    } else {
                        ForEach(Array(detail.output.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(T.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(T.fill, in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .accessibilityIdentifier("jobs.output.\(job.id)")
    }

    private func dotColor(_ status: String) -> Color {
        switch status {
        case "running": return T.text3
        case "stopping", "killed": return T.warnText
        case "failed": return T.err
        case "completed": return T.ok
        default: return T.text3
        }
    }
}

/// One roster identity: measure height, scroll only when taller than the
/// desktop `MenuSurface` viewport cap. `ViewThatFits` swapped `jobList` for
/// `ScrollView { jobList }` and dropped the first 「已结束」 press.
private struct JobsPopoverRoster<Content: View>: View {
    var maxHeight: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content()
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: JobsRosterHeightKey.self, value: geo.size.height)
                    }
                )
        }
        .frame(maxHeight: min(measuredHeight, maxHeight), alignment: .top)
        .onPreferenceChange(JobsRosterHeightKey.self) { next in
            if next != contentHeight { contentHeight = next }
        }
    }

    private var measuredHeight: CGFloat {
        contentHeight > 0 ? contentHeight : maxHeight
    }
}

private struct JobsRosterHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
