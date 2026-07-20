//
//  OnboardingView.swift
//  checklist-app
//
//  First-launch wizard. Shown by `ContentView` when the SwiftData store has
//  zero users — collects the first manager's name and a 4-digit PIN (entered
//  twice for confirmation), creates the user, signs them in, and never shows
//  again. Replaces ADR 0002's seeded demo users (`Manager/0000`, `Staff/1111`)
//  per `docs/adr/0003-staff-management-and-duty-permissions.md`.
//
//  First-launch is **store-derived**, not flag-based: a `@Query` in the root
//  view counts users, so a UserDefaults wipe can't strand the app on
//  onboarding with users already present (or skip onboarding with none).
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var attemptedSubmission = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set up this device")
                            .font(.headline)
                        Text("Create the first manager account. Additional staff are added later from the Staff screen — only managers can do that.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Manager name") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .submitLabel(.next)
                }

                Section {
                    SecureField("4-digit PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: pin) { _, newValue in
                            // Same input-shaping rule as LoginView's PIN pad:
                            // digits only, clamp to PIN length.
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
                } header: {
                    Text("PIN")
                } footer: {
                    if attemptedSubmission, let reason = validationFailure {
                        Text(reason)
                            .foregroundStyle(.red)
                    } else {
                        Text("Used at sign-in to attribute your duty completions. Can be reset later by you or another manager.")
                    }
                }
            }
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Manager", action: submit)
                }
            }
        }
        .interactiveDismissDisabled(true)
    }

    // MARK: - Validation

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    /// Returns nil if input is valid, otherwise a user-facing reason string.
    /// Order matters: check name first, then PIN format, then PIN match —
    /// surface the most actionable problem first.
    private var validationFailure: String? {
        if trimmedName.isEmpty { return "Enter a name." }
        if !isValidPin(pin) { return "PIN must be exactly 4 digits." }
        if pin != confirmPin { return "PINs don't match." }
        return nil
    }

    // MARK: - Submit

    /// Validates, creates the manager, sets their PIN, signs them in. The
    /// root `ContentView` will flip to the area list as soon as
    /// `authStore.currentUserID` is set.
    private func submit() {
        attemptedSubmission = true
        guard validationFailure == nil else { return }

        let manager = User(name: trimmedName, role: .manager)
        // `setPin` can only throw `invalidFormat`, which `isValidPin` above
        // already rules out. The `try?` is belt-and-braces against a future
        // condition where `setPin` becomes stricter than `isValidPin`.
        try? manager.setPin(pin)
        modelContext.insert(manager)
        try? modelContext.save()

        _ = authStore.signIn(user: manager, pin: pin)
    }
}
