//
//  TaskItem.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation
import SwiftData

/// A single actionable item within a checklist, ordered by `order`.
///
/// Named `TaskItem` rather than `Task` to avoid shadowing Swift's
/// concurrency `Task` type in the same module.
@Model
final class TaskItem {
    var title: String
    var order: Int
    var isCompleted: Bool
    var completedAt: Date?

    /// Parent checklist (to-one inverse). Plain optional; no @Relationship here.
    var checklist: Checklist?

    /// Completion history for this task.
    /// `.cascade`: deleting a task also deletes its logs.
    @Relationship(deleteRule: .cascade, inverse: \CompletionLog.task)
    var logs: [CompletionLog] = []

    init(title: String, order: Int, isCompleted: Bool = false) {
        self.title = title
        self.order = order
        self.isCompleted = isCompleted
        self.completedAt = nil
    }
}
