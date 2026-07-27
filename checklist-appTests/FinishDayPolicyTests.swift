//
//  FinishDayPolicyTests.swift
//  checklist-appTests
//
//  In-memory SwiftData tests for the finish-day warn helper in
//  `Scheduling/FinishDayPolicy.swift`. Uses an in-memory container
//  because the helper's inputs are `@Model` instances with
//  `@Relationship` traversal (`duty.logs`, `log.businessDay`) — same
//  pattern as `AuthStoreTests`. Mirrors the AAA style of
//  `BusinessDayHealthTests` / `LogRetentionTests`.
//
//  See `docs/adr/0006-finish-day-with-incomplete-closing-duties.md`
//  for the locked-in rule: closing daily duties not yet completed in
//  the current business day produce a warn prompt; the helper returns
//  the list, the UI decides how to surface it.
//

import XCTest
import SwiftData
@testable import checklist_app

@MainActor
final class FinishDayPolicyTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()

        // Fresh in-memory SwiftData container per test (matches the
        // `isStoredInMemoryOnly` tooling path the app itself uses under
        // previews/XCTest). Tests stay isolated, no on-disk state leaks.
        let schema = Schema([
            Checklist.self,
            TaskItem.self,
            CompletionLog.self,
            BusinessDay.self,
            User.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Test helpers

    /// Creates a duty attached to a freshly-inserted checklist with the
    /// given `(area, cadence, phase)`. Both the checklist and the duty
    /// are inserted into the context before returning.
    @discardableResult
    private func makeDuty(
        title: String,
        area: Area = .foh,
        cadence: Cadence = .daily,
        phase: Phase? = .closing,
        order: Int = 0
    ) -> TaskItem {
        let list = Checklist(title: "test", area: area, cadence: cadence, phase: phase)
        context.insert(list)
        let duty = TaskItem(
            title: title,
            order: order,
            weekday: cadence == .weekly ? .monday : nil
        )
        duty.checklist = list
        context.insert(duty)
        return duty
    }

    /// Marks `duty` as done in `businessDay` by inserting a
    /// `CompletionLog` and wiring both references. Mirrors the production
    /// mutation in `DutyListView.toggle(_:)`.
    private func markDone(_ duty: TaskItem, in businessDay: BusinessDay) {
        let log = CompletionLog()
        log.duty = duty
        log.businessDay = businessDay
        context.insert(log)
    }

    // MARK: - Empty cases

    func testIncompleteClosingDuties_noDutiesAtAll_returnsEmpty() {
        // Arrange: a business day with no duties in the store at all.
        let day = BusinessDay()
        context.insert(day)

        // Act
        let result = FinishDayPolicy.incompleteClosingDuties(in: [], businessDay: day)

        // Assert
        XCTAssertTrue(result.isEmpty, "no duties → nothing to warn about")
    }

    func testIncompleteClosingDuties_allClosingDutiesDone_returnsEmpty() {
        // Arrange: two closing duties, both completed in the current day.
        // The "happy path" finish-day — no warning should fire.
        let day = BusinessDay()
        context.insert(day)
        let d1 = makeDuty(title: "Lock front door")
        let d2 = makeDuty(title: "Turn off lights")
        markDone(d1, in: day)
        markDone(d2, in: day)
        try? context.save()

        // Act
        let result = FinishDayPolicy.incompleteClosingDuties(in: [d1, d2], businessDay: day)

        // Assert
        XCTAssertTrue(result.isEmpty, "all closing duties done → no warning")
    }

    // MARK: - Non-empty cases

    func testIncompleteClosingDuties_allClosingDutiesIncomplete_returnsAll() {
        // Arrange: two closing duties, neither completed.
        let day = BusinessDay()
        context.insert(day)
        let d1 = makeDuty(title: "Lock front door")
        let d2 = makeDuty(title: "Turn off lights")
        try? context.save()

        // Act
        let result = FinishDayPolicy.incompleteClosingDuties(in: [d1, d2], businessDay: day)

        // Assert
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(Set(result.map(\.title)), Set(["Lock front door", "Turn off lights"]))
    }

    func testIncompleteClosingDuties_mixedCompleteAndIncomplete_returnsOnlyIncomplete() {
        // Arrange: three closing duties; the middle one is done. The
        // result must include the incomplete ones and exclude the done
        // one — order preserved.
        let day = BusinessDay()
        context.insert(day)
        let d1 = makeDuty(title: "Lock front door", order: 0)
        let d2 = makeDuty(title: "Count drawer", order: 1)
        let d3 = makeDuty(title: "Turn off lights", order: 2)
        markDone(d2, in: day)  // only the middle one
        try? context.save()

        // Act
        let result = FinishDayPolicy.incompleteClosingDuties(in: [d1, d2, d3], businessDay: day)

        // Assert
        XCTAssertEqual(result.map(\.title), ["Lock front door", "Turn off lights"])
    }

    // MARK: - Exclusion rules

    func testIncompleteClosingDuties_excludesOpeningDuties() {
        // Arrange: two incomplete daily duties — one opening, one closing.
        // Only the closing one should appear in the warn list.
        let day = BusinessDay()
        context.insert(day)
        let opening = makeDuty(title: "Unlock front door", phase: .opening)
        let closing = makeDuty(title: "Lock front door", phase: .closing)
        try? context.save()

        // Act
        let result = FinishDayPolicy.incompleteClosingDuties(in: [opening, closing], businessDay: day)

        // Assert
        XCTAssertEqual(result.map(\.title), ["Lock front door"])
    }

    func testIncompleteClosingDuties_excludesWeeklyDuties() {
        // Arrange: a weekly duty (phase == nil) and a closing daily duty,
        // both incomplete. Weekly checklists have phase nil by design
        // (CONTEXT.md + Models/Checklist.swift) — they are structurally
        // not "closing" and must be excluded.
        let day = BusinessDay()
        context.insert(day)
        let weekly = makeDuty(title: "Sharpen knives", cadence: .weekly, phase: nil)
        let closing = makeDuty(title: "Lock front door", cadence: .daily, phase: .closing)
        try? context.save()

        // Act
        let result = FinishDayPolicy.incompleteClosingDuties(in: [weekly, closing], businessDay: day)

        // Assert
        XCTAssertEqual(result.map(\.title), ["Lock front door"])
    }

    func testIncompleteClosingDuties_excludesOrphanedDuties() {
        // Arrange: a duty with no checklist (orphaned — e.g. its
        // checklist was deleted, which `.cascade` would normally also
        // delete the duty, but a manual store edit could orphans it).
        // Such a duty can't be "closing" — there's no checklist to
        // derive phase from — and must be silently skipped rather than
        // crash. ADR 0004's history viewer handles the same nil case as
        // "Other" for logs.
        let day = BusinessDay()
        context.insert(day)
        let orphan = TaskItem(title: "Mystery duty", order: 0)
        context.insert(orphan)
        try? context.save()

        // Act
        let result = FinishDayPolicy.incompleteClosingDuties(in: [orphan], businessDay: day)

        // Assert
        XCTAssertTrue(result.isEmpty, "orphaned duty (no checklist) is silently excluded")
    }

    // MARK: - Ordering

    func testIncompleteClosingDuties_preservesInputOrder() {
        // Arrange: three incomplete closing duties inserted in a known
        // order (the helper does not sort — the call site does). The
        // result must come back in the same order it went in so the
        // UI's bullet list is deterministic and matches the duty list.
        let day = BusinessDay()
        context.insert(day)
        let d1 = makeDuty(title: "Z-title", order: 5)
        let d2 = makeDuty(title: "A-title", order: 0)
        let d3 = makeDuty(title: "M-title", order: 3)
        try? context.save()

        // Act: pass them in a deliberately-unsorted order.
        let result = FinishDayPolicy.incompleteClosingDuties(in: [d1, d2, d3], businessDay: day)

        // Assert
        XCTAssertEqual(result.map(\.title), ["Z-title", "A-title", "M-title"])
    }
}
