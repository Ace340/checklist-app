//
//  Checklist.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation
import SwiftData

/// A named checklist of one type (opening, closing, or weekly) that owns
/// an ordered list of tasks.
@Model
final class Checklist {
    var title: String
    var type: ChecklistType
    var createdAt: Date
    var updatedAt: Date

    /// The ordered tasks within this checklist.
    /// `.cascade`: deleting a checklist also deletes its tasks (and, via
    /// TaskItem's own cascade, their completion logs).
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.checklist)
    var tasks: [TaskItem] = []

    init(title: String, type: ChecklistType, createdAt: Date = .now) {
        self.title = title
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
