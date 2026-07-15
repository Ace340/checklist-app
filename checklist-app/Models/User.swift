//
//  User.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation
import SwiftData

/// A restaurant staff member. Role gates UI features and edit permissions.
@Model
final class User {
    var name: String
    var role: UserRole
    var createdAt: Date

    /// All completion records authored by this user.
    /// `.nullify`: if a user is deleted, keep their logs for audit history
    /// but clear the `completedBy` link.
    @Relationship(deleteRule: .nullify, inverse: \CompletionLog.completedBy)
    var logs: [CompletionLog] = []

    init(name: String, role: UserRole = .staff, createdAt: Date = .now) {
        self.name = name
        self.role = role
        self.createdAt = createdAt
    }
}

extension User {
    /// Convenience flag for gating manager-only actions in the UI.
    var isManager: Bool { role == .manager }
}
