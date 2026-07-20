//
//  TaskItem.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation
import SwiftData

/// A single actionable duty within a checklist, ordered by `order`.
///
/// Named `TaskItem` rather than `Task` to avoid shadowing Swift's
/// concurrency `Task` type in the same module. See CONTEXT.md.
///
/// Completion state is **derived** from `CompletionLog` records — it is never
/// stored on the duty. "Done for today" means a log exists in the current
/// business day; "done this week" (for weekly duties) means a log exists in
/// the current Monday-start week. See
/// `docs/adr/0001-derived-completion-state.md` and the `DutyStatus` seam.
@Model
final class TaskItem {
    var title: String
    var order: Int

    /// Raw storage for the weekday this weekly duty is bound to. Nil for daily
    /// duties. Stored as `Int` (not `Weekday`) because SwiftData's macro
    /// resolves an optional custom enum as a relationship, not a value — so we
    /// persist the `Weekday.rawValue` and bridge via the computed `weekday`.
    /// See `Weekday` in `Scheduling/DutyStatus.swift` (Monday-first, Int-backed).
    var weekdayRawValue: Int?

    /// Parent checklist (to-one inverse). Plain optional; no @Relationship here.
    var checklist: Checklist?

    /// The weekday this weekly duty is bound to (nil for daily duties).
    /// Derived from `weekdayRawValue`; not persisted directly.
    var weekday: Weekday? {
        get { weekdayRawValue.flatMap(Weekday.init(rawValue:)) }
        set { weekdayRawValue = newValue?.rawValue }
    }

    /// Completion history for this duty.
    /// `.cascade`: deleting a duty also deletes its logs.
    @Relationship(deleteRule: .cascade, inverse: \CompletionLog.duty)
    var logs: [CompletionLog] = []

    init(title: String, order: Int, weekday: Weekday? = nil) {
        self.title = title
        self.order = order
        self.weekday = weekday
    }
}

extension TaskItem {
    /// Whether this daily duty has been completed in the given business day
    /// (ADR #1 — completion state is derived from logs, never stored on the
    /// duty itself).
    ///
    /// Compared by SwiftData identity: within a single `mainContext`, the
    /// same row returns the same instance, so `===` is correct. The
    /// `businessDay != nil` guard avoids a false positive on orphaned logs
    /// whose `businessDay` was nullified by a `BusinessDay` deletion.
    ///
    /// Lives here (not on the View) so the XCTest target can cover ADR #1's
    /// derivation with an in-memory SwiftData container.
    func isDone(in businessDay: BusinessDay) -> Bool {
        logs.contains { $0.businessDay != nil && $0.businessDay === businessDay }
    }

    /// Whether this weekly duty has been completed in the Monday-start week
    /// containing `now` (ADR #1).
    func isDoneThisWeek(asOf now: Date, calendar: Calendar) -> Bool {
        let interval = mondayStartWeekInterval(containing: now, calendar: calendar)
        return logs.contains { interval.contains($0.timestamp) }
    }
}
