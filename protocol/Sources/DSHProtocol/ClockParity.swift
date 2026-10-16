import Foundation

/// Desktop `@deepseek-ai/dsh-client-ui-primitives` `relativeTime`
/// (`packages/client/ui-primitives/src/relative-time.ts`).
public enum RelativeTimeUnit: String, Equatable, Sendable {
    case now
    case minutes
    case hours
    case days
    case months
    case years
}

public struct RelativeTime: Equatable, Sendable {
    public var unit: RelativeTimeUnit
    public var n: Int
}

/// Compact elapsed buckets. Future timestamps clamp to `now`. Not calendar today/yesterday.
public func relativeTime(at: Int64, now: Int64) -> RelativeTime {
    let minute: Int64 = 60_000
    let hour: Int64 = 3_600_000
    let day: Int64 = 86_400_000
    let diff = max(0, now - at)
    if diff < minute { return RelativeTime(unit: .now, n: 0) }
    if diff < hour { return RelativeTime(unit: .minutes, n: Int(diff / minute)) }
    if diff < day { return RelativeTime(unit: .hours, n: Int(diff / hour)) }
    if diff < 30 * day { return RelativeTime(unit: .days, n: Int(diff / day)) }
    if diff < 365 * day { return RelativeTime(unit: .months, n: Int(diff / (30 * day))) }
    return RelativeTime(unit: .years, n: Int(diff / (365 * day)))
}

/// Desktop `ui-workspace` `Rows.tsx` `timeLabel` + locale `time.now` / `time.{unit}`.
public func formatSessionTime(at: Int64, now: Int64, english: Bool) -> String {
    let bucket = relativeTime(at: at, now: now)
    switch bucket.unit {
    case .now: return english ? "now" : "刚刚"
    case .minutes: return english ? "\(bucket.n)min" : "\(bucket.n)分钟"
    case .hours: return english ? "\(bucket.n)h" : "\(bucket.n)小时"
    case .days: return english ? "\(bucket.n)d" : "\(bucket.n)天"
    case .months: return english ? "\(bucket.n)mo" : "\(bucket.n)个月"
    case .years: return english ? "\(bucket.n)y" : "\(bucket.n)年"
    }
}

/// Desktop `ui-workspace` `sessionStatuses` `pendingInteraction` union.
public enum SessionPendingInteraction: String, Equatable, Sendable {
    case approval
    case planReview
    case question
}

/// Same order as `sessionStatuses`: approval, then plan-review, then question.
public func sessionPendingInteraction(
    awaitingApproval: Bool,
    planReview: Bool,
    awaitingAnswer: Bool
) -> SessionPendingInteraction? {
    if awaitingApproval { return .approval }
    if planReview { return .planReview }
    if awaitingAnswer { return .question }
    return nil
}

/// Desktop session row trailing slot: `primaryStatus.trailingLabel ?? timeLabel`.
/// Blank sessions omit the slot (`!row.blank && …`).
public func sessionRowTrailingLabel(
    blank: Bool,
    pending: SessionPendingInteraction?,
    updatedAt: Int64,
    now: Int64,
    english: Bool
) -> String? {
    if blank { return nil }
    switch pending {
    case .approval: return english ? "Approval" : "待审批"
    case .planReview: return english ? "Plan review" : "计划待审"
    case .question: return english ? "Answer" : "待回答"
    case nil: return formatSessionTime(at: updatedAt, now: now, english: english)
    }
}

/// Desktop `ui-chat` `locale.ts` `clock.md`.
public func messageClockMd(month: Int, day: Int, english: Bool) -> String {
    english ? "\(month)/\(day)" : "\(month)月\(day)日"
}

/// Desktop `ui-chat` `locale.ts` `clock.ymd`.
public func messageClockYmd(year: Int, month: Int, day: Int, english: Bool) -> String {
    english ? "\(year)-\(month)-\(day)" : "\(year)年\(month)月\(day)日"
}

/// Desktop `ui-chat` `formatMessageClock` (`message-chrome.ts`).
/// Local calendar day → `HH:mm`; same year → `clock.md` + clock; else `clock.ymd` + clock.
/// Month/day are unpadded; time is 24-hour zero-padded. No today/yesterday words.
public func formatMessageClock(
    _ timestampMs: Int64,
    nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
    english: Bool,
    calendar: Calendar = .current
) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000)
    let now = Date(timeIntervalSince1970: TimeInterval(nowMs) / 1000)
    let clock = String(
        format: "%02d:%02d",
        calendar.component(.hour, from: date),
        calendar.component(.minute, from: date)
    )
    if calendar.isDate(date, inSameDayAs: now) { return clock }
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    let datePart = year == calendar.component(.year, from: now)
        ? messageClockMd(month: month, day: day, english: english)
        : messageClockYmd(year: year, month: month, day: day, english: english)
    return "\(datePart) \(clock)"
}

/// Conversation session header has crumbs / title / slots — no clock.
public let conversationHeaderShowsTimestamp = false
