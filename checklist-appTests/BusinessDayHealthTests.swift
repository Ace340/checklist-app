//
//  BusinessDayHealthTests.swift
//  checklist-appTests
//
//  Pure-logic tests for the staleness helper in
//  `Scheduling/BusinessDayHealth.swift`. No SwiftData container needed —
//  the helper takes `Date` primitives, not `BusinessDay`. Mirrors the
//  `LogRetentionTests` AAA style and boundary-pinning pattern.
//
//  See `docs/adr/0005-forgotten-finish-day.md` for the locked-in rule:
//  a business day is stale once its `openedAt` is *strictly older* than
//  24 hours from "now."
//

import XCTest
@testable import checklist_app

final class BusinessDayHealthTests: XCTestCase {

    /// 24 hours, to the second. Same value as
    /// `BusinessDayHealth.staleThreshold`, restated locally so a typo
    /// in either place surfaces as a test failure rather than a silent
    /// off-by-something regression.
    private let twentyFourHours: TimeInterval = 24 * 60 * 60

    /// Fixed reference instant. DO NOT use `.now` in time-based tests —
    /// all `openedAt` values are constructed relative to this so
    /// assertions are deterministic across runs.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - staleThreshold

    func testStaleThreshold_equalsTwentyFourHoursInSeconds() {
        XCTAssertEqual(BusinessDayHealth.staleThreshold, twentyFourHours)
    }

    func testStaleThreshold_equalsExact86400Seconds() {
        // Sanity: 24 * 60 * 60 = 86,400. Pins the value to a known
        // literal so a typo in either the constant or its multiplier
        // is caught at test time.
        XCTAssertEqual(BusinessDayHealth.staleThreshold, 86_400)
    }

    // MARK: - isStale (common cases)

    func testIsStale_justOpened_returnsFalse() {
        // A day opened at this exact instant is fresh.
        let result = BusinessDayHealth.isStale(openedAt: now, asOf: now)
        XCTAssertFalse(result)
    }

    func testIsStale_farPast_returnsTrue() {
        // A day opened 7 days ago is unambiguously stale.
        let weekAgo = now - (7 * 24 * 60 * 60)
        let result = BusinessDayHealth.isStale(openedAt: weekAgo, asOf: now)
        XCTAssertTrue(result)
    }

    // MARK: - isStale (boundary at exactly 24 hours)

    func testIsStale_openedExactlyAtThreshold_returnsFalse() {
        // Strict greater-than: a day exactly 24 hours old is still
        // within the legitimate-range boundary and must NOT be flagged
        // stale. Pins the inclusivity decision from ADR 0005.
        let openedAt = now - twentyFourHours
        let result = BusinessDayHealth.isStale(openedAt: openedAt, asOf: now)
        XCTAssertFalse(
            result,
            "business day exactly 24 hours old is not yet stale"
        )
    }

    func testIsStale_openedOneSecondBeforeThreshold_returnsFalse() {
        let openedAt = now - twentyFourHours + 1
        let result = BusinessDayHealth.isStale(openedAt: openedAt, asOf: now)
        XCTAssertFalse(result)
    }

    func testIsStale_openedOneSecondAfterThreshold_returnsTrue() {
        let openedAt = now - twentyFourHours - 1
        let result = BusinessDayHealth.isStale(openedAt: openedAt, asOf: now)
        XCTAssertTrue(result)
    }

    // MARK: - isStale (defensive edge case)

    func testIsStale_futureOpenedAt_returnsFalse() {
        // Clock skew: an `openedAt` slightly in the future produces a
        // negative duration. Must not flag stale (no false positives on
        // plausible device clock drift).
        let openedAt = now + 60  // 1 minute in the future
        let result = BusinessDayHealth.isStale(openedAt: openedAt, asOf: now)
        XCTAssertFalse(result)
    }
}
