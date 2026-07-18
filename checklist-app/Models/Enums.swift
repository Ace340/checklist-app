//
//  Enums.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation

/// Which side of the restaurant a checklist belongs to — FOH (Front of House)
/// or BOH (Back of House). The primary grouping on the home screen.
/// See CONTEXT.md.
enum Area: String, Codable, CaseIterable {
    case foh
    case boh
}

/// How often a duty recurs. A **daily** duty runs every day in either the
/// Opening or Closing phase. A **weekly** duty is bound to a specific day of
/// the week (`TaskItem.weekday`) and surfaces only on that day.
/// See CONTEXT.md.
enum Cadence: String, Codable, CaseIterable {
    case daily
    case weekly
}

/// The stage of the service day a daily checklist covers — Opening or Closing.
/// Nil for weekly checklists (weekly duties have no phase; they have a weekday).
/// Avoid: "stage" (in restaurants a *stage* is an unpaid kitchen intern).
/// See CONTEXT.md.
enum Phase: String, Codable, CaseIterable {
    case opening
    case closing
}

/// A staff member's permission level. SwiftData persists the raw value;
/// access control itself is enforced in app logic (`user.role == .manager`).
/// SwiftData enforces no row-level security — gating is the app's job.
enum UserRole: String, Codable, CaseIterable {
    case staff
    case manager
}
