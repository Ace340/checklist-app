//
//  DutyStatusTests.swift
//  checklist-appTests
//
//  XCTest port of the 18 Phase 0 scheduling assertions originally in
//  .tmp/tdd/Tests.swift. Same cases, same UTC-calendar fixture, same
//  anchors (2026: Mon=Jul13, Tue=Jul14, Wed=Jul15, Thu=Jul16, Sun=Jul19).
//

import XCTest
@testable import checklist_app

final class DutyStatusTests: XCTestCase {

    /// Fixed UTC calendar so weekday math is deterministic across machines and
    /// independent of the machine running the tests.
    private static var utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private var calendar: Calendar { Self.utcCalendar }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // Anchors (2026): Mon=Jul13, Tue=Jul14, Wed=Jul15, Thu=Jul16, Sun=Jul19
    private var monday: Date { day(2026, 7, 13) }
    private var tuesday: Date { day(2026, 7, 14) }
    private var wednesday: Date { day(2026, 7, 15) }
    private var thursday: Date { day(2026, 7, 16) }
    private var sunday: Date { day(2026, 7, 19) }

    // MARK: - Slice 1: weekly duty on its own day, not done, is DUE

    func testWeeklyDutyOnItsWeekdayNotDoneIsDue() {
        XCTAssertEqual(
            weeklyDutyStatus(scheduled: .wednesday, now: wednesday, completedThisWeek: false, calendar: calendar),
            .due,
            "Wednesday duty on Wednesday, not done -> due"
        )
    }

    // MARK: - Slice 2: weekly boundaries

    func testWeeklyDutyBeforeItsWeekday_onMonday_isNotYetDue() {
        XCTAssertEqual(
            weeklyDutyStatus(scheduled: .wednesday, now: monday, completedThisWeek: false, calendar: calendar),
            .notYetDue,
            "Wednesday duty on Monday, not done -> notYetDue"
        )
    }

    func testWeeklyDutyBeforeItsWeekday_onTuesday_isNotYetDue() {
        XCTAssertEqual(
            weeklyDutyStatus(scheduled: .wednesday, now: tuesday, completedThisWeek: false, calendar: calendar),
            .notYetDue,
            "Wednesday duty on Tuesday, not done -> notYetDue"
        )
    }

    func testWeeklyDutyAfterItsWeekday_onThursday_isOverdue() {
        XCTAssertEqual(
            weeklyDutyStatus(scheduled: .wednesday, now: thursday, completedThisWeek: false, calendar: calendar),
            .overdue,
            "Wednesday duty on Thursday, not done -> overdue"
        )
    }

    func testWeeklyDutyAfterItsWeekday_onSunday_isOverdue() {
        XCTAssertEqual(
            weeklyDutyStatus(scheduled: .wednesday, now: sunday, completedThisWeek: false, calendar: calendar),
            .overdue,
            "Wednesday duty on Sunday, not done -> overdue"
        )
    }

    func testWeeklyDutyOnItsWeekdayDoneThisWeek_isDone() {
        XCTAssertEqual(
            weeklyDutyStatus(scheduled: .wednesday, now: wednesday, completedThisWeek: true, calendar: calendar),
            .done,
            "Wednesday duty on Wednesday, done -> done"
        )
    }

    func testWeeklyDutyCompletedEarlyBeforeItsWeekday_isDone() {
        // Completion outranks day-position: a duty done before its weekday
        // is done for the week. (Pinned by Phase 0 tests; do not regress.)
        XCTAssertEqual(
            weeklyDutyStatus(scheduled: .friday, now: wednesday, completedThisWeek: true, calendar: calendar),
            .done,
            "Friday duty done early on Wednesday -> done"
        )
    }

    // MARK: - Slice 3: daily status is current-business-day completion

    func testDailyDutyNotDoneThisBusinessDay_isPending() {
        XCTAssertEqual(
            dailyDutyStatus(completedInCurrentBusinessDay: false),
            .pending,
            "daily duty not done this business day -> pending"
        )
    }

    func testDailyDutyDoneThisBusinessDay_isDone() {
        XCTAssertEqual(
            dailyDutyStatus(completedInCurrentBusinessDay: true),
            .done,
            "daily duty done this business day -> done"
        )
    }

    // MARK: - Slice 4: surfacing rule — hide only notYetDue

    func testShouldSurfacePending() {
        XCTAssertTrue(shouldSurface(.pending), "pending surfaces")
    }

    func testShouldSurfaceDone() {
        XCTAssertTrue(shouldSurface(.done), "done surfaces")
    }

    func testShouldSurfaceDue() {
        XCTAssertTrue(shouldSurface(.due), "due surfaces")
    }

    func testShouldSurfaceOverdue() {
        XCTAssertTrue(shouldSurface(.overdue), "overdue surfaces")
    }

    func testShouldNotSurfaceNotYetDue() {
        XCTAssertFalse(shouldSurface(.notYetDue), "notYetDue is hidden until its weekday")
    }

    // MARK: - Slice 5: Monday-start week boundary (for "done this week")

    func testSameWeek_mondayToWednesday_isSameWeek() {
        XCTAssertTrue(
            sameWeek(monday, wednesday, calendar: calendar),
            "Mon Jul13 & Wed Jul15 share a week"
        )
    }

    func testSameWeek_wednesdayToSunday_isSameWeek() {
        XCTAssertTrue(
            sameWeek(wednesday, sunday, calendar: calendar),
            "Wed Jul15 & Sun Jul19 share a week (Sunday is week's end)"
        )
    }

    func testSameWeek_sundayToNextMonday_isDifferentWeek() {
        let nextMonday = day(2026, 7, 20)
        XCTAssertFalse(
            sameWeek(sunday, nextMonday, calendar: calendar),
            "Sun Jul19 & Mon Jul20 are different weeks"
        )
    }

    func testSameWeek_mondayToPrevMonday_isDifferentWeek() {
        let prevMonday = day(2026, 7, 6)
        XCTAssertFalse(
            sameWeek(monday, prevMonday, calendar: calendar),
            "Mon Jul13 & Mon Jul6 are different weeks"
        )
    }
}
