# Auth is a PIN-based current-user session on a shared device

The app replaces its seeded default-manager trust model with real authentication: a staff member identifies themselves with a 4-digit PIN, becomes the **current user** for the session, and every `CompletionLog` they create is attributed to them via `completedBy`. Manager-only actions (Finish Day) gate on *the current user's* role, not on the existence of any manager in the store.

## Decisions

- **4-digit PIN**, not username/password. The PIN's job is **audit attribution** — answering "who completed this duty" — not protecting money or PII.
- **One shared device, pass-the-phone.** Restaurant reality: most staff don't get company phones. The phone sits at the host stand or expo window and is handed around. There is a "Switch User" affordance in the toolbar so handing off is one tap + a PIN.
- **One PIN per session.** Sign in at launch (or after Switch User); the current user persists until sign-out. Mirrors POS clock-in / clock-out: friction-free during a shift, easy handoff between staff.
- **Single restaurant.** `User` is not scoped to a `Restaurant` aggregate root — multi-location is explicitly out of scope (see `ROADMAP.md` Future).
- **Login flow is pick-name → enter PIN.** Staff tap their name in a list, then enter their PIN. Avoids PIN-collision concerns entirely (two staff with the same PIN is fine — the name disambiguates).
- **Session lives in an `@Observable AuthStore` in SwiftUI `.environment`.** The current user's `UUID` is persisted in `UserDefaults` so the session survives app backgrounding and relaunch; the PIN is **never** persisted — it is re-entered at every fresh sign-in.

## PIN storage and threat model

A user's PIN is stored as a SHA-256 hash of (PIN ‖ per-user salt), with the salt stored alongside the hash on the `User` row. This is deliberately simple and the ADR is honest about what it does and does not defend:

- **Defended:** casual observation of the store (a manager glancing at a debug dump cannot read staff PINs); rainbow-table / precomputed attacks across the whole user table (per-user salt forces a fresh brute-force per row).
- **Not defended:** a determined attacker with read access to the SwiftData store. A 4-digit PIN has 10,000 possibilities — brute-forceable in milliseconds regardless of salt. **The real security boundary is the iOS app sandbox**, not the hash. The store is only readable by the app itself; an attacker who has defeated the sandbox has the whole store regardless.
- **Threat model:** the data is restaurant duty-completion records. Blast radius if leaked is low (no payment data, no PII beyond staff names). This matches restaurant POS industry conventions, where server PINs are universally soft credentials.

If the app's threat model escalates (e.g. it starts handling payment data or guest PII), the migration path is to move secrets into Keychain with longer, user-chosen passwords — and to revisit whether the shared-device model still applies.

## What changes in the existing model

- **`User`** gains `id: UUID` (stable identifier for session persistence and future history-viewer filtering — `PersistentIdentifier` is not `Codable` and cannot round-trip through `UserDefaults`), plus `pinHash: String?` and `pinSalt: String`. Methods `setPin(_:)` and `matchesPin(_:)` encapsulate the hashing; no call site touches the hashes directly.
- **`CompletionLog.completedBy`** — already in the schema, never populated — is now set at log-insertion time. Existing logs stay `nil` (the field was unused before, so no data is lost); the history viewer (Feature #5) will need to handle "unknown user" for these legacy rows.
- **`seedOnLaunch`** stops creating a default manager. It now seeds one manager (name `"Manager"`, PIN `0000`) and one staff user (name `"Staff"`, PIN `1111`) for first-run demo. These PINs are intentionally documented here; production deployments will replace them via a future staff-management screen (out of scope for this feature).
- **Finish Day** gates on `authStore.currentUser?.isManager == true`. The previous "any manager exists" check is removed.
- **`ContentView`** renders `LoginView` when `authStore.currentUser == nil`, otherwise the existing area list.

## Rejected alternatives

- **Username/password.** Overkill. Adds password-reset flows, validation, password-strength rules — none of which serve the actual goal (attribution). Friction at every sign-in would push staff toward shared logins, which is worse than no auth.
- **Personal devices.** Would require server-side accounts, multi-tenancy, and push setup per user — far out of scope, and contradicts the restaurant-industry reality that staff don't get company phones.
- **Per-restaurant `User`.** Pre-empts a multi-location decision that isn't made yet (see `ROADMAP.md` Future). Adds a `Restaurant` aggregate root the rest of the model doesn't need.
- **PIN entry on every mutation.** Friction at every tap would destroy the speed that makes the app usable during service. The "once per session + trivial Switch User" pattern matches every production POS in restaurants.
- **In-memory session only (no `UserDefaults` persistence).** Loses attribution across app backgrounding (which iOS does aggressively) — staff would be re-PINning every time they switch apps, which is several times per shift.
- **Salted Argon2 / PBKDF2 with high iteration count.** Would not meaningfully change the threat model — 4-digit space is brute-forceable regardless. Adds a CommonCrypto dependency for no security gain.

## Open questions deferred to follow-ups

- **Staff-management UI** (add/edit/remove users, change PINs) — not in this feature. Today the seed data is the only way to add users.
- **Auto sign-out on idle.** A shared device left signed in misattributes logs to whoever last signed in. Restaurants vary on whether they want this. Defer until asked for.
- **Forgotten PIN recovery.** Today: reset via direct store edit (dev) or re-seed (nuclear). A real flow needs the staff-management UI above.
