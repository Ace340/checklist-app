//
//  CompletionLog.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation
import SwiftData

/// An audit record capturing who completed a duty and when. Belongs to
/// one `TaskItem`, optionally one `User`, and exactly one `BusinessDay`.
///
/// Mutable under manager edit per
/// `docs/adr/0004-history-viewer-and-retention.md`: `note` and
/// `completedBy` may be changed, with `lastEditedAt` and `lastEditedBy`
/// stamped on every edit. `timestamp` and `duty` are immutable; for those,
/// delete and recreate. Logs roll off after a rolling 30-day retention
/// window (hard-deleted on app launch).
///
/// A completion is attributed to the business day it occurred in (a log
/// written at 1:30am Sunday belongs to Saturday's business day), so
/// business-day membership is carried by the `businessDay` reference — it
/// cannot be derived from the wall-clock `timestamp` alone. See
/// `docs/adr/0001-derived-completion-state.md`.
@Model
final class CompletionLog {
    var timestamp: Date
    var note: String?

    /// The duty this log records (to-one inverse). Plain optional.
    /// Named `duty` per CONTEXT.md's domain language (`task` is on the
    /// avoid list — collides with Swift's concurrency `Task`).
    var duty: TaskItem?

    /// The user who completed the duty (to-one inverse). Plain optional;
    /// `.nullify` on the User side keeps this log even if the user is deleted.
    var completedBy: User?

    /// The business day this completion belongs to (to-one inverse). Plain
    /// optional; `.nullify` on the BusinessDay side keeps this log (audit
    /// history) if the business day is ever deleted.
    var businessDay: BusinessDay?

    /// Set on the first manager edit and updated on every subsequent edit.
    /// `nil` means the log has never been edited — a clean signal that the
    /// row is original. See ADR 0004.
    var lastEditedAt: Date?

    /// The manager who last edited this log (to-one inverse, `.nullify` on
    /// the User side preserves the log if the editor is deleted). `nil`
    /// means the log has never been edited. See ADR 0004.
    var lastEditedBy: User?

    init(timestamp: Date = .now, note: String? = nil) {
        self.timestamp = timestamp
        self.note = note
    }
}
