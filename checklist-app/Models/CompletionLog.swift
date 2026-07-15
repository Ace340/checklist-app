//
//  CompletionLog.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation
import SwiftData

/// An audit record capturing who completed a task and when.
/// Belongs to one TaskItem and (optionally) one User.
@Model
final class CompletionLog {
    var timestamp: Date
    var note: String?

    /// The task this log records (to-one inverse). Plain optional.
    var task: TaskItem?

    /// The user who completed the task (to-one inverse). Plain optional;
    /// `.nullify` on the User side keeps this log even if the user is deleted.
    var completedBy: User?

    init(timestamp: Date = .now, note: String? = nil) {
        self.timestamp = timestamp
        self.note = note
    }
}
