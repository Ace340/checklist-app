//
//  Enums.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation

/// The kind of checklist, defining when it runs in the restaurant's schedule.
/// Stored directly by SwiftData because the value set is fixed and small.
enum ChecklistType: String, Codable, CaseIterable {
    case opening
    case closing
    case weekly
}

/// A staff member's permission level. SwiftData persists the raw value;
/// access control itself is enforced in app logic (`user.role == .manager`).
enum UserRole: String, Codable, CaseIterable {
    case staff
    case manager
}
