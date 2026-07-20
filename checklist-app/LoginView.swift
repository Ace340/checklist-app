//
//  LoginView.swift
//  checklist-app
//
//  Sign-in screen shown when no current user is set. Pick-name → enter-PIN
//  flow: staff tap their name in the list, then enter their 4-digit PIN on
//  a numeric keypad. Matches POS clock-in conventions; avoids PIN-collision
//  concerns entirely (two staff with the same PIN is fine — the name
//  disambiguates). See `docs/adr/0002-auth-and-current-user-session.md`.
//

import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.modelContext) private var modelContext

    /// All users in the directory. Small list (a single restaurant's staff);
    /// safe to load all and filter/sort in Swift.
    @Query(sort: \User.name) private var users: [User]

    /// The user the staff member picked. Nil = still on the "who are you"
    /// step; non-nil = the PIN pad is showing for this user.
    @State private var selectedUser: User?

    /// The digits entered so far. Kept as a plain String so the keypad UI
    /// can render it directly (max 4 chars per `isValidPin`).
    @State private var enteredPin = ""

    /// Shows briefly after a wrong-PIN attempt. Cleared on next input.
    @State private var showingWrongPin = false

    @FocusState private var pinFieldFocused: Bool

    private var usersWhoCanSignIn: [User] {
        // Hide users without a configured PIN from the login list — they
        // can't sign in anyway, and surfacing them invites confusion
        // ("why can't I tap my name?").
        users.filter { $0.hasPin }
    }

    var body: some View {
        NavigationStack {
            if usersWhoCanSignIn.isEmpty {
                ContentUnavailableView(
                    "No Sign-In Available",
                    systemImage: "person.badge.key",
                    description: Text("Ask a manager to set up staff users.")
                )
            } else {
                List {
                    ForEach(usersWhoCanSignIn) { user in
                        Button {
                            selectedUser = user
                            enteredPin = ""
                            showingWrongPin = false
                            pinFieldFocused = true
                        } label: {
                            UserRow(user: user)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle("Who are you?")
            }
        }
        .sheet(item: $selectedUser) { user in
            PinEntrySheet(
                user: user,
                enteredPin: $enteredPin,
                showingWrongPin: $showingWrongPin,
                pinFieldFocused: $pinFieldFocused,
                onSubmit: { trySignIn(user: user) },
                onDismiss: { selectedUser = nil }
            )
            .presentationDetents([.medium])
        }
    }

    /// Attempts to sign in `user` with the currently-entered PIN. On
    /// success the sheet dismisses (the parent view flips to the area list
    /// because `authStore.currentUser` becomes non-nil). On failure, the
    /// wrong-PIN state is shown and the entry clears for retry.
    private func trySignIn(user: User) {
        let ok = authStore.signIn(user: user, pin: enteredPin)
        if ok {
            selectedUser = nil
        } else {
            showingWrongPin = true
            enteredPin = ""
        }
    }
}

// MARK: - User row

private struct UserRow: View {
    let user: User

    var body: some View {
        HStack {
            Image(systemName: user.isManager ? "person.badge.shield.checkmark" : "person")
                .foregroundStyle(user.isManager ? .purple : .accentColor)
                .frame(width: 24)
            Text(user.name)
            Spacer()
            if user.isManager {
                Text("Manager")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - PIN entry sheet

private struct PinEntrySheet: View {
    let user: User
    @Binding var enteredPin: String
    @Binding var showingWrongPin: Bool
    var pinFieldFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(user.name)
                    .font(.title2.bold())

                SecureField("Enter PIN", text: $enteredPin)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: 120)
                    .focused(pinFieldFocused)
                    .onChange(of: enteredPin) { _, newValue in
                        // Strip non-digits, clamp to PIN length. Auto-submit
                        // on the 4th digit so the staff member doesn't have
                        // to hunt for a Sign In button with wet hands.
                        let cleaned = newValue.filter { ("0"..."9").contains($0) }
                        let clamped = String(cleaned.prefix(pinLength))
                        if clamped != newValue { enteredPin = clamped }
                        if clamped.count == pinLength {
                            onSubmit()
                        }
                    }

                if showingWrongPin {
                    Text("Wrong PIN — try again")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Spacer()
            }
            .padding(32)
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
    }
}
