import XCTest
@testable import DSHProtocol

final class ClockParityTests: XCTestCase {
    func testRelativeTimeBucketsMatchDesktopPrimitives() {
        let day: Int64 = 86_400_000
        let now: Int64 = 2_000_000_000_000
        XCTAssertEqual(relativeTime(at: now + 60_000, now: now), RelativeTime(unit: .now, n: 0))
        XCTAssertEqual(relativeTime(at: now - 59_999, now: now), RelativeTime(unit: .now, n: 0))
        XCTAssertEqual(relativeTime(at: now - 60_000, now: now), RelativeTime(unit: .minutes, n: 1))
        XCTAssertEqual(relativeTime(at: now - 3_599_999, now: now), RelativeTime(unit: .minutes, n: 59))
        XCTAssertEqual(relativeTime(at: now - 3_600_000, now: now), RelativeTime(unit: .hours, n: 1))
        XCTAssertEqual(relativeTime(at: now - (day - 1), now: now), RelativeTime(unit: .hours, n: 23))
        XCTAssertEqual(relativeTime(at: now - day, now: now), RelativeTime(unit: .days, n: 1))
        XCTAssertEqual(relativeTime(at: now - (30 * day - 1), now: now), RelativeTime(unit: .days, n: 29))
        XCTAssertEqual(relativeTime(at: now - 30 * day, now: now), RelativeTime(unit: .months, n: 1))
        XCTAssertEqual(relativeTime(at: now - (365 * day - 1), now: now), RelativeTime(unit: .months, n: 12))
        XCTAssertEqual(relativeTime(at: now - 365 * day, now: now), RelativeTime(unit: .years, n: 1))
        XCTAssertEqual(relativeTime(at: now - 2 * 365 * day, now: now), RelativeTime(unit: .years, n: 2))
    }

    func testSessionTimeLabelUsesWorkspaceLocale() {
        let day: Int64 = 86_400_000
        let now: Int64 = 2_000_000_000_000
        XCTAssertEqual(formatSessionTime(at: now, now: now, english: false), "刚刚")
        XCTAssertEqual(formatSessionTime(at: now, now: now, english: true), "now")
        XCTAssertEqual(formatSessionTime(at: now - 60_000, now: now, english: false), "1分钟")
        XCTAssertEqual(formatSessionTime(at: now - 60_000, now: now, english: true), "1min")
        XCTAssertEqual(formatSessionTime(at: now - 3_600_000, now: now, english: false), "1小时")
        XCTAssertEqual(formatSessionTime(at: now - 3_600_000, now: now, english: true), "1h")
        XCTAssertEqual(formatSessionTime(at: now - day, now: now, english: false), "1天")
        XCTAssertEqual(formatSessionTime(at: now - day, now: now, english: true), "1d")
        XCTAssertEqual(formatSessionTime(at: now - 30 * day, now: now, english: false), "1个月")
        XCTAssertEqual(formatSessionTime(at: now - 30 * day, now: now, english: true), "1mo")
        XCTAssertEqual(formatSessionTime(at: now - 365 * day, now: now, english: false), "1年")
        XCTAssertEqual(formatSessionTime(at: now - 365 * day, now: now, english: true), "1y")
    }

    func testSessionRowHidesTimeOnBlankAndUsesCompactPending() {
        let now: Int64 = 1_000
        XCTAssertNil(
            sessionRowTrailingLabel(blank: true, pending: nil, updatedAt: 0, now: now, english: false)
        )
        XCTAssertEqual(
            sessionRowTrailingLabel(blank: false, pending: .approval, updatedAt: 0, now: now, english: false),
            "待审批"
        )
        XCTAssertEqual(
            sessionRowTrailingLabel(blank: false, pending: .planReview, updatedAt: 0, now: now, english: true),
            "Plan review"
        )
        XCTAssertEqual(
            sessionRowTrailingLabel(blank: false, pending: .question, updatedAt: 0, now: now, english: false),
            "待回答"
        )
        XCTAssertEqual(
            sessionRowTrailingLabel(blank: false, pending: nil, updatedAt: now, now: now, english: false),
            "刚刚"
        )
        XCTAssertEqual(
            sessionPendingInteraction(awaitingApproval: true, planReview: true, awaitingAnswer: true),
            .approval
        )
        XCTAssertEqual(
            sessionPendingInteraction(awaitingApproval: false, planReview: true, awaitingAnswer: true),
            .planReview
        )
    }

    func testTitleMetadataUsesPendingStateBeforeRunningAndDoesNotInventIdle() {
        func metadata(_ running: Bool?, _ pending: SessionPendingInteraction? = nil) -> ConversationTitleMetadata {
            ConversationTitleMetadata(updatedAt: nil, blank: false, running: running, pending: pending, now: 1_000, english: false)
        }
        XCTAssertNil(metadata(nil).status)
        XCTAssertNotEqual(metadata(true).status, metadata(false).status)
        for pending in [SessionPendingInteraction.approval, .planReview, .question] {
            XCTAssertEqual(metadata(true, pending).status, metadata(false, pending).status)
            XCTAssertEqual(metadata(nil, pending).status, metadata(true, pending).status)
            XCTAssertNotEqual(metadata(true, pending).status, metadata(true).status)
        }
        XCTAssertEqual(Set([metadata(true).status, metadata(false).status, metadata(true, .approval).status,
                            metadata(true, .planReview).status, metadata(true, .question).status]).count, 5)
    }

    func testTitleTimeHidesMissingAndBlankDatesAndAdvancesAtMinuteBoundary() {
        let now: Int64 = 2_000_000_000_000
        func metadata(_ timestamp: Int64?, blank: Bool = false, now: Int64) -> ConversationTitleMetadata {
            ConversationTitleMetadata(updatedAt: timestamp, blank: blank, running: false, pending: nil, now: now, english: false)
        }
        for absent: Int64? in [nil, 0, -1] { XCTAssertNil(metadata(absent, now: now).time) }
        XCTAssertNil(metadata(now, blank: true, now: now).time)
        let initial = metadata(now, now: now)
        XCTAssertEqual(initial.time, metadata(now, now: now + 59_999).time)
        XCTAssertEqual(initial.time, metadata(now + 60_000, now: now).time)
        XCTAssertNotEqual(initial.time, metadata(now, now: now + 60_000).time)
        XCTAssertEqual(initial.status, metadata(now, now: now + 60_000).status)
    }

    func testMessageClockMatchesDesktopLocalCalendarRules() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ mi: Int) -> Int64 {
            var parts = DateComponents()
            parts.year = y
            parts.month = m
            parts.day = d
            parts.hour = h
            parts.minute = mi
            parts.second = 0
            parts.nanosecond = 0
            let date = calendar.date(from: parts)!
            return Int64((date.timeIntervalSince1970 * 1000).rounded())
        }
        let now = at(2026, 10, 12, 16, 8)
        XCTAssertEqual(formatMessageClock(now, nowMs: now, english: false, calendar: calendar), "16:08")
        XCTAssertEqual(
            formatMessageClock(at(2026, 10, 11, 16, 8), nowMs: now, english: false, calendar: calendar),
            "10月11日 16:08"
        )
        XCTAssertEqual(
            formatMessageClock(at(2025, 1, 3, 9, 5), nowMs: now, english: false, calendar: calendar),
            "2025年1月3日 09:05"
        )
        XCTAssertEqual(
            formatMessageClock(at(2026, 10, 11, 16, 8), nowMs: now, english: true, calendar: calendar),
            "10/11 16:08"
        )
        XCTAssertEqual(
            formatMessageClock(at(2025, 1, 3, 9, 5), nowMs: now, english: true, calendar: calendar),
            "2025-1-3 09:05"
        )
        XCTAssertFalse(conversationHeaderShowsTimestamp)
    }
}
