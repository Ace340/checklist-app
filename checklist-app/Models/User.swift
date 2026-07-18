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

    /// Raw storage for the user's role. Stored as `String` (not `UserRole`)
    /// because SwiftData's predicate validator rejects keypaths through
    /// `.rawValue` on Codable-enum properties at runtime (fatalError in
    /// `SwiftData/Schema.swift:346`). Persist the raw value directly so
    /// predicates can match it (`$0.roleRawValue == "manager"`), and bridge
    /// to `UserRole` via the computed `role`. Mirrors the `weekdayRawValue`
    /// pattern on `TaskItem`.
    var roleRawValue: String

    var createdAt: Date

    /// All completion records authored by this user.
    /// `.nullify`: if a user is deleted, keep their logs for audit history
    /// but clear the `completedBy` link.
    @Relationship(deleteRule: .nullify, inverse: \CompletionLog.completedBy)
    var logs: [CompletionLog] = []

    init(name: String, role: UserRole = .staff, createdAt: Date = .now) {
        self.name = name
        self.roleRawValue = role.rawValue
        self.createdAt = createdAt
    }

    /// The user's role, bridged from `roleRawValue`. If the persisted raw
    /// value is somehow invalid (manual store edit, schema drift), falls
    /// back to `.staff` rather than trapping.
    var role: UserRole {
        get { UserRole(rawValue: roleRawValue) ?? .staff }
        set { roleRawValue = newValue.rawValue }
    }
}

extension User {
    /// Convenience flag for gating manager-only actions in the UI.
    var isManager: Bool { role == .manager }
}
