//
//  User.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation
import SwiftData

/// A restaurant staff member. Role gates UI features and edit permissions;
/// a 4-digit PIN identifies them at sign-in so their `CompletionLog`s carry
/// attribution. See `docs/adr/0002-auth-and-current-user-session.md`.
@Model
final class User {
    /// Stable identifier used for session persistence (the `AuthStore` keeps
    /// this UUID in `UserDefaults`) and for future history-viewer filtering.
    /// Shadows `PersistentModel.id` (a `PersistentIdentifier`) because that
    /// type is not `Codable` and cannot round-trip through `UserDefaults`.
    var id: UUID

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

    /// Per-user salt regenerated on every `setPin` call. Empty `Data` when
    /// no PIN is set. Stored as `Data` (SwiftData value attribute) so the
    /// `hashPin` API can consume it directly without hex round-tripping.
    var pinSalt: Data

    /// SHA-256 hash of (PIN ‖ salt), hex-encoded. Nil when no PIN is set —
    /// the user exists in the directory but cannot sign in until a manager
    /// assigns them one.
    var pinHash: String?

    /// All completion records authored by this user.
    /// `.nullify`: if a user is deleted, keep their logs for audit history
    /// but clear the `completedBy` link.
    @Relationship(deleteRule: .nullify, inverse: \CompletionLog.completedBy)
    var logs: [CompletionLog] = []

    init(
        name: String,
        role: UserRole = .staff,
        createdAt: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.roleRawValue = role.rawValue
        self.createdAt = createdAt
        self.pinSalt = Data()
        self.pinHash = nil
    }

    /// The user's role, bridged from `roleRawValue`. If the persisted raw
    /// value is somehow invalid (manual store edit, schema drift), falls
    /// back to `.staff` rather than trapping.
    var role: UserRole {
        get { UserRole(rawValue: roleRawValue) ?? .staff }
        set { roleRawValue = newValue.rawValue }
    }

    /// Sets or replaces the user's PIN. Generates a fresh salt so a PIN
    /// change invalidates the old hash even if the new PIN happens to match
    /// the old. Throws `PinError.invalidFormat` if `pin` is not 4 ASCII
    /// digits — callers should pre-validate with `isValidPin` at the UI layer.
    func setPin(_ pin: String) throws {
        guard isValidPin(pin) else { throw PinError.invalidFormat }
        let salt = generateSalt()
        self.pinSalt = salt
        self.pinHash = hashPin(pin, salt: salt)
    }

    /// Returns true iff `pin` matches the stored hash. Returns false if no
    /// PIN is set — a never-configured user cannot sign in (so a stale
    /// seed or partial setup doesn't open a back door).
    func matchesPin(_ pin: String) -> Bool {
        guard let stored = pinHash, !pinSalt.isEmpty else { return false }
        return hashPin(pin, salt: pinSalt) == stored
    }
}

extension User {
    /// Convenience flag for gating manager-only actions in the UI.
    var isManager: Bool { role == .manager }

    /// Whether this user has a PIN configured and can therefore sign in.
    /// Surfaced as a property (not just `matchesPin` returning false) so
    /// the UI can distinguish "no PIN set" from "wrong PIN entered" when
    /// deciding what message to show.
    var hasPin: Bool { pinHash != nil && !pinSalt.isEmpty }
}
