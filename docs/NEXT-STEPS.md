# Next Steps — Resume Here

Handoff for the restaurant checklists feature. This doc is self-contained: read it, plus `CONTEXT.md` and `docs/adr/0001-derived-completion-state.md`, and you have everything needed to continue.

---

## 🔖 Session handoff — 2026-07-27 (RESUME HERE)

**One-line status:** `/code-review` skill run against Feature #5 (`11235ee..0ca42f4`); 2 hard findings + 1 scope-creep + 1 minor mismatch addressed in one focused set of edits. **78/78 tests still green.** Standards + Spec axes ran in parallel as sub-agents. Work currently uncommitted on `main`.

### Exact resume action
1. **Review the diff and commit** (suggested message: `Address Feature #5 code-review findings (helper bypass + ADR/impl drift)`). Modified: `checklist-app/checklist_appApp.swift`, `docs/adr/0004-history-viewer-and-retention.md`, `docs/NEXT-STEPS.md`.
2. Optional: tag the milestone (`git tag feature-5-reviewed`).
3. Pick the next roadmap item — see candidates in the 2026-07-21 handoff below (Feature #2 forgotten finish-day is still highest-leverage).

### What was reviewed
Ran the `/code-review` skill against `11235ee..0ca42f4` (Feature #5: history viewer + retention, 4 commits, 756 insertions). Standards axis read `CONTEXT.md` + ADRs 0001–0004 + the Fowler smell baseline; Spec axis read ADR 0004 + the Feature #5 ROADMAP entry. Two sub-agents ran in parallel.

### Findings & resolution

**Addressed (this session):**
- **Standards hard / Spec wrongness — `seedOnLaunch` bypassed `LogRetention.logsToDelete`.** Production code re-implemented the strict-`<` rule inline as `#Predicate { $0.timestamp < cutoff }`; the helper ADR 0004 designates as the call-site entry point had zero production callers (test-only). Rewired `seedOnLaunch` to fetch all logs and pass them through `LogRetention.logsToDelete(in:asOf:)` — the rule now has exactly one production implementation, pinned by `LogRetentionTests`. Inline comment rewrites the engineering tradeoff (single source of truth > marginal DB-layer efficiency at this data volume).
- **Spec wrongness — ADR 0004 said `.confirmationDialog`, both impls use `.alert`.** Surfaced mid-fix: `StaffManagementView` (the cited reference) *also* uses `.alert`, so the ADR was the outlier, not the implementation. Reversed the originally-proposed fix direction (would have been a SwiftUI refactor of `HistoryView`; became a one-line doc fix). Updated ADR 0004 line 16.
- **Spec mismatch — ADR 0004 vs ROADMAP vs impl on entry point.** ADR said "gear-icon menu gains a History entry"; ROADMAP said "clock icon beside the staff gear"; impl has three separate toolbar buttons. Updated ADR 0004 line 30 to match the impl + ROADMAP wording.
- **Spec scope creep — "Other" section in `HistoryView`.** ADR 0004 said "FOH / BOH"; impl renders FOH / BOH / Other (catches logs whose `duty?.checklist?.area == nil`). Defensible — a deleted duty shouldn't make its past logs invisible — but unmentioned in the ADR. Updated ADR 0004 lines 11, 12, 31 to bless it.

**Deferred (judgement calls, all in `HistoryView` / `LogRetention`):**
- **Duplicated Code** — three near-identical `fohLogs` / `bohLogs` / `orphanedLogs` filter-and-sort shapes; one `logs(for area: Area?)` helper collapses them.
- **Message Chain / Feature Envy** — `$0.duty?.checklist?.area` is a 3-hop walk; an `Area` convenience on `CompletionLog` (or `TaskItem`) would hide it.
- **Misleading comment** — `LogRetention.swift:15-16` claims to mirror `PinHasher`'s caseless-enum pattern; `PinHasher` is actually top-level free functions. Only `StaffManagement` is a caseless enum.
- **Banned synonym in comments** — `HistoryView.swift:24, 27` uses bare "day" where CONTEXT.md's avoid-list flags it; term-of-art is "business day." UI strings are clean.

### Verification
`xcodebuild test -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 17'` → **TEST SUCCEEDED**, 78/78 cases pass (same count as pre-fix — the rewired production path now exercises the same `LogRetention.logsToDelete` code that `LogRetentionTests` already pinned).

### Debugging notes (don't re-discover)
- **Don't trust an ADR's API names verbatim.** ADR 0004 said `.confirmationDialog` for delete confirmation; both `HistoryView` and the cited `StaffManagementView` reference use `.alert`. Caught when checking the reference shape before refactoring. Always grep for the actual call site before treating an ADR's API mention as ground truth.
- **`LogRetention.logsToDelete` is the right home for the rule, even at the cost of fetching without a `#Predicate`.** Data volume is bounded (single restaurant, rolling 30-day window — at most a few thousand logs); the single-source-of-truth win outweighs the DB-layer filter cost. The helper's strict-`<` boundary at exactly 30 days is pinned by three tests (`==cutoff`, `cutoff-1s`, `cutoff+1s`) — running through the helper gives the production path that guarantee for free.

### Phase status
| Phase | Status |
|-------|--------|
| Phase 0 — pure scheduling | ✅ Done (18/18) |
| Phase 1 — SwiftData models | ✅ Done |
| Phase 2 — UI | ✅ Done |
| Tests — XCTest port | ✅ 18/18 green |
| Phase 3 — `/code-review` + fixes | ✅ Done (`4094f62`) |
| Feature #1 — Auth & current-user session | ✅ Done (ADR 0002) |
| Feature #7 — Staff management & duty permissions | ✅ Done (ADR 0003) |
| Feature #5 — Business-day history & log viewer | ✅ Done (ADR 0004) |
| **Feature #5 `/code-review` pass + fixes** | ✅ **Done** (this session) |

---

## 🔖 Session handoff — 2026-07-21 (RESUME HERE)

**One-line status:** Roadmap Feature #5 (Business-day history & log viewer) **done**. Managers can browse past business days from a new clock icon in `AreaListView`, drill into FOH / BOH / Other sections, see every `CompletionLog` captured in each, edit (`note` + `completedBy` only) via `LogEditSheet`, and delete with confirmation. Logs roll off after a rolling 30-day window (hard-deleted on app launch). **78/78 tests green** (12 new for `LogRetention` in Phase 0; the rolling total was 66 after Feature #7). ADR 0004 written — it explicitly revises one clause of ADR 0001 ("history stays intact forever in the logs"). Four commits across three phases, all pushed to `origin/main`.

### Exact resume action
1. **Optional: run `/code-review` skill** against the Feature #5 work (`5f96ff2..5430875`). Past review passes (commit `4094f62`) caught real spec/standards issues; worth doing here too. Standards axis + spec axis (ADR 0004) in parallel.
2. **Optional: tag the milestone** (`git tag history-viewer-complete`).
3. Pick the next roadmap item — likely candidates:
   - **Feature #2 (Forgotten finish-day handling)** — Small. Pure UI logic; benefits from auth (warn the manager).
   - **Feature #3 (Finish-day with incomplete closing duties)** — Small once the policy is decided.
   - **Feature #4 (Duty templates & seed data)** — Medium. Wants real-restaurant input.
   - **Duty edit/delete UI** (ADR 0003 deferred follow-up) — the permission model is locked; only the UI is missing. Now feels like a natural pair with #5 since the history viewer reveals how often managers want to clean up duties.

### What landed this session (4 commits)
- **`docs/adr/0004-history-viewer-and-retention.md`** (NEW) — locks in: business day → Area grouping, screen-only (no export), rolling 30-day hard-delete retention, manager-only edit (`note` + `completedBy`) and delete, atomic `lastEditedAt` / `lastEditedBy` stamps, `LogRetention` pure-helper namespace, no `LogEditPolicy` helper (inline `isManager` gate). Explicitly revises ADR 0001's "logs stay intact forever" clause with reasoning.
- **`checklist-app/History/LogRetention.swift`** (NEW) — caseless-enum namespace. `retentionWindow` (= 30 × 24 × 60 × 60 seconds, named so the policy is searchable from one place), `cutoffDate(asOf:)`, `logsToDelete(in:asOf:)`. Framework-free, mirrors `PinHasher` / `StaffManagement`.
- **`checklist-appTests/LogRetentionTests.swift`** (NEW) — 12 tests, AAA pattern, detached `CompletionLog` instances. Pins the strict-less-than boundary at exactly 30 days with three dedicated tests (`==cutoff`, `cutoff-1s`, `cutoff+1s`).
- **`checklist-app/Models/CompletionLog.swift`** (MODIFIED) — added `lastEditedAt: Date?` + `lastEditedBy: User?`. Doc comment rewritten (was "immutable audit record"; now accurately describes ADR 0004 mutability + retention). `init` unchanged — new logs default to never-edited (both nil).
- **`checklist-app/Models/User.swift`** (MODIFIED) — added `editedLogs: [CompletionLog]` with `@Relationship(deleteRule: .nullify, inverse: \CompletionLog.lastEditedBy)`, mirroring the existing `logs` / `completedBy` pair. `.nullify` so deleting a manager who edited logs keeps the logs but clears `lastEditedBy`.
- **`checklist-app/checklist_appApp.swift`** (MODIFIED) — `seedOnLaunch` now also hard-deletes logs older than `LogRetention.cutoffDate(asOf: .now)` via a `#Predicate` fetch + per-log delete. Uses `#Predicate` for DB-layer filtering (more efficient than fetching all + running the pure helper in-memory). Doc comment updated to describe both invariants.
- **`checklist-app/History/HistoryView.swift`** (NEW) — top-level `HistoryView` (`NavigationStack` + `List` of business days, most recent first, open day at top) + drill-down `BusinessDayDetailView` (FOH / BOH / Other sections, logs sorted newest-first within each) + `LogRow` (duty title, time, completer, note, "edited" pencil badge). Tap-to-edit + swipe-to-delete with `.alert` confirmation. "Other" section catches logs whose `duty?.checklist?.area == nil` (deleted-duty case) so they stay visible instead of silently dropping.
- **`checklist-app/History/LogEditSheet.swift`** (NEW) — manager-only form sheet. `note` (multi-line text) + `completedBy` (Picker over all users with explicit "Unattributed" `UUID?.none` tag so managers can clear attribution). Save stamps `lastEditedAt` / `lastEditedBy` together — atomic audit signal. Duty title shown read-only. Footer surfaces last-edit info when present. Defense-in-depth `onAppear` re-check mirrors `AddDutySheet`.
- **`checklist-app/ContentView.swift`** (MODIFIED) — `AreaListView` toolbar gains a `clock.arrow.circlepath` icon beside the staff gear (manager-only). New `@State showingHistory` + `.sheet` presentation. Updated the inline comment to reference both ADR 0003 and ADR 0004.

### Verification
`xcodebuild test -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 17'` → **TEST SUCCEEDED**, 78/78 cases pass, zero new warnings (only the pre-existing 9 DutyStatus Swift-6 actor-isolation notes remain, unchanged since 2026-07-18).

### How to use the new history viewer
1. **Sign in as a manager** (onboarding-created manager or any promoted user — staff don't see the icon).
2. Tap the **clock icon** (top-left, beside the staff gear) → History sheet opens with the open business day at the top showing "Open" + log count.
3. Tap a business day → drill into FOH / BOH / Other sections. Logs are sorted newest-first within each section.
4. **Tap a log** → edit sheet → change `note` (multi-line text) and/or `completedBy` (Picker, includes "Unattributed") → Save → row returns with a pencil badge indicating it's been edited. Footer inside the sheet shows last-edit info.
5. **Swipe-left on a log** → tap Delete → confirmation alert → confirm → log is permanently removed.
6. **Retention is invisible by design.** On every app launch, `seedOnLaunch` hard-deletes logs older than 30 days. No UI affordance, no setting, no tombstone.

### Debugging notes (don't re-discover)
- **`.tag(UUID?.none)` works for nil-selection in SwiftUI `Picker`.** The selection type must be declared `UUID?` on the `@State`; the tags use explicit Optional (`UUID?.none` and `Optional(user.id)`). Swift can't infer the nil case from context, so be explicit.
- **`.alert(_:isPresented:)` with a `Binding(get:set:)` for "pending item" confirmation.** Clean way to associate a destructive confirmation with an optional state (`logPendingDeletion: CompletionLog?`). `get: { logPendingDeletion != nil }`, `set: { if !$0 { logPendingDeletion = nil } }`. The alert's button handlers clear the state, which auto-dismisses.
- **`@ViewBuilder private func logRow(_:) -> some View` factors view modifiers across sections.** Used in `BusinessDayDetailView` so the `.contentShape`, `.onTapGesture`, and `.swipeActions` stay identical for FOH / BOH / Other rows. Without this, three near-duplicate ForEach bodies drift.
- **`BusinessDay.logs` relationship is lazy-loaded by SwiftData.** Accessing `day.logs` in `BusinessDayDetailView` faults in the logs automatically — no fetch needed, no `@Query` required at the detail level. The top-level `@Query(sort: \BusinessDay.openedAt, order: .reverse)` in `HistoryView` handles fetching days.
- **Schema migration was lightweight.** Adding optional fields (`lastEditedAt: Date?`, `lastEditedBy: User?`) + a new optional relationship (`User.editedLogs`) is automatic for SwiftData. In-memory test stores are immune. If a stale dev-store errors on schema change, delete the app from the simulator (same as every prior model change).
- **Strict less-than at the retention boundary.** A log whose `timestamp` exactly equals the cutoff is NOT eligible for deletion — pinned by three tests in `LogRetentionTests` (`==cutoff` not deleted, `cutoff-1s` deleted, `cutoff+1s` not deleted). The ADR says "older than 30 × 24 hours"; the tests make it enforced.
- **`log.duty?.checklist?.area == nil` is the "orphaned" check.** Catches both `duty == nil` AND `checklist == nil` cases — any log where Area can't be derived. `Area` is non-optional on `Checklist`, so this never matches a "legitimate nil area" (there's no such thing).

### Open design decisions still flagged (not blocking)
- **No `/code-review` run yet** on Feature #5. Worth doing before declaring the feature fully closed — past review passes caught real issues (commit `4094f62`).
- **Auto sign-out on idle** (ADR 0002 follow-up, unchanged): a shared device left signed in misattributes logs. Restaurants vary on whether they want this. Defer until asked for.
- **Forgotten finish-day** (unchanged): if nobody hits Finish Day, next morning's logs attach to yesterday's open business day. Now *additionally* relevant to history viewing — yesterday looks over-counted, today looks empty.
- **Finish-day with incomplete closing duties** (unchanged): still allowed silently. Product decision still pending.
- **Duty edit/delete UI** (ADR 0003 follow-up, unchanged): the permission model is locked, the UI doesn't exist. Now more visible since history shows deleted-duty logs as "(deleted duty)" — managers may want a cleaner way to retire a duty.
- **Deletion audit trail** (ADR 0004 deferred): today, deleting a `CompletionLog` is silent — no record of who deleted what when. A `LogMutationAudit` aggregate would be the shape if this surfaces as a need.
- **Search / filter within history view** (ADR 0004 deferred): chronological scroll is fine for one month of logs. Revisit if volume makes scroll painful.
- **Bulk log actions** (ADR 0004 deferred): per-row swipe covers today's volume.
- **Pre-existing Swift 6 actor-isolation warnings** in `DutyStatusTests.swift` (9 warnings). Unchanged; address in a separate Swift 6 migration pass if desired.

### Phase status
| Phase | Status |
|-------|--------|
| Phase 0 — pure scheduling | ✅ Done (18/18) |
| Phase 1 — SwiftData models | ✅ Done |
| Phase 2 — UI | ✅ Done |
| Tests — XCTest port | ✅ 18/18 green |
| Phase 3 — `/code-review` + fixes | ✅ Done (`4094f62`) |
| Feature #1 — Auth & current-user session | ✅ Done (ADR 0002) |
| Feature #7 — Staff management & duty permissions | ✅ Done (ADR 0003) |
| **Feature #5 — Business-day history & log viewer** | ✅ **Done** (ADR 0004) |

---

## 🔖 Session handoff — 2026-07-20 late (RESUME HERE)

**One-line status:** Roadmap Feature #7 (Staff management & duty permissions) **done**. First-launch onboarding wizard replaces seeded demo users; managers can add/rename/promote/demote/reset-PIN/delete users via a new Staff screen; `+` duty button is hidden for staff. Forgotten-PIN recovery (ADR 0002 follow-up) closed as a side effect. **66/66 tests green** (18 DutyStatus + 13 PinHasher + 13 AuthStore + 22 StaffManagement). ADR 0003 written. Work uncommitted on `main`.

### Exact resume action
1. **Review the diff and commit** (suggested message: `feat(staff): manager-only staff management + duty permissions (Feature #7, ADR 0003)`). Untracked: `Onboarding/OnboardingView.swift`, `StaffManagement/StaffManagement.swift`, `StaffManagement/StaffManagementView.swift`, `docs/adr/0003-*.md`, `checklist-appTests/StaffManagementTests.swift`. Modified: `ContentView.swift`, `checklist_appApp.swift`, `docs/ROADMAP.md`, `docs/NEXT-STEPS.md`.
2. **Run the app** to sanity-check the onboarding flow (delete from simulator first to trigger first-launch): name → PIN → confirm → land signed-in as manager → tap gear icon → add a staff user → switch user → verify `+` button is hidden for staff.
3. Optional: run `/code-review` skill against the new code.
4. Pick next roadmap item — **Feature #5 (history & log viewer)** remains the highest-leverage next step (every new log now carries attribution; UI doesn't exist yet).

### What landed this session
- **`docs/adr/0003-staff-management-and-duty-permissions.md`** (NEW) — locks in: onboarding wizard (no seed), manager-only duty editing, `StaffManagement` pure-helper namespace, self-protection + last-manager protection, hide-don't-disable policy, forgotten-PIN recovery in scope.
- **`checklist-app/StaffManagement/StaffManagement.swift`** (NEW) — pure, framework-free permission helpers (`canCreateUser`, `canEdit`, `canPromote`, `canDemote`, `canDelete`). Caseless-enum namespace, mirrors `PinHasher` pattern. The UI is a thin shell over these.
- **`checklist-app/StaffManagement/StaffManagementView.swift`** (NEW) — `NavigationStack` + `List` of users with add/edit/delete/reset-PIN sheets. All mutations re-validate via `StaffManagement.*` before touching the store. Inline explanations when an action is blocked (e.g. "Can't demote the only remaining manager").
- **`checklist-app/Onboarding/OnboardingView.swift`** (NEW) — first-launch wizard (name → PIN → confirm). Single `Form` with inline validation. Auto-signs-in on completion; never shows again (detection is store-derived via `@Query` count of users in `ContentView`).
- **`checklist-app/ContentView.swift`** (MODIFIED) — root now a 3-way switch (`OnboardingView` / `LoginView` / `AreaListView`); gear icon added to `AreaListView` toolbar beside `SwitchUserButton` (manager-only); `DutyListView`'s `+` button wrapped in `if currentUser?.isManager == true`; `AddDutySheet` gained defense-in-depth `onAppear` re-check.
- **`checklist-app/checklist_appApp.swift`** (MODIFIED) — `seedOnLaunch` no longer creates demo users (Manager/0000 + Staff/1111 removed). It still seeds the open `BusinessDay` if none exists — that's required for the first completion log to be visible.
- **`checklist-appTests/StaffManagementTests.swift`** (NEW) — 22 tests covering all five helpers: who-can-create, who-can-edit (rename/PIN reset), promote/demote rules, delete rules, self-protection, last-manager protection, and defense-against-partial-`allUsers`-list. Pure tests, no SwiftData container (uses detached `User` instances).
- **`docs/ROADMAP.md`** (MODIFIED) — added Feature #7 section marked DONE; struck through the two ADR 0002 follow-ups this feature closes (staff-management UI, forgotten-PIN recovery).
- **`docs/NEXT-STEPS.md`** (MODIFIED) — this entry.

### Verification
`xcodebuild test -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 17'` → **TEST SUCCEEDED**, 66/66 cases pass, zero new warnings (only the pre-existing 9 DutyStatus Swift-6 actor-isolation notes remain).

### How to use the new staff management
1. **Delete the app from the simulator** (or wipe via `xcrun simctl uninstall`) to trigger first-launch onboarding.
2. Launch → onboarding screen: enter your name, set a 4-digit PIN, confirm → land signed-in as the first manager.
3. Tap the **gear icon** (top-left, beside your name) → Staff screen opens.
4. Tap **+ Add User** → name + role (staff/manager) + 4-digit PIN → user appears in the directory.
5. Tap any user row → edit name, change role, reset PIN, or delete (blocked if it would orphan managers).
6. Switch User → tap a staff user → verify the `+` button is hidden on `DutyListView`.

### Debugging notes (don't re-discover)
- **`User(name:role:)` works without a ModelContext.** `@Model` classes can be instantiated detached; tests that only read `id`/`role`/`isManager` (like `StaffManagementTests`) don't need the in-memory-container dance that `AuthStoreTests` does.
- **Caseless enum as a namespace** is the right Swift pattern for pure-helper files (`enum StaffManagement {}` with no cases). Can't be accidentally instantiated; static methods read as `StaffManagement.canDelete(...)`. Mirrors stdlib usage (e.g. `Mirror`).
- **First-launch detection via `@Query` count, not a UserDefaults flag.** A defaults wipe with users still in the store would otherwise strand the app on onboarding; a store-derived check is self-correcting.
- **Defense-in-depth in `AddDutySheet.onAppear`** — the `+` button is hidden for staff, but the sheet re-validates on appear and dismisses if the current user isn't a manager. Costs 4 lines, future-proofs against any path that surfaces the sheet without going through the button.
- **`@State` initialized from a `let user: User` in `EditUserSheet.init`** — SwiftUI requires the `_name = State(initialValue: user.name)` pattern because `@State` is created once at view instantiation, not on each render. Direct assignment inside `init` is the documented workaround.

### Open design decisions still flagged (not blocking)
- **Auto sign-out on idle** (ADR 0002 follow-up, unchanged): a shared device left signed in misattributes logs. Restaurants vary on whether they want this. Defer until asked for.
- **Forgotten finish-day** (unchanged): if nobody hits Finish Day, next morning's logs attach to yesterday's open business day. Now *also* could target the warning to "the manager" specifically via auth.
- **Finish-day with incomplete closing duties** (unchanged): still allowed silently. Product decision still pending.
- **Duty edit/delete UI** (ADR 0003 follow-up): the *permission* model is locked (manager-only), but there's no UI yet for editing or deleting existing duties. Forward-compatible — the gating is already in place.
- **Bulk staff import / management-action audit trail / PIN rotation** — all explicitly deferred in ADR 0003.
- **Pre-existing Swift 6 actor-isolation warnings** in `DutyStatusTests.swift` (9 warnings). Unchanged; address in a separate Swift 6 migration pass if desired.

### Phase status
| Phase | Status |
|-------|--------|
| Phase 0 — pure scheduling | ✅ Done (18/18) |
| Phase 1 — SwiftData models | ✅ Done |
| Phase 2 — UI | ✅ Done |
| Tests — XCTest port | ✅ 18/18 green |
| Phase 3 — `/code-review` + fixes | ✅ Done (`4094f62`) |
| Feature #1 — Auth & current-user session | ✅ Done (44/44 green, ADR 0002) |
| **Feature #7 — Staff management & duty permissions** | ✅ **Done** (66/66 green, ADR 0003) |

---

## 🔖 Session handoff — 2026-07-20 evening

**One-line status:** Roadmap Feature #1 (Auth & current-user session) **done**. PIN-based login is live, `CompletionLog.completedBy` is populated on every new log, Finish Day gates on the signed-in manager. **44/44 tests green** (18 DutyStatus + 13 PinHasher + 13 AuthStore). ADR 0002 written. Next: pick another roadmap item — Feature #5 (history & log viewer) is now fully unblocked because every new log carries attribution.

### Exact resume action
1. Pick the next feature from `docs/ROADMAP.md`. Suggested natural next steps:
   - **Feature #5 — Business-day history & log viewer:** the audit trail is now rich (every new log has `completedBy`), but there's no UI to read it. This is the pay-off feature for both ADR #1 and ADR #0002.
   - **Feature #2 — Forgotten finish-day handling:** still relevant; benefits from auth (warn *the manager* specifically).
   - **Staff-management UI** (ADR 0002 deferred follow-up): today the only way to add/edit/remove users or change PINs is via direct store edit. A first cut would be a manager-only settings screen.
2. Optional: tag the milestone (`git tag auth-session-complete`).
3. Optional housekeeping: address the 9 pre-existing Swift 6 actor-isolation warnings in `DutyStatusTests.swift` if you want a fully clean Swift 6 build.

### What landed this session
- **`docs/adr/0002-auth-and-current-user-session.md`** (NEW) — captures every decision: 4-digit PIN, shared device, one-PIN-per-session, single-restaurant, `AuthStore` in `.environment`, PIN persisted as SHA-256 + per-user salt with honest threat model (casual observation defense; iOS sandbox is the real boundary).
- **`checklist-app/Auth/PinHasher.swift`** (NEW) — pure, framework-free PIN helpers (`isValidPin`, `generateSalt`, `hashPin`) + `PinError.invalidFormat`. Mirrors the `DutyStatus.swift` pattern.
- **`checklist-app/Auth/AuthStore.swift`** (NEW) — `@Observable` session. Holds `currentUserID: UUID?`; persists via `UserDefaults`; `signIn(user:pin:)` / `signOut()` / `currentUser(in:)`. The PIN itself is never persisted.
- **`checklist-app/Models/User.swift`** (MODIFIED) — added `id: UUID` (stable for session persistence — `PersistentIdentifier` isn't `Codable`), `pinSalt: Data`, `pinHash: String?`, `setPin(_:)`, `matchesPin(_:)`, `hasPin`. Existing `init(name:role:createdAt:)` signature preserved (new params have defaults).
- **`checklist-app/ContentView.swift`** (MODIFIED) — split into `ContentView` (login gate: shows `LoginView` when no current user, else `AreaListView`) + `AreaListView` (was `ContentView`). Finish Day gates on `authStore.currentUser?.isManager`. New `SwitchUserButton` in leading toolbar. `toggle()` now sets `log.completedBy = currentUser` on every new log.
- **`checklist-app/LoginView.swift`** (NEW) — pick-name → enter-PIN flow. Auto-submits on the 4th digit (no Sign In button to hunt for with wet hands). Wrong-PIN shake-style retry inline.
- **`checklist-app/checklist_appApp.swift`** (MODIFIED) — dropped default-manager seed; replaced with first-run seed of `Manager` (PIN `0000`) + `Staff` (PIN `1111`) per ADR 0002. Wired `AuthStore` into `.environment`.
- **`checklist-appTests/PinHasherTests.swift`** (NEW) — 13 tests: validation rules, hash determinism, salt uniqueness, output shape.
- **`checklist-appTests/AuthStoreTests.swift`** (NEW) — 13 tests: sign-in success/failure, sign-out, session persistence across `AuthStore` instances (simulated relaunch via shared `UserDefaults`), deleted-user-logs-out, user model PIN coverage. `@MainActor` (needed for `ModelContainer.mainContext` in Swift 6 mode).

### Verification
`xcodebuild test -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 17'` → **TEST SUCCEEDED**, 44/44 cases pass, zero new warnings (only the pre-existing 9 DutyStatus Swift-6 actor-isolation notes remain).

### How to use the new auth
1. Launch the app → LoginView appears (no session yet).
2. Tap **Manager** → enter `0000` → area list appears. Toolbar shows Finish Day (manager) + Switch User (signed-in-as).
3. Tap **Switch User** → back to LoginView (session cleared).
4. Tap **Staff** → enter `1111` → area list appears. Finish Day button hidden (not manager).
5. Tap any duty → a `CompletionLog` is inserted with `completedBy` set to the current user. (Previously: `completedBy` stayed nil — half the audit value of ADR #1 was lost.)

### Debugging notes (don't re-discover)
- **`ModelContainer.mainContext` is `@MainActor`-isolated** in Swift 6 mode (and in Swift 5 with the `GlobalActorIsolatedTypesUsability` upcoming-feature flag, which this project has enabled). Test classes touching it must be `@MainActor` — see `AuthStoreTests.swift`. The pre-existing `DutyStatusTests.swift` does not touch the context, which is why it works without the annotation (and produces only warnings for the unrelated `DutyStatus: Equatable` main-actor-isolated conformance).
- **SwiftData `#Predicate` on `UUID` equality works natively** — `$0.id == id` compiles and runs fine. The predicate gotchas in this project are with enums (worked around via `roleRawValue` / `weekdayRawValue`); UUID is a value attribute, no workaround needed.
- **`SecureField` + `.numberPad` + `.textContentType(.oneTimeCode)`** is the right combo for a PIN entry on iOS — `oneTimeCode` triggers iOS to auto-fill from SMS where applicable (not used here, but it suppresses the strong-password autofill suggestion which would be wrong for a 4-digit PIN).
- **`@State private var authStore = AuthStore()`** in `checklist_appApp` is the SwiftUI-idiomatic owner of an `@Observable` environment object. Don't use `@StateObject` (that's for `ObservableObject`).

### Open design decisions still flagged (not blocking)
- **Staff-management UI** (ADR 0002 follow-up): only way to add/edit/remove users or change PINs is via direct store edit. A first cut manager-only settings screen would unblock production deployment.
- **Auto sign-out on idle** (ADR 0002 follow-up): a shared device left signed in misattributes logs. Restaurants vary on whether they want this. Defer until asked.
- **Forgotten finish-day:** unchanged from prior handoff — if nobody hits Finish Day, next morning's logs attach to yesterday's open business day. Now *also* could target the warning to "the manager" specifically via auth.
- **Finish-day with incomplete closing duties:** still allowed silently. Product decision still pending.
- **Pre-existing Swift 6 actor-isolation warnings** in `DutyStatusTests.swift` (9 warnings). Unchanged from prior handoff; address in a separate Swift 6 migration pass if desired.

### Phase status
| Phase | Status |
|-------|--------|
| Phase 0 — pure scheduling | ✅ Done (18/18) |
| Phase 1 — SwiftData models | ✅ Done |
| Phase 2 — UI | ✅ Done |
| Tests — XCTest port | ✅ 18/18 green |
| Phase 3 — `/code-review` + fixes | ✅ Done (`4094f62`) |
| **Feature #1 — Auth & current-user session** | ✅ **Done** (44/44 green, ADR 0002 written) |

---

## 🔖 Session handoff — 2026-07-20 (morning)

**One-line status:** Phase 3 complete — `/code-review` skill executed, all hard findings addressed, 18/18 tests green. Committed (`4094f62`) and pushed. Next: pick an open design decision below, or start the next feature (auth/session is the natural next step — it unblocks real finish-day gating).

### Exact resume action
1. Pick one of the open design decisions below (none blocking) — OR — start the next feature. **Auth/session is highest-leverage** because it unblocks real finish-day gating and unlocks `CompletionLog.completedBy` (currently never populated).
2. Optional housekeeping: address the 9 pre-existing Swift 6 actor-isolation warnings in `DutyStatusTests.swift` (see debugging notes below) if you want a clean Swift 6 build.
3. Optional: tag the milestone (`git tag phase-3-complete`).

### What landed this session (commit `4094f62`)
- Ran `/code-review` skill against `main` since `411a7e6` (Phase 1 + Phase 2 + Tests). Standards + Spec axes ran in parallel as sub-agents.
- 11 findings: 2 spec correctness bugs, 7 standards hard violations, 5 baseline smells. All hard findings addressed; 3 deferred with reasoning.

**Spec fixes:**
- **nil-businessDay silent data loss:** `toggle` now `guard let`s the current business day before inserting a `CompletionLog`. Previously, if `finishDay` had just run (or `seedOnLaunch` hadn't fired), a log could be inserted with `businessDay == nil` — silently invisible forever, since the derivation filters out nil-attributed logs. User would tap, row wouldn't flip, no error.
- **`shouldSurface` wired into the UI:** `DutyListView.duties` now filters through `shouldSurface(status(of:))`. Weekly duties whose weekday hasn't arrived are hidden — also preventing early taps. 5 XCTest cases had pinned this rule but the UI ignored them.

**Standards fixes:**
- ADR #1 derivation extracted from a private SwiftUI View onto `TaskItem.isDone(in:)` / `isDoneThisWeek(asOf:calendar:)` so XCTest can cover it (was unreachable from the test target).
- `CompletionLog.task` → `.duty` (CONTEXT.md avoid word); both sides of the SwiftData inverse updated.
- `Phase` doc comment no longer uses banned word `stage` as a descriptor.
- `DutyRow` 4 parallel `switch status` statements collapsed into one `DutyStatusStyle` table.
- `(cadence, phase)` slot-name switch deduped into a shared `slotName` helper.
- `AreaView.title/subtitle` statics → `Area.displayName/.subtitle`; `DutyRow.weekdayLabel` → `Weekday.displayName` (Feature Envy).
- Test helper `day(_:_:_:)` → `date(y:m:d:)` (Mysterious Name + CONTEXT.md avoid word).

**Deferred (with reasoning, see commit message for detail):**
- "Front of House" / "Back of House" subtitles kept — canonical CONTEXT.md forms (the *Avoid* lists target colloquial synonyms like *the front*, not the glossary expansion itself).
- `currentBusinessDay` `@Query` duplication — SwiftUI per-View idiom; would need a custom property wrapper for marginal gain.
- Data-clumps / divergent-change smells — bigger refactor, out of review scope.

### Debugging notes (don't re-discover)
- **Pre-existing Swift 6 actor-isolation warnings** in `DutyStatusTests.swift` (9 warnings on `XCTAssertEqual` calls). These predate this session — they were already present after the 2026-07-18 evening commit. Swift 5 mode treats them as warnings, not errors; tests pass. Likely fix when ready: mark `DutyStatus`-equality tests nonisolated or annotate the test class. Address in a separate Swift 6 migration pass if/when desired.
- **`xcodebuild test` is parallel-safe now:** the run uses "Clone N of iPhone 17" — tests execute in ~21s wall-clock for the full suite.

### Open design decisions still flagged (not blocking)
- **Finish-Day gating is loose:** the button shows if *any* manager `User` exists (a default manager is seeded on launch). Real gating needs a "current user"/auth session. `// TODO` markers in `checklist_appApp.swift` and `ContentView.swift`. **Highest-leverage next step.**
- **Forgotten finish-day:** if nobody hits "Finish day", next morning's logs attach to yesterday's still-open business day. Options: warn on launch if the open business day is >24h old; auto-prompt manager.
- **Finish-day with incomplete closing duties:** allowed (just closes) or blocked until all closing duties done? Decide.
- **`CompletionLog.completedBy` is never populated** in the UI. Not a spec breach, but the audit-trail field exists and stays empty — half the audit value of ADR #1 is lost. Lands naturally with auth (you have a `User` to attribute).

### Phase status
| Phase | Status |
|-------|--------|
| Phase 0 — pure scheduling | ✅ Done (18/18) |
| Phase 1 — SwiftData models | ✅ Done |
| Phase 2 — UI | ✅ Done |
| Tests — XCTest port | ✅ 18/18 green |
| Phase 3 — `/code-review` + fixes | ✅ **Done** (`4094f62`) |

---

## 🔖 Session handoff — 2026-07-18 evening

**One-line status:** Phase 1, Phase 2, and the XCTest port are all **green and committed** on `main` (pushed). 18/18 tests pass. Next: Phase 3 (`/code-review` skill against `CONTEXT.md` + ADR #1).

### Exact resume action
1. Run the **`/code-review`** skill against the work on `main` since the Phase 0 commit (`8854020` or `411a7e6`). Focus: standards + spec compliance on Phase 1 (models), Phase 2 (UI), and the test port.
2. Address any review findings (likely small — work has been TDD'd against Phase 0 tests).
3. Land findings as one or more follow-up commits.
4. Optionally tackle one of the open design decisions below (none are blocking).
5. Consider tagging a milestone (`git tag phase-3-complete` or similar) once review is clean.

### What landed this session (commit pending as this doc is written)
- **XCTest target created** (GUI step, user did the `File → New → Target → Unit Testing Bundle` once in Xcode). Target name `checklist-appTests`, bundle ID `acedev.checklist-appTests`, `TestTargetID` = `checklist-app`. Synced folders auto-include any `.swift` under `checklist-appTests/`.
- **`checklist-appTests/DutyStatusTests.swift`** (NEW) — 18 `XCTestCase` methods porting every assertion from `.tmp/tdd/Tests.swift`, grouped by slice with `// MARK:` comments, AAA pattern, one assertion per test, shared UTC-calendar fixture.
- **`checklist-appTests/checklist_appTests.swift`** (DELETED) — Xcode-generated stub.
- **Root-cause fix for SwiftUI Previews + XCTest host crashes:** the `.rawValue == "manager"` predicate from the prior session compiled but failed SwiftData's **runtime predicate validator** (`SwiftData/Schema.swift:346: Fatal error: Failed to validate \User.role.rawValue because rawValue is not a member of UserRole`). Applied the team's established `weekdayRawValue` pattern: `User` now stores `roleRawValue: String` and exposes computed `role: UserRole` that bridges via `UserRole(rawValue:) ?? .staff`. All call sites (`user.role`, `User(role: .manager)`, `user.isManager`) unchanged. Predicates now use `$0.roleRawValue == "manager"`.
- **In-memory store under tooling:** `sharedModelContainer` switches to `isStoredInMemoryOnly: true` when `XCODE_RUNNING_FOR_PREVIEWS == "1"` or `XCTestConfigurationFilePath` is set. Normal launches use the on-disk store unchanged. Gives tests a fresh isolated store each run.
- Verification: `xcodebuild test -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 17'` → **TEST SUCCEEDED**, 18/18 cases pass.

### Debugging notes (don't re-discover)
- **SwiftData `#Predicate` cannot match a `Codable` enum case directly** (`$0.role == .manager` → compile error). And **`.rawValue` on a Codable-enum stored property also fails** — but only at runtime, in SwiftData's predicate validator (`Schema.swift:346`). Both fail. The team's established pattern: store `XRawValue` as a primitive, expose computed `X` that bridges. Applied for `Weekday` (in `TaskItem`) and now for `UserRole` (in `User`).
- **Capturing the simulator's actual assertion message:** `simctl launch --console-pty <UDID> <bundleID>` streams stderr directly — much faster than parsing `.ips` crash logs (which show symbols but not the assertion string) or `simctl log stream` (which doesn't capture fputs/stderr from SwiftUI apps reliably). Use this first when a SwiftData/SwiftUI app traps on launch.
- **Xcode "quit unexpectedly" during `New → Target`** was actually the **SwiftUI Previews host** dying (it runs the app binary under the app's name), not Xcode itself. Crash logs land in `~/Library/Logs/DiagnosticReports/<app-name>-*.ips`, not `Xcode-*.ips`. The target creation itself **succeeded** in that session — `xcodebuild -list` confirmed `checklist-appTests` was registered.
- **The test host crashes before XCTest can connect**, so failures look like `Test crashed with signal trap before establishing connection` rather than a normal test failure. The root cause is in `App.main()` of the **host app**, not the tests.

### Open design decisions still flagged (not blocking)
- **Finish-Day gating is loose:** the button shows if *any* manager `User` exists (a default manager is seeded on launch). Real gating needs a "current user"/auth session. `// TODO` markers in `checklist_appApp.swift` and `ContentView.swift`. Revisit when auth lands.
- **Forgotten finish-day:** if nobody hits "Finish day", next morning's logs attach to yesterday's still-open business day. Options: warn on launch if the open business day is >24h old; auto-prompt manager.
- **Finish-day with incomplete closing duties:** allowed (just closes) or blocked until all closing duties done? Decide.

### Phase status
| Phase | Status |
|-------|--------|
| Phase 0 — pure scheduling | ✅ Done (18/18) |
| Phase 1 — SwiftData models | ✅ Compiles + runs |
| Phase 2 — UI | ✅ Compiles + runs |
| Tests — XCTest port | ✅ **18/18 green** |
| Phase 3 — `/code-review` + final pass | ⏳ **Next** |

---

## 🔖 Session handoff — 2026-07-18 (morning)

**One-line status:** Phase 1 + Phase 2 **compile green** (`xcodebuild build ... iPhone 17` → **BUILD SUCCEEDED**) and are committed on `main`. Next: port the 18 Phase 0 tests into a new XCTest target.

### Exact resume action
1. **User (GUI-only):** in Xcode, `File → New → Target → iOS → Unit Testing Bundle`, name it **`checklist-appTests`**. Synced folders auto-include the .swift files agent writes.
2. Port the 18 tests from `.tmp/tdd/Tests.swift` into `XCTestCase` methods under `checklist-appTests/`.
3. `xcodebuild test -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 17'` → all green.
4. Run `/code-review` skill against `CONTEXT.md` + `docs/adr/0001-derived-completion-state.md`.
5. Commit tests.

### What landed this session (commit after this edit)
- Applied the predicate-safe fix in `checklist_appApp.swift` and `ContentView.swift`: `$0.role == UserRole.manager` → `$0.role.rawValue == "manager"` (SwiftData `#Predicate` cannot compare an enum-case keypath; compare the `String` rawValue instead).
- Xcode 26.6 toolchain gate cleared (`xcodebuild` + simulators now available — was previously blocked on `xcode-select` pointing at CLT-only).

### Open design decisions still flagged (not blocking)
- **Finish-Day gating is loose:** the button shows if *any* manager `User` exists (a default manager is seeded on launch). Real gating needs a "current user"/auth session. `// TODO` markers in `checklist_appApp.swift` and `ContentView.swift`. Revisit when auth lands.
- **Forgotten finish-day:** if nobody hits "Finish day", next morning's logs attach to yesterday's still-open business day. Options: warn on launch if the open business day is >24h old; auto-prompt manager.
- **Finish-day with incomplete closing duties:** allowed (just closes) or blocked until all closing duties done? Decide.

### Phase status
| Phase | Status |
|-------|--------|
| Phase 0 — pure scheduling | ✅ Done (18/18) |
| Phase 1 — SwiftData models | ✅ Compiles green |
| Phase 2 — UI | ✅ Compiles green |
| Tests — XCTest port | ⏳ **Next** — user creates target, agent ports 18 tests |
| Phase 3 — `/code-review` + final commit | ⏳ Last |

---

## 🔖 Session handoff — 2026-07-16

**One-line status:** Phase 1 (models) + Phase 2 (UI) are **written but not yet compiling**. Exactly one known error remained. Work was **uncommitted on `main`** until the build went green (done in the 2026-07-18 session above).

### Exact resume action (~3 minutes)
1. Apply this one fix in **two** files — `checklist_appApp.swift` (the `seedOnLaunch` `FetchDescriptor<User>`) and `ContentView.swift` (the `@Query` for managers):
   ```swift
   // FROM  (errors: "key path cannot refer to enum case 'manager'")
   #Predicate { $0.role == UserRole.manager }
   // TO    (compare the String rawValue — predicate-safe)
   #Predicate { $0.role.rawValue == "manager" }
   ```
   Why: SwiftData `#Predicate` cannot compare a `Codable` enum property to an enum case via keypath. Compare the `String` rawValue instead.
2. Rebuild:
   ```sh
   xcodebuild build -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
   ```
3. Address any further errors that surface (the two gotchas below are already resolved).

### Already-fixed SwiftData gotchas (don't re-discover)
- **`var weekday: Weekday?` was treated as a relationship, not a value attribute** → fixed by storing `weekdayRawValue: Int?` and exposing `weekday: Weekday?` as a computed property. All call sites (`duty.weekday`) unchanged.
- **Bare `.manager` in `#Predicate` errored ("member access without an explicit base")** → changed to `UserRole.manager`, which then surfaced the *next* error (the keypath/enum-case one), which is the remaining fix above (→ `.rawValue == "manager"`).

### Files changed this session (all uncommitted on `main`)
- `Models/Enums.swift` — dropped `ChecklistType`; added `Area`, `Cadence`, `Phase` (`String, Codable, CaseIterable`)
- `Models/Checklist.swift` — `area`/`cadence`/`phase?` replace `type`
- `Models/TaskItem.swift` — removed `isCompleted` + `completedAt` (ADR #1); added `weekdayRawValue` + computed `weekday`
- `Models/CompletionLog.swift` — added `businessDay: BusinessDay?`
- `Models/BusinessDay.swift` — **NEW**: `openedAt`, `closedAt?`, `logs`, `isOpen`
- `Scheduling/DutyStatus.swift` — added `CaseIterable` to `Weekday` (for the UI picker)
- `checklist_appApp.swift` — `BusinessDay.self` in `Schema`; seeds an open `BusinessDay` + a default `User(.manager)` on launch
- `ContentView.swift` — full Phase 2 rewrite: 3-level nav (FOH/BOH → Opening/Closing/Weekly → duties), derived status via the `DutyStatus` seam, tap-to-log, undo, Add-Duty sheet, manager Finish-Day button

### After the build is green
1. **Tests — Option A (agreed):** write XCTest model tests into `checklist-appTests/`; the **user** creates the test target once in Xcode (`File → New → Target → iOS → Unit Testing Bundle`, name `checklist-appTests`). Synced folders auto-join the `.swift` files.
2. `xcodebuild test -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 17'` → all green.
3. Commit Phase 1 + Phase 2 together.

### Open design decision flagged
- **Finish-Day gating is loose:** the button shows if *any* manager `User` exists (a default manager is seeded on launch). Real gating needs a "current user"/auth session, which doesn't exist yet. Marked with `// TODO` in `checklist_appApp.swift` and `ContentView.swift`. Revisit when auth lands.

### Phase status
| Phase | Status |
|-------|--------|
| Phase 0 — pure scheduling | ✅ Done (18/18) |
| Phase 1 — SwiftData models | 🟡 Written; 1 compile error from green (fix above) |
| Phase 2 — UI | 🟡 Written; compiles together with Phase 1 |
| Tests — XCTest port | ⏳ After green build (Option A) |
| Phase 3 — review + commit | ⏳ Last |

---

## Where we are

| Phase | Status |
|-------|--------|
| **Grilling / domain model** | ✅ Done — captured in `CONTEXT.md` (7 terms) + `docs/adr/0001-derived-completion-state.md` |
| **Phase 0 — pure scheduling logic** | ✅ Done — 18/18 tests green |
| **Phase 1 — SwiftData models** | ⛔ Blocked on toolchain (see below) |
| **Phase 2 — UI** | ⏳ After Phase 1 |
| **Phase 3 — code review + commit** | ⏳ Last |

All work is **uncommitted** on `main`. Decide whether to checkpoint-commit Phase 0 before continuing.

---

## ⛔ Unblock first — the toolchain gate

`xcode-select` points at Command Line Tools, so `xcodebuild` and simulators are unavailable. Phase 1 requires a live typecheck loop. Run:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify:
```sh
xcodebuild -version                                    # prints a version
xcrun simctl list devices available | grep -c iPhone   # nonzero
```

---

## What Phase 0 delivered (already done, verified)

`checklist-app/Scheduling/DutyStatus.swift` — pure, framework-free (no SwiftData/SwiftUI), auto-joins the target via Xcode 16 synced folders. Public seam:

- `Weekday` — Monday-first, `Comparable` (Int rawValue so SwiftData can store it)
- `DutyStatus` — `.pending | .done | .notYetDue | .due | .overdue`
- `weekday(of:calendar:)` — Monday-first weekday from a `Date`
- `weeklyDutyStatus(scheduled:now:completedThisWeek:calendar:)` — weekly boundary logic
- `dailyDutyStatus(completedInCurrentBusinessDay:)` — daily done/pending
- `shouldSurface(_:)` — hide only `.notYetDue`
- `mondayStartWeekInterval(containing:calendar:)` + `sameWeek(_:_:calendar:)` — week boundary for "done this week"

**Run the Phase 0 tests now** (no Xcode needed — uses `swiftc`):
```sh
swiftc checklist-app/Scheduling/DutyStatus.swift .tmp/tdd/Tests.swift -o /tmp/dutytest && /tmp/dutytest
```
Expect: `ALL PASSED` (18 checks).

Key behaviour pinned by tests: a weekly duty done **early** (before its weekday) correctly shows `.done` (completion outranks day-position).

---

## Phase 1 — SwiftData models  (requires toolchain unblocked)

> ⚠️ The model changes below break the **current `ContentView.swift`** (it reads `checklist.type` and `task.isCompleted`, both being removed). Either stub-update `ContentView` to compile at the end of Phase 1, or do Phase 1 + Phase 2 together. Recommended: do them together to avoid a broken intermediate commit.

**1. `checklist-app/Models/Enums.swift`**
- Delete `ChecklistType`.
- Add: `enum Area: String, Codable, CaseIterable { case foh, boh }`
- Add: `enum Cadence: String, Codable, CaseIterable { case daily, weekly }`
- Add: `enum Phase: String, Codable, CaseIterable { case opening, closing }`
- `Weekday` already exists in `DutyStatus.swift` — reuse it. Keep Int rawValue (SwiftData stores it; logic needs `Comparable`).

**2. `checklist-app/Models/Checklist.swift`**
- Replace `var type: ChecklistType` with three properties: `var area: Area`, `var cadence: Cadence`, `var phase: Phase?` (nil for weekly).
- Update `init`.

**3. `checklist-app/Models/TaskItem.swift`**
- **Delete** `var isCompleted: Bool` and `var completedAt: Date?` (see ADR #1 — state is now derived).
- **Add** `var weekday: Weekday?` (set only on weekly duties).
- Update `init` (drop the removed params).

**4. New `checklist-app/Models/BusinessDay.swift`**
```swift
@Model
final class BusinessDay {
    var openedAt: Date
    var closedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \CompletionLog.businessDay)
    var logs: [CompletionLog] = []
    var isOpen: Bool { closedAt == nil }
    init(openedAt: Date = .now) { self.openedAt = openedAt; self.closedAt = nil }
}
```

**5. `checklist-app/Models/CompletionLog.swift`**
- Add `var businessDay: BusinessDay?` (to-one inverse). Keep `timestamp`, `note`, `task`, `completedBy`.

**6. `checklist-app/checklist_appApp.swift`**
- Add `BusinessDay.self` to the `Schema([...])`.
- Seed an open `BusinessDay` on launch if none exists (the "current business day" = the one `BusinessDay` with `closedAt == nil`).

**7. XCTest target**
- Create a Unit Testing bundle target (in Xcode: File → New → Target → Unit Testing Bundle — adding a *target* needs GUI/pbxproj; synced folders only auto-include files, not targets).
- Port the 18 tests from `.tmp/tdd/Tests.swift` into XCTest `XCTestCase` methods.
- Run: `xcodebuild test -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 16'` (adjust simulator name).

**No migration needed** — no shipped data exists. If a stale dev store errors on schema change, delete it on first run.

---

## Phase 2 — UI  (after Phase 1 typechecks)

Rebuild `ContentView.swift` to the 3-level navigation agreed in grilling:

1. **Home**: two cards — **FOH**, **BOH** (the `Area`s).
2. **Tap an area**: cards **Opening**, **Closing**, **Weekly** (filtered by `cadence`/`phase`).
3. **Tap a card**: the duties, each showing **derived** state via the `DutyStatus` seam.

**Derived state** (never stored — ADR #1):
- Current business day = the `BusinessDay` with `closedAt == nil` (seed if none).
- Daily duty done ↔ a `CompletionLog` exists for it whose `businessDay == currentBusinessDay`.
- Weekly duty done ↔ a `CompletionLog` exists for it with `timestamp` inside `mondayStartWeekInterval(containing: now)`.
- Status via `dailyDutyStatus(...)` / `weeklyDutyStatus(...)`; show only duties where `shouldSurface(status)` is true.

**"Finish day" button** (manager-only — gate on `user.role == .manager`):
- Sets `currentBusinessDay.closedAt = .now`.
- Creates a new open `BusinessDay`.
- Daily duties reset automatically (new business day has no logs → derived state reads undone).

---

## Phase 3 — finish

- Run the **`/code-review`** skill against `CONTEXT.md` + `docs/adr/0001-derived-completion-state.md`.
- Run full `xcodebuild test`.
- Commit to `main`.

---

## Open edge cases (not blocking — decide during implementation)

- **Forgotten finish-day**: if nobody hits "Finish day", the next morning's logs attach to yesterday's still-open business day. Mitigation options: warn on launch if the open business day is >24h old; auto-prompt manager.
- **Finish-day with incomplete duties**: allowed (just closes the day) or blocked until all closing duties done? Decide.
- **Un-done Sunday weekly duty**: clears Monday (week rollover) — already handled correctly by the tested logic.

---

## Quick domain refresher (full detail in `CONTEXT.md` + ADR #1)

- **6 checklists** = Area `{FOH,BOH}` × Cadence `{daily,weekly}` × (Phase `{opening,closing}` for daily only).
- **Weekly duties** are bound to a `Weekday`; surface from that day onward; haunt as `.overdue` until done; clear at Monday rollover.
- **The tick is derived, not stored** — `isCompleted`/`completedAt` are gone. "Done" = a completion log exists in the current business day (daily) or Monday-start week (weekly).
- **Business day** ends on an explicit manager "Finish day" action (closings happen 11pm–2am, not midnight). A log at 1:30am Sunday belongs to Saturday's business day → `CompletionLog` must carry a `businessDay` reference, not just a timestamp.
