//
//  DutyStatus.swift
//  checklist-app
//
//  Pure, framework-free scheduling logic. No SwiftData, no SwiftUI.
//  Testable with `swiftc` alone. See docs/adr/0001-derived-completion-state.md.
//

import Foundation

/// A day of the week, Monday-first. Weekly duties are bound to one of these
/// (see `Cadence` in CONTEXT.md). Monday-first because the restaurant week
/// rolls over on Monday.
enum Weekday: Int, Comparable {
    case monday = 0
    case tuesday = 1
    case wednesday = 2
    case thursday = 3
    case friday = 4
    case saturday = 5
    case sunday = 6

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// The scheduling status of a duty, derived — never stored. See ADR #1.
///
/// - `pending`: a daily duty not yet done in the current business day.
/// - `done`: completed in the current period (business day for daily,
///   Monday-start week for weekly).
/// - `notYetDue`: a weekly duty whose weekday hasn't arrived yet this week.
/// - `due`: a weekly duty whose weekday is today, not yet done this week.
/// - `overdue`: a weekly duty whose weekday has passed, still not done this week.
enum DutyStatus: Equatable {
    case pending
    case done
    case notYetDue
    case due
    case overdue
}

/// Maps a `Date` to its `Weekday` using a Monday-first convention, regardless
/// of `Calendar`'s Sunday-first `weekday` component (1=Sunday ... 7=Saturday).
func weekday(of date: Date, calendar: Calendar) -> Weekday {
    switch calendar.component(.weekday, from: date) {
    case 1: return .sunday
    case 2: return .monday
    case 3: return .tuesday
    case 4: return .wednesday
    case 5: return .thursday
    case 6: return .friday
    case 7: return .saturday
    default: fatalError("Calendar returned invalid weekday component")
    }
}

/// The status of a **weekly** duty on a given day.
///
/// A weekly duty is invisible before its weekday (`.notYetDue`), due on its
/// weekday, and overdue through the end of the week if still undone — clearing
/// at the Monday-start week rollover. "Done this week" is supplied by the
/// caller, who derives it from completion logs (ADR #1).
func weeklyDutyStatus(
    scheduled: Weekday,
    now: Date,
    completedThisWeek: Bool,
    calendar: Calendar
) -> DutyStatus {
    let today = weekday(of: now, calendar: calendar)
    // Completion wins regardless of day: a duty done early (before its weekday)
    // is done for the week.
    if completedThisWeek { return .done }
    if today < scheduled { return .notYetDue }
    if today == scheduled { return .due }
    return .overdue
}

/// The status of a **daily** duty. Whether it's done depends only on whether a
/// completion log exists in the current business day (supplied by the caller,
/// per ADR #1). Phase (opening/closing) affects ordering in the UI, not status.
func dailyDutyStatus(completedInCurrentBusinessDay: Bool) -> DutyStatus {
    completedInCurrentBusinessDay ? .done : .pending
}

/// Whether a duty of the given status should be shown to staff today.
///
/// Daily duties always surface (pending or done). Weekly duties surface from
/// their weekday onward — including done and overdue — but are hidden before
/// their weekday arrives (`.notYetDue`).
func shouldSurface(_ status: DutyStatus) -> Bool {
    status != .notYetDue
}

/// The Monday-start week interval containing `date`. Used to scope "done this
/// week" log queries for weekly duties (ADR #1).
func mondayStartWeekInterval(containing date: Date, calendar: Calendar) -> DateInterval {
    var cal = calendar
    cal.firstWeekday = 2 // Calendar is Sunday-first (1); 2 forces Monday-start
    return cal.dateInterval(of: .weekOfYear, for: date)!
}

/// Whether two dates fall in the same Monday-start week.
func sameWeek(_ a: Date, _ b: Date, calendar: Calendar) -> Bool {
    mondayStartWeekInterval(containing: a, calendar: calendar)
        == mondayStartWeekInterval(containing: b, calendar: calendar)
}
