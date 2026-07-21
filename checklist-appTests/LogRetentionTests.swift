//
//  LogRetentionTests.swift
//  checklist-appTests
//
//  Pure-logic tests for the retention helpers in
//  `History/LogRetention.swift`. No SwiftData container needed —
//  `CompletionLog` instances are constructed detached and never inserted,
//  since the helpers only read `timestamp`. Mirrors the `PinHasherTests`
//  and `StaffManagementTests` AAA style.
//
//  See `docs/adr/0004-history-viewer-and-retention.md` for the locked-in
//  rule: a log is eligible for hard deletion once its `timestamp` is
//  *strictly older* than 30 × 24 hours from "now."
//

import XCTest
@testable import checklist_app

final class LogRetentionTests: XCTestCase {

    /// 30 days, to the second. Same value as `LogRetention.retentionWindow`,
    /// restated locally so a typo in either place surfaces as a test failure
    /// rather than a silent off-by-something regression.
    private let thirtyDays: TimeInterval = 30 * 24 * 60 * 60

    /// Fixed reference instant. DO NOT use `.now` in time-based tests —
    /// all logs and cutoffs are constructed relative to this so assertions
    /// are deterministic across runs.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Detached log — not inserted into any ModelContext. Sufficient for
    /// testing pure retention logic which only reads `timestamp`.
    private func makeLog(timestamp: Date) -> CompletionLog {
        CompletionLog(timestamp: timestamp)
    }

    // MARK: - retentionWindow

    func testRetentionWindow_equalsThirtyDaysInSeconds() {
        XCTAssertEqual(LogRetention.retentionWindow, thirtyDays)
    }

    func testRetentionWindow_equalsExact2592000Seconds() {
        // Sanity: 30 * 24 * 60 * 60 = 2,592,000. Pins the value to a known
        // literal so a typo in either the constant or its multiplier is
        // caught at test time.
        XCTAssertEqual(LogRetention.retentionWindow, 2_592_000)
    }

    // MARK: - cutoffDate

    func testCutoffDate_returnsExactlyThirtyDaysBeforeAsOf() {
        let cutoff = LogRetention.cutoffDate(asOf: now)
        XCTAssertEqual(cutoff.timeIntervalSince(now), -thirtyDays)
    }

    func testCutoffDate_atEpoch_returnsThirtyDaysBeforeEpoch() {
        // Edge: a reference instant of 0 must produce a negative cutoff
        // (30 days before the epoch). Confirms the math is pure subtraction
        // with no calendar-day wrapping.
        let epoch = Date(timeIntervalSince1970: 0)
        let cutoff = LogRetention.cutoffDate(asOf: epoch)
        XCTAssertEqual(cutoff.timeIntervalSince1970, -thirtyDays)
    }

    // MARK: - logsToDelete (empty / all / none)

    func testLogsToDelete_emptyInput_returnsEmpty() {
        let result = LogRetention.logsToDelete(in: [], asOf: now)
        XCTAssertTrue(result.isEmpty)
    }

    func testLogsToDelete_allOlderThanWindow_returnsAll() {
        let logs = [
            makeLog(timestamp: now - thirtyDays - 60),
            makeLog(timestamp: now - thirtyDays - 3_600),
            makeLog(timestamp: now - thirtyDays - 86_400),
        ]
        let result = LogRetention.logsToDelete(in: logs, asOf: now)
        XCTAssertEqual(result.count, 3)
    }

    func testLogsToDelete_allNewerThanWindow_returnsEmpty() {
        let logs = [
            makeLog(timestamp: now),
            makeLog(timestamp: now - 60),
            makeLog(timestamp: now - (thirtyDays - 1)), // 1s inside the window
        ]
        let result = LogRetention.logsToDelete(in: logs, asOf: now)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - logsToDelete (boundary at exactly 30 days)

    func testLogsToDelete_logExactlyAtCutoff_notIncluded() {
        // Strict less-than: a log exactly 30 days old is still within the
        // retention window and must NOT be deleted. Pins the inclusivity
        // decision from ADR 0004.
        let cutoff = LogRetention.cutoffDate(asOf: now)
        let logAtCutoff = makeLog(timestamp: cutoff)
        let result = LogRetention.logsToDelete(in: [logAtCutoff], asOf: now)
        XCTAssertTrue(
            result.isEmpty,
            "log exactly 30 days old is still within retention window"
        )
    }

    func testLogsToDelete_logOneSecondBeforeCutoff_included() {
        let cutoff = LogRetention.cutoffDate(asOf: now)
        let logJustBefore = makeLog(timestamp: cutoff.addingTimeInterval(-1))
        let result = LogRetention.logsToDelete(in: [logJustBefore], asOf: now)
        XCTAssertEqual(result.count, 1)
    }

    func testLogsToDelete_logOneSecondAfterCutoff_notIncluded() {
        let cutoff = LogRetention.cutoffDate(asOf: now)
        let logJustAfter = makeLog(timestamp: cutoff.addingTimeInterval(1))
        let result = LogRetention.logsToDelete(in: [logJustAfter], asOf: now)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - logsToDelete (mixed ages, ordering)

    func testLogsToDelete_mixedAges_returnsOnlyOldLogs() {
        let oldLog = makeLog(timestamp: now - thirtyDays - 1)   // eligible
        let edgeLog = makeLog(timestamp: now - thirtyDays)      // NOT eligible (== cutoff)
        let newLog = makeLog(timestamp: now - 1)                // not eligible
        let result = LogRetention.logsToDelete(in: [oldLog, edgeLog, newLog], asOf: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.timestamp, oldLog.timestamp)
    }

    func testLogsToDelete_preservesInputOrder() {
        // Not semantically required (the caller iterates and deletes), but
        // pinned so a future `.sorted` doesn't surprise the call site.
        // Uses identity comparison (`===`) because `CompletionLog` is a
        // `@Model` class without `Equatable` conformance.
        let oldest = makeLog(timestamp: now - thirtyDays - 86_400)
        let middle = makeLog(timestamp: now - thirtyDays - 3_600)
        let newest = makeLog(timestamp: now - thirtyDays - 60)
        let result = LogRetention.logsToDelete(in: [oldest, middle, newest], asOf: now)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result[0] === oldest)
        XCTAssertTrue(result[1] === middle)
        XCTAssertTrue(result[2] === newest)
    }
}
