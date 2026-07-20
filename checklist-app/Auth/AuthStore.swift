//
//  AuthStore.swift
//  checklist-app
//
//  The current-user session. Owns the signed-in user's stable identity (a
//  UUID persisted in `UserDefaults`) and exposes the auth API used by views
//  and mutations. See `docs/adr/0002-auth-and-current-user-session.md`.
//

import Foundation
import SwiftData
import Observation

/// The current-user session. One instance lives in the SwiftUI `.environment`
/// for the lifetime of the app.
///
/// The PIN itself is **never** persisted — only the `UUID` of the user who
/// last signed in. This is the deliberate point of the "trust the session
/// until sign-out" model: the user enters their PIN once, the resulting
/// session survives backgrounding and relaunch, and any new `CompletionLog`
/// they create is attributed to that user until they explicitly hand off.
///
/// The current `User` object is fetched from SwiftData on demand rather
/// than cached, so the store never holds a stale reference across day
/// rollovers or model-context resets. The UUID is the only persistent state.
@Observable
final class AuthStore {
    /// UserDefaults key for the signed-in user's UUID string.
    private static let currentUserIDKey = "checklist-app.currentUserID"

    /// The signed-in user's stable identifier. Nil when logged out or no
    /// session has been restored yet.
    private(set) var currentUserID: UUID?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Restore a prior session if one exists. The PIN is not re-entered —
        // we trust the session until explicit sign-out, matching POS
        // clock-in / clock-out conventions.
        if let raw = defaults.string(forKey: Self.currentUserIDKey),
           let id = UUID(uuidString: raw) {
            self.currentUserID = id
        }
    }

    /// Attempts to sign in `user` with the supplied PIN. On success, the
    /// user becomes current and the session is persisted. On failure, the
    /// session is left untouched (a wrong-PIN attempt does not sign out a
    /// previously-signed-in user). Returns true iff sign-in succeeded.
    @discardableResult
    func signIn(user: User, pin: String) -> Bool {
        guard user.matchesPin(pin) else { return false }
        currentUserID = user.id
        defaults.set(user.id.uuidString, forKey: Self.currentUserIDKey)
        return true
    }

    /// Clears the current session. The next `currentUser(in:)` call returns
    /// nil and the persistence key is removed so a relaunch does not restore
    /// the prior user.
    func signOut() {
        currentUserID = nil
        defaults.removeObject(forKey: Self.currentUserIDKey)
    }

    /// Fetches the live `User` for the current session from the given
    /// context, or nil if logged out, or nil if the user was deleted since
    /// sign-in (deletion cleanly logs the session out).
    func currentUser(in context: ModelContext) -> User? {
        guard let id = currentUserID else { return nil }
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
}
