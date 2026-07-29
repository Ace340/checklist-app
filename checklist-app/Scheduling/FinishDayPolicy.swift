//
//  FinishDayPolicy.swift
//  checklist-app
//
//  Pure, framework-free helper governing which duties should be called
//  out when a manager attempts to finish the business day. The UI layer
//  (`AreaListView`) calls this and decides how to surface the result
//  (today: a warn-and-confirm `.alert` listing the duties); this module
//  never touches SwiftData/SwiftUI, so its filtering rule is fully
//  testable. Tests that exercise `@Relationship` traversal use an
//  in-memory container (see `FinishDayPolicyTests`).
//
//  Rule locked in by
//  `docs/adr/0006-finish-day-with-incomplete-closing-duties.md`:
//  a Finish Day attempt with closing daily duties not yet completed in
//  the current business day produces a warn prompt. The list of
//  incomplete closing duties is computed from existing derived state
//  (ADR 0001) — no new persisted flag, no model change.
//
//  Mirrors the `Scheduling/BusinessDayHealth.swift` and
//  `History/LogRetention.swift` pattern: helpers collected as a
//  `caseless enum` namespace.
//

import Foundation

/// Namespace for finish-day policy checks. `caseless enum` so it can't
/// be accidentally instantiated — same trick used for `BusinessDayHealth`
/// and `LogRetention`.
enum FinishDayPolicy {

    /// Returns the closing daily duties in `duties` that are not yet
    /// completed in `businessDay` — the list a manager should see before
    /// the business day is closed.
    ///
    /// A "closing duty" is a daily duty whose `checklist.phase == .closing`.
    /// Weekly duties are excluded by construction (weekly checklists have
    /// `phase == nil`; weekly duties are bound to a `Weekday`, not a
    /// `Phase` — see `Models/Checklist.swift` and CONTEXT.md). Opening
    /// daily duties are excluded by definition. Duties whose `checklist`
    /// is nil (orphaned — e.g. their checklist was deleted) are excluded;
    /// they don't belong to any checklist and so can't be "closing."
    /// ADR 0004's history viewer surfaces orphans separately as "Other."
    ///
    /// Completion is derived per ADR 0001: a duty is "done" in a business
    /// day iff a `CompletionLog` exists in that day. No new persisted
    /// state is introduced.
    ///
    /// Input order is preserved — matters for predictable UI rendering
    /// (the alert lists duties in the same order the manager sees them
    /// in `DutyListView`, sorted by `order` at the call site).
    static func incompleteClosingDuties(
        in duties: [TaskItem],
        businessDay: BusinessDay
    ) -> [TaskItem] {
        duties.filter { duty in
            guard let list = duty.checklist else { return false }
            guard list.cadence == .daily, list.phase == .closing else { return false }
            return !duty.isDone(in: businessDay)
        }
    }
}
