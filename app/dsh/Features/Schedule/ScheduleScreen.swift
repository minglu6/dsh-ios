import SwiftUI
import DSHProtocol

struct ScheduleScreen: View {
    @ObservedObject var model: AppModel
    @State private var rows: [JSONValue] = []
    @State private var selected: JSONValue?
    @State private var query = ""
    @State private var filter = "all"
    @State private var loading = false
    @State private var loaded = false
    @State private var error: String?
    @State private var notice: String?
    @State private var now = Date()

    var body: some View {
        if let selected {
            ScheduleDetailView(
                model: model,
                row: rows.first { $0["id"] == selected["id"] && $0["sessionId"] == selected["sessionId"] } ?? selected,
                authoritative: rows.contains { $0["id"] == selected["id"] && $0["sessionId"] == selected["sessionId"] } && loaded,
                catalogError: error,
                loading: loading,
                onBack: { self.selected = nil },
                onRefresh: { Task { await reload() } },
                onCommitted: { record in
                    rows = rows.map { $0["id"] == record["id"] ? record : $0 }
                    self.selected = record
                    Task { await reload() }
                },
                onDeleted: {
                    rows = rows.filter { $0["id"] != selected["id"] }
                    self.selected = nil
                    notice = L.t("任务已删除", "Task deleted.")
                    Task { await reload() }
                }
            )
        } else {
            catalog
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("scheduleScreen")
        }
    }

    private var catalog: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.pop() } label: { OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink) }
                Text(L.automation()).font(PhoneTypography.headline).foregroundStyle(T.ink)
                Spacer()
                Button(SchedulePagePolicy.headerNewLabel(english: L.en)) { newTask() }
                    .foregroundStyle(T.ink)
                    .disabled(!model.isOnline)
                    .accessibilityIdentifier("scheduleNew")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(T.surface)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        tab("all", SchedulePagePolicy.tabLabel("all", english: L.en))
                        tab("active", SchedulePagePolicy.tabLabel("active", english: L.en))
                        tab("inactive", SchedulePagePolicy.tabLabel("inactive", english: L.en))
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    HStack {
                        TextField(L.t("搜索自动化任务", "Search automation tasks"), text: $query)
                        if !query.isEmpty {
                            Button(L.clearSearch()) { query = "" }
                                .font(PhoneTypography.caption)
                                .foregroundStyle(T.text3)
                        }
                    }
                    .padding(10)
                    .background(T.fill, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 18)
                    if let notice { Text(notice).foregroundStyle(T.text3).padding(.horizontal, 18) }
                    if let error {
                        settingsMessage(error, error: true)
                        Button(L.retry()) { Task { await reload() } }
                            .foregroundStyle(T.ink)
                            .padding(.horizontal, 18)
                    }
                    if loading { ProgressView().frame(maxWidth: .infinity).padding() }
                    if loaded && visible.isEmpty {
                        VStack(spacing: 10) {
                            OfficialGlyph(kind: .clockOutline, size: 36, color: T.caption)
                            Text(emptyText)
                                .font(PhoneTypography.subheadline)
                                .foregroundStyle(T.text3)
                                .multilineTextAlignment(.center)
                            Button(SchedulePagePolicy.emptyActionLabel(english: L.en)) { newTask() }
                                .foregroundStyle(T.ink)
                                .disabled(!model.isOnline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                    ForEach(Array(visible.enumerated()), id: \.offset) { _, row in
                        Button { selected = row } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(row["title"].str() ?? "").foregroundStyle(T.ink).lineLimit(2)
                                Text(scheduleSummary(row)).font(PhoneTypography.caption).foregroundStyle(T.text3)
                                Text(row["status"].str() == "active"
                                     ? L.t("下次计划时间：", "Next scheduled time: ") + scheduleNext(row["scheduledAt"].str(), zone: row["timeZone"].str(), now: now)
                                     : L.t("已结束", "Inactive"))
                                .font(PhoneTypography.caption).foregroundStyle(T.text3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                        Divider().padding(.horizontal, 18)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        .task(id: "\(model.activeId ?? "")-\(model.scheduleCatalogRevision)") { await reload() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private var visible: [JSONValue] {
        rows.filter { row in
            (filter == "all" || row["status"].str() == filter) &&
            ["title", "prompt", "sessionId"].contains { (row[$0].str() ?? "").localizedCaseInsensitiveContains(query.trimmingCharacters(in: .whitespaces)) || query.trimmingCharacters(in: .whitespaces).isEmpty }
        }
    }

    private var emptyText: String {
        SchedulePagePolicy.emptyBody(hasRows: !rows.isEmpty, filter: filter, query: query, english: L.en)
    }

    private func tab(_ value: String, _ label: String) -> some View {
        Button(label) { filter = value }
            .foregroundStyle(filter == value ? T.ink : T.text3)
            .font(PhoneTypography.subheadline.weight(filter == value ? .semibold : .regular))
    }

    private func newTask() {
        model.pop()
        model.showDrawer = false
        if model.chat == nil, let first = model.sessions.first {
            model.openSession(first.sessionId)
        }
    }

    private func reload() async {
        guard !loading, model.isOnline else { return }
        loading = true
        defer { loading = false }
        do {
            guard model.ops.contains("schedule.catalog") else { throw PocketError(code: "unavailable", message: L.unavailable()) }
            guard let client = model.clientOrNull() else {
                throw PocketError(code: "transport", message: L.t("连接已断开，请重新连接。", "Disconnected. Reconnect to continue."))
            }
            rows = try scheduleCatalogRows(try await client.scheduleCatalog())
            loaded = true
            error = nil
        } catch {
            self.error = scheduleFailureMessage((error as? PocketError)?.message ?? error.localizedDescription, en: L.en)
        }
    }
}

private struct ScheduleDetailView: View {
    @ObservedObject var model: AppModel
    let row: JSONValue
    let authoritative: Bool
    let catalogError: String?
    let loading: Bool
    var onBack: () -> Void
    var onRefresh: () -> Void
    var onCommitted: (JSONValue) -> Void
    var onDeleted: () -> Void

    @State private var tab = 0
    @State private var editing = false
    @State private var title = ""
    @State private var prompt = ""
    @State private var initial: ScheduleTimingDraft
    @State private var draft: ScheduleTimingDraft
    @State private var busy = false
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var now = Date()

    init(model: AppModel, row: JSONValue, authoritative: Bool, catalogError: String?, loading: Bool, onBack: @escaping () -> Void, onRefresh: @escaping () -> Void, onCommitted: @escaping (JSONValue) -> Void, onDeleted: @escaping () -> Void) {
        self.model = model
        self.row = row
        self.authoritative = authoritative
        self.catalogError = catalogError
        self.loading = loading
        self.onBack = onBack
        self.onRefresh = onRefresh
        self.onCommitted = onCommitted
        self.onDeleted = onDeleted
        let timing = scheduleTimingDraft(row)
        _initial = State(initialValue: timing)
        _draft = State(initialValue: timing)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink) }
                Text(row["title"].str() ?? "").font(PhoneTypography.headline).foregroundStyle(T.ink).lineLimit(1)
                Spacer()
                if editing {
                    Button(busy ? L.saving() : L.save(), action: save)
                        .disabled(busy || !model.isOnline || !changed || !authoritative || !isActive || !model.ops.contains("schedule.update"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(T.surface)
            HStack(spacing: 12) {
                Button(L.t("规则", "Rules")) { tab = 0 }.foregroundStyle(tab == 0 ? T.ink : T.text3)
                Button(L.t("任务运行记录", "Records")) { tab = 1 }.foregroundStyle(tab == 1 ? T.ink : T.text3)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let catalogError { settingsMessage(catalogError, error: true) }
                    if !authoritative && !loading { settingsMessage(L.t("任务已不可用，可能已被删除", "Task unavailable. It may have been deleted."), error: true) }
                    if let error { settingsMessage(error, error: true) }
                    if tab == 1 {
                        ScheduleHistoryView(model: model, sessionId: sessionId, id: id, zone: row["timeZone"].str())
                    } else {
                        Text(isActive ? L.t("已开启", "Enabled") : L.t("已结束", "Inactive")).foregroundStyle(T.text3)
                        if editing {
                            TextField(L.t("自动化任务名称", "Automation task name"), text: $title).disabled(!canEdit)
                            TextEditor(text: $prompt).frame(minHeight: 80).disabled(!canEdit)
                            timingEditor
                        } else {
                            Text(L.t("自动化任务内容", "Automation task instruction")).font(PhoneTypography.caption).foregroundStyle(T.text3)
                            Text(row["prompt"].str() ?? "").foregroundStyle(T.ink)
                            Button(L.t("编辑", "Edit")) {
                                editing = true
                                title = row["title"].str() ?? ""
                                prompt = row["prompt"].str() ?? ""
                                initial = scheduleTimingDraft(row)
                                draft = initial
                            }
                            .disabled(!model.isOnline || !authoritative || !isActive || loading || !model.ops.contains("schedule.update"))
                        }
                        Text(L.t("下次计划时间：", "Next scheduled time: ") + scheduleNext(row["scheduledAt"].str(), zone: row["timeZone"].str(), now: now))
                            .font(PhoneTypography.caption).foregroundStyle(T.text3)
                        Button {
                            if let sessionId = row["sessionId"].str() {
                                model.openSession(sessionId)
                                model.pop()
                            }
                        } label: {
                            Text(L.t("打开会话", "Open session"))
                        }
                        if model.ops.contains("schedule.delete") {
                            Button(L.delete(), role: .destructive) { confirmDelete = true }
                                .disabled(!model.isOnline || busy)
                        }
                    }
                }
                .padding(18)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        .confirmationDialog(L.t("删除此任务？", "Delete this task?"), isPresented: $confirmDelete) {
            Button(L.delete(), role: .destructive, action: deleteTask)
            Button(L.cancel(), role: .cancel) {}
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private var id: String { row["id"].str() ?? "" }
    private var sessionId: String { row["sessionId"].str() ?? "" }
    private var isActive: Bool { row["status"].str() == "active" }
    private var changed: Bool { title.trimmingCharacters(in: .whitespaces) != (row["title"].str() ?? "") || prompt.trimmingCharacters(in: .whitespaces) != (row["prompt"].str() ?? "") || draft != initial }
    private var canEdit: Bool { model.isOnline && !busy && authoritative && isActive && model.ops.contains("schedule.update") }

    @ViewBuilder
    private var timingEditor: some View {
        Picker(L.t("重复", "Repeat"), selection: Binding(get: { draft.kind }, set: { draft = draft.copy(kind: $0) })) {
            Text(L.t("仅一次", "Once")).tag("once")
            Text(L.t("每天", "Every day")).tag("daily")
            Text(L.t("每周", "Weekly")).tag("weekly")
            Text(L.t("固定间隔", "Fixed interval")).tag("every")
            Text(L.t("自定义", "Custom")).tag("cron")
        }
        TextField(L.t("时间", "Time"), text: Binding(get: { draft.time }, set: { draft = draft.copy(time: $0) }))
        TextField(L.t("时区", "Time zone"), text: Binding(get: { draft.zone }, set: { draft = draft.copy(zone: $0) }))
        if draft.kind == "once" {
            TextField(L.t("日期", "Date"), text: Binding(get: { draft.date }, set: { draft = draft.copy(date: $0) }))
        }
        if draft.kind == "every" {
            TextField(L.t("间隔", "Interval"), text: Binding(get: { draft.quantity }, set: { draft = draft.copy(quantity: $0) }))
            Picker("", selection: Binding(get: { draft.unit }, set: { draft = draft.copy(unit: $0) })) {
                Text(L.t("秒", "seconds")).tag("second")
                Text(L.t("分钟", "minutes")).tag("minute")
                Text(L.t("小时", "hours")).tag("hour")
            }
        }
        if draft.kind == "weekly" {
            HStack {
                ForEach(1...7, id: \.self) { day in
                    Button {
                        var days = draft.weekdays
                        if days.contains(day) { days.remove(day) } else { days.insert(day) }
                        draft = draft.copy(weekdays: days)
                    } label: {
                        Text(weekdayLabel(day))
                            .font(PhoneTypography.caption)
                            .foregroundStyle(draft.weekdays.contains(day) ? T.onPrimary : T.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(draft.weekdays.contains(day) ? T.primaryButton : T.fill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if draft.kind == "cron" {
            TextField("cron", text: Binding(get: { draft.expression }, set: { draft = draft.copy(expression: $0) }))
        }
    }

    private func save() {
        guard !busy else { return }
        busy = true
        error = nil
        Task {
            do {
                let request = try scheduleUpdateRequest(row, title: title, prompt: prompt, initial: initial, draft: draft)
                guard let client = model.clientOrNull() else {
                    throw PocketError(code: "transport", message: L.t("连接已断开，请重新连接。", "Disconnected. Reconnect to continue."))
                }
                let updated = try scheduleUpdatedRecord(try await client.scheduleUpdate(args: request))
                var merged = row.obj() ?? [:]
                for (key, value) in updated.obj() ?? [:] { merged[key] = value }
                merged["sessionId"] = .string(sessionId)
                editing = false
                onCommitted(.object(merged))
            } catch {
                self.error = scheduleFailureMessage((error as? PocketError)?.code ?? error.localizedDescription, en: L.en)
                if ((error as? PocketError)?.code ?? "").hasPrefix("schedule_") { onRefresh() }
            }
            busy = false
        }
    }

    private func deleteTask() {
        guard let client = model.clientOrNull() else { return }
        busy = true
        Task {
            do {
                let result = try await client.scheduleDelete(sessionId: sessionId, id: id)
                try scheduleConfirmDeleted(result)
                onDeleted()
            } catch {
                self.error = scheduleFailureMessage((error as? PocketError)?.code ?? error.localizedDescription, en: L.en)
            }
            busy = false
        }
    }
}

private struct ScheduleHistoryView: View {
    @ObservedObject var model: AppModel
    let sessionId: String
    let id: String
    let zone: String?
    @State private var items: [JSONValue] = []
    @State private var error: String?
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error { settingsMessage(error, error: true) }
            if loading { ProgressView() }
            if items.isEmpty && !loading {
                Text(L.t("暂无运行记录", "No run records yet")).foregroundStyle(T.text3)
            }
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading) {
                    Text(item["status"].str() ?? item["outcome"].str() ?? "").foregroundStyle(T.ink)
                    Text(scheduleStamp(item["scheduledAt"].str() ?? item["at"].str(), zone: zone)).font(PhoneTypography.caption).foregroundStyle(T.text3)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard model.ops.contains("schedule.history"), let client = model.clientOrNull() else {
            loading = false
            return
        }
        loading = true
        do {
            items = try scheduleHistoryRows(try await client.scheduleHistory(sessionId: sessionId, id: id))
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

private func weekdayLabel(_ day: Int) -> String {
    let labels = L.en
        ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        : ["一", "二", "三", "四", "五", "六", "日"]
    return labels[day - 1]
}

private func scheduleSummary(_ row: JSONValue) -> String {
    let kind = row["kind"].str() ?? ""
    switch kind {
    case "every":
        if let seconds = row["everySeconds"].long() {
            return L.t("每 \(seconds) 秒", "Every \(seconds) seconds")
        }
    case "daily": return L.t("每天 \(row["time"].str() ?? "")", "Every day \(row["time"].str() ?? "")")
    case "weekly": return L.t("每周 \(row["time"].str() ?? "")", "Weekly \(row["time"].str() ?? "")")
    case "cron": return row["expression"].str() ?? "cron"
    default: break
    }
    return scheduleStamp(row["scheduledAt"].str(), zone: row["timeZone"].str())
}

private func scheduleStamp(_ value: String?, zone: String?) -> String {
    guard let value else { return "—" }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    guard let date else { return value }
    let out = DateFormatter()
    out.dateFormat = "yyyy-MM-dd HH:mm:ss z"
    if let zone, let tz = TimeZone(identifier: zone) { out.timeZone = tz }
    return out.string(from: date)
}

private func scheduleNext(_ value: String?, zone: String?, now: Date) -> String {
    let stamp = scheduleStamp(value, zone: zone)
    guard let distance = scheduleRelativeTime(value, now: now) else { return stamp }
    let unit: String
    switch distance.unit {
    case "day": unit = L.t("天", distance.value == 1 ? "day" : "days")
    case "hour": unit = L.t("小时", distance.value == 1 ? "hour" : "hours")
    case "minute": unit = L.t("分钟", distance.value == 1 ? "minute" : "minutes")
    default: unit = L.t("秒", distance.value == 1 ? "second" : "seconds")
    }
    let relative: String
    switch distance.direction {
    case 0: relative = L.t("现在到期", "Due now")
    case 1: relative = L.t("\(distance.value)\(unit)后", "in \(distance.value) \(unit)")
    default: relative = L.t("已逾期 \(distance.value)\(unit)", "\(distance.value) \(unit) overdue")
    }
    return "\(stamp) (\(relative))"
}
