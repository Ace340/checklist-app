//
//  BusinessDay.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation
import SwiftData

/// The operating period from one close-out to the next. Because closings
/// land anywhere from 11pm to 2am depending on traffic, a business day is
/// ended by an explicit **"finish day"** action (not midnight), which also
/// resets the daily checklists — a fresh business day has no logs, so every
/// daily duty reads as undone via derived state. See CONTEXT.md and
/// `docs/adr/0001-derived-completion-state.md`.
@Model
final class BusinessDay {
    var openedAt: Date
    var closedAt: Date?

    /// All completion logs attributed to this business day.
    /// `.nullify`: deleting a business day keeps the logs (audit history)
    /// but clears their `businessDay` reference.
    @Relationship(deleteRule: .nullify, inverse: \CompletionLog.businessDay)
    var logs: [CompletionLog] = []

    /// The current business day is the one `BusinessDay` with `closedAt == nil`.
    var isOpen: Bool { closedAt == nil }

    init(openedAt: Date = .now, closedAt: Date? = nil) {
        self.openedAt = openedAt
        self.closedAt = closedAt
    }
}
