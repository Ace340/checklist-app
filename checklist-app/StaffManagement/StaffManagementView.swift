//
//  StaffManagementView.swift
//  checklist-app
//
//  Manager-only UI for managing the user directory: add, rename, promote/
//  demote, reset PIN, delete. Opens from a gear icon in `AreaListView`'s
//  toolbar (gated on `currentUser.isManager`). Every mutation re-validates
//  via the pure helpers in `StaffManagement/StaffManagement.swift` before
//  touching the store — the UI is a thin shell over those rules.
//
//  See `docs/adr/0003-staff-management-and-duty-permissions.md` for the
//  locked-in policies: self-protection (no demote/delete self) and
//  last-manager protection (store always retains >=1 manager).
//

import SwiftUI
import SwiftData

struct StaffManagementView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \User.name) private var users: [User]

    @State private var showingAddUser = false
    @State private var editingUser: User?

    var body: some View {
        NavigationStack {
            List {
                ForEach(users) { user in
                    Button {
                        editingUser = user
                    } label: {
                        UserManagementRow(user: user)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Staff")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingAddUser = true
                    } label: {
                        Label("Add User", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: { dismiss() })
                }
            }
            .sheet(isPresented: $showingAddUser) {
                AddUserSheet()
            }
            .sheet(item: $editingUser) { user in
                EditUserSheet(user: user)
            }
        }
    }
}

// MARK: - Row

private struct UserManagementRow: View {
    let user: User

    var body: some View {
        HStack {
            Image(systemName: user.isManager ? "person.badge.shield.checkmark" : "person")
                .foregroundStyle(user.isManager ? .purple : .accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                if !user.hasPin {
                    Text("No PIN set")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if user.isManager {
                Text("Manager")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Add user

private struct AddUserSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var role: UserRole = .staff
    @State private var pin = ""
    @State private var attemptedSubmission = false

    var body: some View {
        NavigationStack {
            Form {
                Section("User") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .submitLabel(.next)
                    Picker("Role", selection: $role) {
                        Text("Staff").tag(UserRole.staff)
                        Text("Manager").tag(UserRole.manager)
                    }
                }

                Section {
                    SecureField("4-digit PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: pin) { _, newValue in
                            let cleaned = newValue.filter { ("0"..."9").contains($0) }
                            let clamped = String(cleaned.prefix(pinLength))
                            if clamped != newValue { pin = clamped }
                        }
                } header: {
                    Text("PIN")
                } footer: {
                    if attemptedSubmission, let reason = validationFailure {
                        Text(reason).foregroundStyle(.red)
                    } else {
                        Text("The user will enter this at first sign-in. It can be reset later.")
                    }
                }
            }
            .navigationTitle("New User")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: submit)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var validationFailure: String? {
        if trimmedName.isEmpty { return "Enter a name." }
        if !isValidPin(pin) { return "PIN must be exactly 4 digits." }
        return nil
    }

    private func submit() {
        attemptedSubmission = true
        guard validationFailure == nil else { return }

        let user = User(name: trimmedName, role: role)
        try? user.setPin(pin)
        modelContext.insert(user)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit user

private struct EditUserSheet: View {
    let user: User

    @Environment(AuthStore.self) private var authStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// All users — needed for the last-manager check in `StaffManagement`.
    @Query private var allUsers: [User]

    @State private var name: String
    @State private var role: UserRole
    @State private var showingResetPin = false
    @State private var showingDeleteConfirm = false
    @State private var attemptedSave = false

    init(user: User) {
        self.user = user
        // Initialize @State from the user. SwiftUI requires this pattern
        // because @State is created once at view instantiation.
        _name = State(initialValue: user.name)
        _role = State(initialValue: user.role)
    }

    private var currentUser: User? { authStore.currentUser(in: modelContext) }

    var body: some View {
        NavigationStack {
            Form {
                Section("User") {
                    TextField("Name", text: $name)
                }

                Section {
                    Picker("Role", selection: $role) {
                        Text("Staff").tag(UserRole.staff)
                        Text("Manager").tag(UserRole.manager)
                    }
                    .disabled(!canChangeRole)
                } header: {
                    Text("Role")
                } footer: {
                    if let reason = roleChangeBlockedReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("PIN") {
                    Button("Reset PIN", action: { showingResetPin = true })
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Text("Delete User")
                    }
                    .disabled(!canDelete)
                    if let reason = deleteBlockedReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit User")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .sheet(isPresented: $showingResetPin) {
                ResetPinSheet(user: user)
            }
            .alert("Delete \(user.name)?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: delete)
            } message: {
                Text("Their completion logs will be preserved but no longer attributed to them.")
            }
        }
    }

    // MARK: - Permission-derived UI state

    private var canChangeRole: Bool {
        guard let current = currentUser else { return false }
        if user.role == .staff {
            return StaffManagement.canPromote(user: user, currentUser: current)
        } else {
            return StaffManagement.canDemote(user: user, currentUser: current, allUsers: allUsers)
        }
    }

    /// Localized explanation of why the role picker is disabled. Returns nil
    /// when the picker is enabled. Surfacing the reason inline saves the
    /// manager from "why can't I tap that?" confusion during service.
    private var roleChangeBlockedReason: String? {
        guard let current = currentUser else { return nil }
        if current.id == user.id && user.isManager {
            return "You can't change your own role. Ask another manager to demote you."
        }
        if user.isManager && !StaffManagement.canDemote(user: user, currentUser: current, allUsers: allUsers) {
            return "Can't demote the only remaining manager. Promote someone else first."
        }
        return nil
    }

    private var canDelete: Bool {
        guard let current = currentUser else { return false }
        return StaffManagement.canDelete(user: user, currentUser: current, allUsers: allUsers)
    }

    private var deleteBlockedReason: String? {
        guard let current = currentUser else { return nil }
        if current.id == user.id {
            return "You can't delete your own account. Ask another manager."
        }
        if user.isManager && !StaffManagement.canDelete(user: user, currentUser: current, allUsers: allUsers) {
            return "Can't delete the only remaining manager."
        }
        return nil
    }

    // MARK: - Mutations

    /// Commits the local @State back to the `User` model. Only writes if
    /// the corresponding `StaffManagement` helper allows it — defends
    /// against any state drift where the picker was enabled but the rule
    /// says no (e.g. another manager was deleted mid-edit).
    private func save() {
        attemptedSave = true
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let current = currentUser else { return }

        if trimmed != user.name {
            user.name = trimmed
        }

        if role != user.role {
            if role == .manager && StaffManagement.canPromote(user: user, currentUser: current) {
                user.role = .manager
            } else if role == .staff && StaffManagement.canDemote(user: user, currentUser: current, allUsers: allUsers) {
                user.role = .staff
            }
            // If neither branch matches, the picker was disabled — leave
            // role untouched rather than force an invalid transition.
        }

        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let current = currentUser,
              StaffManagement.canDelete(user: user, currentUser: current, allUsers: allUsers) else { return }
        modelContext.delete(user)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Reset PIN

private struct ResetPinSheet: View {
    let user: User

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var attemptedSubmission = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New 4-digit PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: pin) { _, newValue in
                            let cleaned = newValue.filter { ("0"..."9").contains($0) }
                            let clamped = String(cleaned.prefix(pinLength))
                            if clamped != newValue { pin = clamped }
                        }
                    SecureField("Confirm PIN", text: $confirmPin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: confirmPin) { _, newValue in
                            let cleaned = newValue.filter { ("0"..."9").contains($0) }
                            let clamped = String(cleaned.prefix(pinLength))
                            if clamped != newValue { confirmPin = clamped }
                        }
                } footer: {
                    if attemptedSubmission, let reason = validationFailure {
                        Text(reason).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Reset PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset", action: submit)
                }
            }
        }
    }

    private var validationFailure: String? {
        if !isValidPin(pin) { return "PIN must be exactly 4 digits." }
        if pin != confirmPin { return "PINs don't match." }
        return nil
    }

    private func submit() {
        attemptedSubmission = true
        guard validationFailure == nil else { return }
        try? user.setPin(pin)
        try? modelContext.save()
        dismiss()
    }
}
