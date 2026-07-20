//
//  StaffManagement.swift
//  checklist-app
//
//  Pure, framework-free permission helpers governing who may create,
//  edit, promote, demote, and delete users. The UI layer is a thin shell
//  over these — all rule logic lives here so it can be unit-tested without
//  a SwiftData container or SwiftUI environment.
//
//  Rules locked in by `docs/adr/0003-staff-management-and-duty-permissions.md`:
//   1. Every mutating action requires the current user to be a manager.
//   2. Self-protection: a manager cannot demote or delete themselves.
//   3. Last-manager protection: the store must always retain >=1 manager.
//
//  Mirrors the `Auth/PinHasher.swift` pattern: top-level functions
//  (collected here as a `caseless enum` namespace) that compose into the
//  model + UI layers above.
//

import Foundation

/// Namespace for staff-management permission checks. `caseless enum` so it
/// can't be accidentally instantiated — same trick the stdlib uses for
/// `Mirror` and others.
enum StaffManagement {

    /// True iff `currentUser` may create a new user. Manager-only.
    static func canCreateUser(currentUser: User) -> Bool {
        currentUser.isManager
    }

    /// True iff `currentUser` may rename `user` or reset `user`'s PIN.
    /// Manager-only; a manager can do this for any user including themselves
    /// (their own name and PIN are theirs to change).
    static func canEdit(user: User, currentUser: User) -> Bool {
        currentUser.isManager
    }

    /// True iff `currentUser` may promote `user` from staff to manager.
    /// Returns false when `user` is already a manager (no-op — the promote
    /// button should hide). No self-protection concern: `currentUser` is
    /// already a manager if they got here.
    static func canPromote(user: User, currentUser: User) -> Bool {
        currentUser.isManager && user.role == .staff
    }

    /// True iff `currentUser` may demote `user` from manager to staff.
    /// False when:
    ///   - `currentUser` is not a manager
    ///   - `user` is not currently a manager (nothing to demote)
    ///   - `user` is `currentUser` (self-protection)
    ///   - `user` is the only manager in `allUsers` (last-manager protection)
    ///
    /// `allUsers` is the full user list — typically the result of a `@Query`
    /// in the UI layer. Passing a partial list triggers last-manager
    /// protection defensively, which is the safer failure mode.
    static func canDemote(user: User, currentUser: User, allUsers: [User]) -> Bool {
        guard currentUser.isManager else { return false }
        guard user.isManager else { return false }
        guard user.id != currentUser.id else { return false }
        return allUsers.filter(\.isManager).count > 1
    }

    /// True iff `currentUser` may delete `user`.
    /// False when:
    ///   - `currentUser` is not a manager
    ///   - `user` is `currentUser` (self-protection)
    ///   - `user` is a manager and is the only manager in `allUsers`
    ///     (last-manager protection)
    ///
    /// Deleting a staff user is always allowed (when current is a manager
    /// and not self). Deleting a manager requires another manager to remain.
    /// `User.logs` uses `.nullify`, so deletion preserves audit history
    /// with `completedBy` cleared — see ADR 0002.
    static func canDelete(user: User, currentUser: User, allUsers: [User]) -> Bool {
        guard currentUser.isManager else { return false }
        guard user.id != currentUser.id else { return false }
        if user.isManager {
            return allUsers.filter(\.isManager).count > 1
        }
        return true
    }
}
