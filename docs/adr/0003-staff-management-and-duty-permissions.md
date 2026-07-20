# Staff management and duty editing are manager-only; the first manager is created by an onboarding wizard

The app gains its first role-gated administrative surfaces. A manager can add, rename, promote/demote, reset the PIN of, and delete users; a manager can add (and, when such UI exists, edit or delete) duties. Staff see the operational surface only — they complete duties and switch users. The seeded demo users (`Manager/0000`, `Staff/1111`) are removed; the first manager is instead created by a one-time onboarding wizard shown when the SwiftData store has zero users.

This ADR extends ADR 0002 (which established the `User`/PIN/`AuthStore` model and deferred this surface as a follow-up); it does not revise any of ADR 0002's decisions.

## Decisions

- **Onboarding wizard on first launch.** When the SwiftData store has zero users, the app shows `OnboardingView` instead of `ContentView`. It collects the first manager's name and a 4-digit PIN (entered twice for confirmation), creates exactly one `User` with `role: .manager`, sets their PIN, signs them in, and never shows again. There is no `UserDefaults` flag — first-launch is derived from the store so a UserDefaults wipe can't strand the app on onboarding with users already present.
- **Manager-only actions, gated by `currentUser.isManager`.** Creating a user, editing any user's name/role/PIN, deleting a user, and adding a duty (`TaskItem`) are gated on the *signed-in* current user being a manager. Consistent with ADR 0002's Finish Day gate.
- **Hide, don't disable, manager-only UI.** Staff never see the + button on `DutyListView`, the gear icon in `AreaListView`'s toolbar, or `StaffManagementView`. Hiding is cleaner than greying and avoids inviting "why can't I tap that" questions during service.
- **`StaffManagement` is a namespace of pure permission helpers** (`canDelete(user:currentUser:allUsers:)`, `canPromote(user:currentUser:allUsers:)`, etc.), not methods on `User`. Pure functions, framework-free, unit-testable — mirrors `PinHasher`'s pattern. The UI is a thin shell over these.
- **Self-protection: a manager cannot delete or demote themselves.** Prevents the "I demoted myself and now nobody can manage users" footgun. To hand off management, they promote someone else first, switch user, then have the new manager demote them.
- **Last-manager protection: the store must always retain at least one manager.** `canDemote` and `canDelete` return false when the candidate is the only manager. Without this, onboarding + a careless demotion could orphan the app.
- **Forgotten-PIN recovery is in scope.** A manager can reset any non-self user's PIN to a new 4-digit value. Closes ADR 0002's deferred "Forgotten PIN recovery" item.
- **UI home: gear icon in `AreaListView` toolbar.** Sits beside the existing Switch User button. Opens `StaffManagementView` as a `.sheet` — `NavigationStack` + `List` of users with add/edit/delete via nested sheets. Follows the existing `AddDutySheet` shape.
- **Onboarding completion auto-signs-in.** The wizard sets `AuthStore.currentUserID` after creating the manager. The manager just chose a PIN; making them re-enter it 200ms later is friction without purpose.

## Threat model (unchanged from ADR 0002)

Nothing structural changes. The PIN's job is still audit attribution, not protecting money or PII. The new risk surface — a manager creating users — is itself manager-gated, so the only escalation beyond "I know a PIN" is "I know a *manager's* PIN," which is what a manager is. The onboarding wizard sets the first PIN with no authentication, which is acceptable because the person holding a freshly-installed device is definitionally the operator; after onboarding, every user-creating action requires a signed-in manager.

## What changes in the existing model

- **`User`** — no schema change. Already has `role`, `setPin`, `matchesPin`, `hasPin`, `logs` relationship (`.nullify` so deleting a user preserves their audit trail with `completedBy` cleared).
- **`checklist_appApp.swift`** — `seedOnLaunch` stops creating demo users entirely. First-launch detection: a `@Query` for users; if empty, render `OnboardingView`, otherwise `ContentView`. The `AuthStore` is shared across both paths so onboarding can sign in on completion.
- **`ContentView.swift` (`AreaListView`)** — gains a gear-icon toolbar item, manager-only, opening `StaffManagementView` as a sheet. Sits beside the existing Switch User button.
- **`ContentView.swift` (`DutyListView`)** — the + button and `AddDutySheet` presentation are wrapped in `if authStore.currentUser?.isManager == true`. The sheet re-checks on appear (defense in depth; future-proofs against navigation-edge bugs).
- **New file `checklist-app/Onboarding/OnboardingView.swift`** — multi-step wizard (name → PIN → confirm → done). Uses `@Environment(AuthStore.self)` to sign in on completion; `@Environment(\.modelContext)` to insert the manager.
- **New file `checklist-app/StaffManagement/StaffManagementView.swift`** — list of users + add/edit/delete/reset-PIN sheets. All mutations re-validate via the `StaffManagement` helpers before touching the store.
- **New file `checklist-app/StaffManagement/StaffManagement.swift`** — pure helpers. Framework-free, mirrors `PinHasher`. UI calls these and only mutates the store when they return true.

## Rejected alternatives

- **Hardcoded seed (`Manager/0000`).** Was the ADR 0002 placeholder. Rejected because (a) documenting production-default PINs in an ADR is a smell; (b) doesn't match real deployment (each restaurant's first manager is a different person); (c) the seed is recreated if a developer wipes the store, masking bugs.
- **Onboarding via plist / out-of-app config.** No UX-friendly way to update later, and contradicts the in-app management model once it exists.
- **Three-role model (owner / manager / staff).** Pre-emptive complexity. Nothing in the roadmap needs a third tier; if one appears (e.g. a read-only owner dashboard), promoting `UserRole` to a larger enum is a contained change.
- **Server-side auth / accounts.** Contradicts ADR 0002's single-device, single-restaurant model. Same rejection as in 0002.
- **Disable manager-only UI instead of hiding.** Greyed-out + buttons during a busy service invite questions and tap-nothing feedback loops. Hide is cleaner.
- **PIN rotation expiry.** Adds friction for no documented threat. Defer until a real requirement surfaces.
- **Allow staff to add duties.** Explicitly rejected by the feature spec — managers are the only editors of the duty catalog. Staff are operators, not curators.
- **Row-level security at the SwiftData layer.** SwiftData does not enforce access control (per `Enums.swift` doc comment). Gating is, and will remain, the app's job.

## Open questions deferred to follow-ups

- **Bulk staff import** (CSV / paste-a-list). Real restaurants onboard 10-30 staff at once. Out of scope for this feature; revisit when a multi-add painful enough to surface.
- **Audit trail of management actions** ("who promoted whom," "who reset whose PIN"). Today's `CompletionLog` only captures duty completions. A separate `ManagementActionLog` aggregate would be the right shape if this surfaces as a need.
- **Required PIN complexity / rotation.** Same as ADR 0002 — soft credentials, low blast radius. Revisit only if threat model escalates.
- **Edit/delete UI for duties.** This ADR locks in the *permission model* (manager-only) but the duty-catalog editor itself is its own piece of UI work, tracked separately.
