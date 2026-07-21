//
//  LogEditSheet.swift
//  checklist-app
//
//  Manager-only sheet for editing a `CompletionLog`'s `note` and
//  `completedBy`. Save stamps `lastEditedAt` / `lastEditedBy` together
//  so the audit signal is atomic (nil on both = never edited). Mirrors
//  the form-sheet shape of `EditUserSheet` and `AddDutySheet`.
//
//  Per ADR 0004: `timestamp` and `duty` are NOT editable here — changing
//  either would silently move the log across business-day / week / duty
//  boundaries and break derived state. Delete + recreate is the explicit,
//  visible path for those cases. The duty title is shown read-only so the
//  manager knows which log they're editing.
//

import SwiftUI
import SwiftData

struct LogEditSheet: View {
    let log: CompletionLog

    @Environment(AuthStore.self) private var authStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \User.name) private var allUsers: [User]

    @State private var note: String
    @State private var selectedUserID: UUID?

    init(log: CompletionLog) {
        self.log = log
        // Initialize @State from the log. SwiftUI requires this pattern
        // because @State is created once at view instantiation, not on
        // each render. Same trick used in `EditUserSheet`.
        _note = State(initialValue: log.note ?? "")
        _selectedUserID = State(initialValue: log.completedBy?.id)
    }

    private var currentUser: User? { authStore.currentUser(in: modelContext) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Duty") {
                    // Read-only context: the manager needs to know which
                    // log they're editing but cannot change which duty it
                    // belongs to (ADR 0004).
                    Text(log.duty?.title ?? "(deleted duty)")
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Note")
                } footer: {
                    if let edited = log.lastEditedAt {
                        // Surface prior edit history so the manager can
                        // see this row has been touched before. The
                        // *previous* value isn't shown (deferred per ADR
                        // 0004) — just the fact of the last edit.
                        let byLine = log.lastEditedBy.map { " by \($0.name)" } ?? ""
                        Text("Last edited \(edited.formatted(date: .abbreviated, time: .shortened))\(byLine).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Completed by") {
                    Picker("User", selection: $selectedUserID) {
                        // Selection is `UUID?` so the manager can clear
                        // attribution by picking "Unattributed." The
                        // explicit Optional tags are required because
                        // Swift can't infer the nil case from context.
                        Text("Unattributed").tag(UUID?.none)
                        ForEach(allUsers) { user in
                            Text(user.name).tag(Optional(user.id))
                        }
                    }
                }
            }
            .navigationTitle("Edit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            // Defense in depth (mirrors `AddDutySheet.onAppear` in
            // `DutyListView`): the history view is manager-only, but if
            // this sheet ever surfaces via a different path (programmatic
            // presentation, navigation bug), bail out rather than let a
            // staff user mutate the audit trail.
            .onAppear {
                guard authStore.currentUser(in: modelContext)?.isManager == true else {
                    dismiss()
                    return
                }
            }
        }
    }

    // MARK: - Save

    /// Commits the local @State back to the log. Stamps `lastEditedAt`
    /// and `lastEditedBy` *together* — the audit signal is "both nil" or
    /// "both set," never one without the other.
    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        log.note = trimmed.isEmpty ? nil : trimmed
        log.completedBy = allUsers.first { $0.id == selectedUserID }
        log.lastEditedAt = .now
        log.lastEditedBy = currentUser
        try? modelContext.save()
        dismiss()
    }
}
