import Foundation

/// The CAS value is a persisted record, never catalog metadata or a reconstructed rule.
public func scheduleSnapshot(_ row: JSONValue) throws -> JSONValue {
    guard let object = row.obj() else { throw PocketError(code: "invalid-response", message: "Missing schedule field: id") }
    var fields = ["id", "kind", "title", "prompt", "scheduledAt"]
    switch object["kind"]?.str() {
    case "at": break
    case "after": fields.append("afterSeconds")
    case "every": fields.append("everySeconds")
    case "daily": fields += ["time", "timeZone"]
    case "weekly": fields += ["time", "timeZone", "weekdays"]
    case "cron": fields += ["expression", "timeZone"]
    default: throw PocketError(code: "invalid-response", message: "Unsupported schedule kind")
    }
    var out: [String: JSONValue] = [:]
    for field in fields {
        guard let value = object[field], !value.isNull else {
            throw PocketError(code: "invalid-response", message: "Missing schedule field: \(field)")
        }
        out[field] = value
    }
    return .object(out)
}

public struct ScheduleTimingDraft: Equatable, Sendable {
    public var kind: String
    public var date: String
    public var time: String
    public var zone: String
    public var quantity: String
    public var unit: String
    public var weekdays: Set<Int>
    public var expression: String

    public init(
        kind: String,
        date: String,
        time: String,
        zone: String,
        quantity: String,
        unit: String,
        weekdays: Set<Int>,
        expression: String
    ) {
        self.kind = kind
        self.date = date
        self.time = time
        self.zone = zone
        self.quantity = quantity
        self.unit = unit
        self.weekdays = weekdays
        self.expression = expression
    }

    public func copy(
        kind: String? = nil,
        date: String? = nil,
        time: String? = nil,
        zone: String? = nil,
        quantity: String? = nil,
        unit: String? = nil,
        weekdays: Set<Int>? = nil,
        expression: String? = nil
    ) -> ScheduleTimingDraft {
        ScheduleTimingDraft(
            kind: kind ?? self.kind,
            date: date ?? self.date,
            time: time ?? self.time,
            zone: zone ?? self.zone,
            quantity: quantity ?? self.quantity,
            unit: unit ?? self.unit,
            weekdays: weekdays ?? self.weekdays,
            expression: expression ?? self.expression
        )
    }
}

public func scheduleTimingDraft(_ row: JSONValue, deviceZone: String = TimeZone.current.identifier) -> ScheduleTimingDraft {
    let zone = row["timeZone"].str() ?? deviceZone
    let wall = parseScheduleInstant(row["scheduledAt"].str()).flatMap { date in
        wallClock(date, zone: zone)
    }
    let seconds = row["everySeconds"].long() ?? 3600
    let unit: String
    if seconds % 3600 == 0 { unit = "hour" }
    else if seconds % 60 == 0 { unit = "minute" }
    else { unit = "second" }
    let days = Set((row["weekdays"].arr() ?? []).compactMap { $0.int() })
    let weekdays: Set<Int> = days.isEmpty ? [wall?.weekday ?? 1] : days
    let stored = row["kind"].str()
    let kind: String
    switch stored {
    case "at", "after": kind = "once"
    case "weekly": kind = weekdays == [1, 2, 3, 4, 5] ? "weekdays" : "weekly"
    default: kind = stored ?? { preconditionFailure("Missing schedule kind") }()
    }
    return ScheduleTimingDraft(
        kind: kind,
        date: wall?.date ?? "",
        time: row["time"].str() ?? wall?.time ?? "09:00:00.000",
        zone: zone,
        quantity: String(seconds / scheduleUnitSeconds(unit)),
        unit: unit,
        weekdays: weekdays,
        expression: row["expression"].str() ?? "0 9 * * *"
    )
}

public func schedulePickedTime(previous: String, hour: Int, minute: Int) -> String {
    precondition((0...23).contains(hour) && (0...59).contains(minute))
    let valid = parseLocalTime(previous) != nil
    let suffix = valid ? String(previous.dropFirst(5)) : ":00.000"
    return String(format: "%02d:%02d", hour, minute) + suffix
}

public func scheduleUnitSeconds(_ unit: String) -> Int64 {
    switch unit {
    case "hour": return 3600
    case "minute": return 60
    case "second": return 1
    default: preconditionFailure("Unknown interval unit")
    }
}

public func scheduleConvertQuantity(_ value: String, from: String, to: String) -> String? {
    guard let decimal = Decimal(string: value) else { return nil }
    let seconds = decimal * Decimal(scheduleUnitSeconds(from))
    var quotient = Decimal()
    var numerator = seconds
    var divisor = Decimal(scheduleUnitSeconds(to))
    let status = NSDecimalDivide(&quotient, &numerator, &divisor, .plain)
    guard status == .noError else { return nil }
    var product = Decimal()
    var q = quotient
    _ = NSDecimalMultiply(&product, &q, &divisor, .plain)
    guard product == seconds else { return nil }
    return nsDecimalString(quotient)
}

public func scheduleIntervalSeconds(_ value: String, unit: String) -> Int64? {
    guard let decimal = Decimal(string: value) else { return nil }
    let seconds = decimal * Decimal(scheduleUnitSeconds(unit))
    var exact = Decimal()
    var tmp = seconds
    NSDecimalRound(&exact, &tmp, 0, .plain)
    if exact != seconds { return nil }
    guard let long = Int64(nsDecimalString(seconds)), (60...9_007_199_254_740_991).contains(long) else { return nil }
    return long
}

public func scheduleCronValid(_ expression: String) -> Bool {
    let fields = expression.trimmingCharacters(in: .whitespacesAndNewlines).split { $0.isWhitespace }.map(String.init)
    let bounds = [0...59, 0...23, 1...31, 1...12, 0...7]
    guard fields.count == 5 else { return false }
    return zip(fields, bounds).allSatisfy { field, range in
        field.split(separator: ",").allSatisfy { part in
            cronFieldValid(String(part), range: range)
        }
    }
}

public struct ScheduleCronShape: Equatable, Sendable {
    public var kind: String
    public var step: Int
    public var hour: Int
    public var minute: Int
    public var weekdays: Set<Int>
    public var days: Set<Int>

    public init(kind: String, step: Int = 1, hour: Int = 9, minute: Int = 0, weekdays: Set<Int> = [1, 2, 3, 4, 5], days: Set<Int> = [1]) {
        self.kind = kind
        self.step = step
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.days = days
    }
}

public func scheduleCronShape(_ expression: String) -> ScheduleCronShape? {
    guard scheduleCronValid(expression) else { return nil }
    let fields = expression.trimmingCharacters(in: .whitespacesAndNewlines).split { $0.isWhitespace }.map(String.init)
    let bounds = [0...59, 0...23, 1...31, 1...12, 0...7]
    let values: [Set<Int>] = zip(fields, bounds).map { field, range in
        Set(field.split(separator: ",").flatMap { part -> [Int] in
            let text = String(part)
            let base = text.split(separator: "/").first.map(String.init) ?? text
            let step = Int(text.split(separator: "/").dropFirst().first.map(String.init) ?? "1") ?? 1
            let start = base == "*" ? range.lowerBound : Int(base.split(separator: "-").first.map(String.init) ?? "") ?? range.lowerBound
            let end = base == "*" ? range.upperBound : Int(base.split(separator: "-").dropFirst().first.map(String.init) ?? base) ?? start
            return (start...end).filter { ($0 - start) % step == 0 }
        })
    }
    if values[3] != Set(1...12) { return nil }
    func fullStep(_ index: Int) -> Int? {
        (1...bounds[index].upperBound).first { step in
            values[index] == Set(bounds[index].filter { $0 % step == 0 })
        }
    }
    let minute = values[0].count == 1 ? values[0].first : nil
    let hour = values[1].count == 1 ? values[1].first : nil
    if fields[4] == "*" {
        if fields[2] == "*" {
            if let minuteStep = fullStep(0), values[1] == Set(0...23) {
                return ScheduleCronShape(kind: "minutely", step: minuteStep)
            }
            if let minute, let hourStep = fullStep(1) {
                return ScheduleCronShape(kind: "hourly", step: hourStep, minute: minute)
            }
            if let minute, let hour {
                return ScheduleCronShape(kind: "daily", hour: hour, minute: minute)
            }
            return nil
        }
        if let minute, let hour {
            return ScheduleCronShape(kind: "monthly", hour: hour, minute: minute, days: values[2])
        }
        return nil
    }
    if fields[2] != "*" || minute == nil || hour == nil { return nil }
    return ScheduleCronShape(
        kind: "weekly",
        hour: hour!,
        minute: minute!,
        weekdays: Set(values[4].map { $0 == 0 ? 7 : $0 })
    )
}

public func scheduleCronExpression(_ shape: ScheduleCronShape) -> String {
    precondition((0...23).contains(shape.hour) && (0...59).contains(shape.minute))
    func field(_ values: Set<Int>) -> String {
        let sorted = values.sorted()
        var runs: [String] = []
        var index = 0
        while index < sorted.count {
            let start = index
            while index + 1 < sorted.count && sorted[index + 1] == sorted[index] + 1 { index += 1 }
            if index - start >= 2 {
                runs.append("\(sorted[start])-\(sorted[index])")
            } else {
                runs.append(sorted[start...index].map(String.init).joined(separator: ","))
            }
            index += 1
        }
        return runs.joined(separator: ",")
    }
    switch shape.kind {
    case "minutely":
        precondition((1...59).contains(shape.step))
        return "\(shape.step == 1 ? "*" : "*/\(shape.step)") * * * *"
    case "hourly":
        precondition((1...23).contains(shape.step))
        return "\(shape.minute) \(shape.step == 1 ? "*" : "*/\(shape.step)") * * *"
    case "daily":
        return "\(shape.minute) \(shape.hour) * * *"
    case "weekly":
        precondition(!shape.weekdays.isEmpty && shape.weekdays.allSatisfy { (1...7).contains($0) })
        return "\(shape.minute) \(shape.hour) * * \(field(Set(shape.weekdays.map { $0 % 7 })))"
    case "monthly":
        precondition(!shape.days.isEmpty && shape.days.allSatisfy { (1...31).contains($0) })
        return "\(shape.minute) \(shape.hour) \(field(shape.days)) * *"
    default:
        preconditionFailure("Unsupported cron shape")
    }
}

public struct ScheduleRelativeTime: Equatable, Sendable {
    public var direction: Int
    public var value: Int64
    public var unit: String
}

public func scheduleRelativeTime(_ scheduledAt: String?, now: Date) -> ScheduleRelativeTime? {
    guard let target = parseScheduleInstant(scheduledAt) else { return nil }
    let millis = target.timeIntervalSince(now) * 1000
    let seconds = abs(millis) / 1000
    let units: [(String, Double)] = [("day", 86400), ("hour", 3600), ("minute", 60), ("second", 1)]
    let unit = units.first { seconds >= $0.1 || $0.0 == "second" }!
    let count = millis > 0 ? ceil(seconds / unit.1) : floor(seconds / unit.1)
    return ScheduleRelativeTime(direction: millis == 0 ? 0 : (millis > 0 ? 1 : -1), value: max(Int64(count), 1), unit: unit.0)
}

public func scheduleTimingChange(_ draft: ScheduleTimingDraft) throws -> JSONValue {
    if draft.kind == "every" {
        guard let seconds = scheduleIntervalSeconds(draft.quantity, unit: draft.unit) else {
            throw PocketError(code: "frequency_too_high", message: "frequency_too_high")
        }
        return jsonObject(["kind": .string("every"), "every_seconds": .number(Double(seconds))])
    }
    let zone = draft.zone.trimmingCharacters(in: .whitespacesAndNewlines)
    guard zone == "UTC" || (zone.contains("/") && !zone.contains(where: { $0.isWhitespace })) else {
        throw PocketError(code: "invalid_time_zone", message: "invalid_time_zone")
    }
    if draft.kind == "cron" {
        guard scheduleCronValid(draft.expression) else { throw PocketError(code: "invalid_cron", message: "invalid_cron") }
        return jsonObject([
            "kind": .string("cron"),
            "cron": jsonObject(["expression": .string(draft.expression), "time_zone": .string(zone)]),
        ])
    }
    let time = draft.time.trimmingCharacters(in: .whitespacesAndNewlines)
    guard time.range(of: #"^\d{2}:\d{2}(?::\d{2}(?:\.\d{1,3})?)?$"#, options: .regularExpression) != nil,
          parseLocalTime(time) != nil else {
        throw PocketError(code: "invalid_rule", message: "invalid_rule")
    }
    let normalizedTime = time.count == 5 ? "\(time):00" : time
    switch draft.kind {
    case "once":
        guard draft.date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            throw PocketError(code: "invalid_rule", message: "invalid_rule")
        }
        return jsonObject([
            "kind": .string("at"),
            "at": jsonObject(["date": .string(draft.date), "time": .string(normalizedTime), "time_zone": .string(zone)]),
        ])
    case "daily":
        return jsonObject([
            "kind": .string("daily"),
            "daily": jsonObject(["time": .string(normalizedTime), "time_zone": .string(zone)]),
        ])
    case "weekly", "weekdays":
        let days = draft.kind == "weekdays" ? Set([1, 2, 3, 4, 5]) : draft.weekdays
        guard !days.isEmpty, days.allSatisfy({ (1...7).contains($0) }) else {
            throw PocketError(code: "invalid_rule", message: "invalid_rule")
        }
        return jsonObject([
            "kind": .string("weekly"),
            "weekly": jsonObject([
                "time": .string(normalizedTime),
                "time_zone": .string(zone),
                "weekdays": .array(days.sorted().map { .number(Double($0)) }),
            ]),
        ])
    default:
        throw PocketError(code: "invalid-response", message: "Unsupported schedule kind")
    }
}

public func scheduleUpdateRequest(
    _ row: JSONValue,
    title: String,
    prompt: String,
    initial: ScheduleTimingDraft,
    draft: ScheduleTimingDraft
) throws -> JSONValue {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty, trimmedTitle.count <= 120 else {
        throw PocketError(code: "invalid_title", message: "invalid_title")
    }
    guard !trimmedPrompt.isEmpty else { throw PocketError(code: "invalid_prompt", message: "invalid_prompt") }
    guard let id = row["id"].isNull ? nil : row["id"], let sessionId = row["sessionId"].isNull ? nil : row["sessionId"] else {
        throw PocketError(code: "invalid-response", message: "Missing schedule field: id")
    }
    var object: [String: JSONValue] = [
        "id": id,
        "sessionId": sessionId,
        "expected": try scheduleSnapshot(row),
    ]
    if trimmedTitle != row["title"].str() { object["title"] = .string(trimmedTitle) }
    if trimmedPrompt != row["prompt"].str() { object["prompt"] = .string(trimmedPrompt) }
    if initial != draft { object["change"] = try scheduleTimingChange(draft) }
    return .object(object)
}

public func scheduleUpdatedRecord(_ result: JSONValue) throws -> JSONValue {
    if let code = result["code"].str() {
        throw PocketError(code: code, message: [code, result["message"].str()].compactMap { $0 }.joined(separator: ": "))
    }
    guard result["updated"].bool() != nil else {
        throw PocketError(code: "invalid-response", message: "Invalid schedule update response")
    }
    guard let record = result["record"].obj() else {
        throw PocketError(code: "invalid-response", message: "Invalid schedule update response: missing record")
    }
    return .object(record)
}

public func scheduleConfirmDeleted(_ result: JSONValue) throws {
    guard result["deleted"].bool() == true else {
        let message = [result["code"].str(), result["message"].str()].compactMap { $0 }.joined(separator: ": ")
        throw PocketError(code: "invalid-response", message: message.isEmpty ? "Could not confirm task deletion" : message)
    }
}

public func scheduleFailureMessage(_ raw: String, en: Bool) -> String {
    let code = raw.split(separator: ":").first.map(String.init) ?? raw
    let explanation: String?
    switch code {
    case "schedule_conflict":
        explanation = en
            ? "This task changed while you were editing. Your draft is retained. Cancel and reopen after refresh to edit the latest rule."
            : "任务在编辑期间已发生变化，草稿已保留。请刷新后取消并重新编辑最新规则。"
    case "schedule_ended":
        explanation = en ? "Inactive tasks are read-only. Their timing cannot be edited." : "已结束的任务为只读，无法修改时间"
    case "schedule_not_found":
        explanation = en ? "This task is no longer available. Your draft is retained." : "此任务当前不可用，草稿已保留。"
    case "invalid_title":
        explanation = en ? "Enter a task name of at most 120 characters." : "请输入不超过 120 个字符的任务名称"
    case "invalid_prompt":
        explanation = en ? "Enter a task instruction." : "请输入任务内容"
    case "invalid_time_zone":
        explanation = en ? "Enter a valid IANA time zone, for example Asia/Shanghai." : "请输入有效的 IANA 时区，例如 Asia/Shanghai。"
    case "invalid_cron":
        explanation = en ? "Enter a five-field cron expression, for example 0 9 * * 1-5." : "请输入 5 字段的 cron 表达式，例如 0 9 * * 1-5"
    case "frequency_too_high":
        explanation = en ? "Enter an interval of at least 60 whole seconds." : "请输入至少 60 秒的整数秒间隔"
    case "not_future":
        explanation = en ? "Choose a date and time in the future." : "请选择未来的日期和时间。"
    case "invalid_rule":
        explanation = en ? "Enter a valid date and time, or check the timing fields." : "请输入有效的日期和时间，或检查运行时间字段。"
    case "delivery_cursor_not_found":
        explanation = en ? "Records were updated. Refresh to reload." : "运行记录已更新，请刷新。"
    default:
        explanation = nil
    }
    return explanation.map { "\($0)\n\(raw)" } ?? raw
}

private func cronFieldValid(_ part: String, range: ClosedRange<Int>) -> Bool {
    if part == "*" { return true }
    if let star = part.range(of: #"^\*/(\d+)$"#, options: .regularExpression) {
        let n = Int64(part[star].dropFirst(2))
        return n.map { (1...9_007_199_254_740_991).contains($0) } == true
    }
    guard let match = part.range(of: #"^(\d+)(?:-(\d+))?(?:/(\d+))?$"#, options: .regularExpression) else { return false }
    let body = String(part[match])
    let pieces = body.split(separator: "/", omittingEmptySubsequences: false)
    let bounds = pieces[0].split(separator: "-", omittingEmptySubsequences: false)
    guard let start = Int(bounds[0]), range.contains(start) else { return false }
    if bounds.count == 1 {
        return pieces.count == 1
    }
    guard let end = Int(bounds[1]), range.contains(end), end >= start else { return false }
    if pieces.count == 1 { return true }
    return Int64(pieces[1]).map { (1...9_007_199_254_740_991).contains($0) } == true
}

private func parseScheduleInstant(_ value: String?) -> Date? {
    guard let value else { return nil }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) { return date }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: value)
}

private func wallClock(_ date: Date, zone: String) -> (date: String, time: String, weekday: Int)? {
    guard let tz = TimeZone(identifier: zone) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day,
          let hour = parts.hour, let minute = parts.minute, let second = parts.second else { return nil }
    let millis = (parts.nanosecond ?? 0) / 1_000_000
    let isoWeekday = parts.weekday == 1 ? 7 : (parts.weekday ?? 2) - 1
    let dateText = String(format: "%04d-%02d-%02d", year, month, day)
    let timeText = String(format: "%02d:%02d:%02d.%03d", hour, minute, second, millis)
    return (dateText, timeText, isoWeekday)
}

private func parseLocalTime(_ value: String) -> DateComponents? {
    let parts = value.split(separator: ":")
    guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
          (0...23).contains(hour), (0...59).contains(minute) else { return nil }
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    if parts.count > 2 {
        let sec = parts[2].split(separator: ".")
        components.second = Int(sec[0])
    }
    return components
}

private func nsDecimalString(_ value: Decimal) -> String {
    var v = value
    return NSDecimalString(&v, nil)
}

public func scheduleCatalogRows(_ result: JSONValue) throws -> [JSONValue] {
    if let array = result.arr() { return array }
    if let items = result["items"].arr() { return items }
    if let tasks = result["tasks"].arr() { return tasks }
    throw PocketError(code: "invalid-response", message: "schedule.catalog must be an array or an object with items/tasks")
}

public func scheduleHistoryRows(_ result: JSONValue) throws -> [JSONValue] {
    if let items = result["items"].arr() { return items }
    if let records = result["records"].arr() { return records }
    if let array = result.arr() { return array }
    throw PocketError(code: "invalid-response", message: "schedule.history must be an array or an object with items/records")
}
