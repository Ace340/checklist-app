# Roadmap

What to build next, in priority order. Each feature is sized so it can land in one session (Small/Medium) or a short series (Large). Pick one, resolve its open questions with the stakeholder, then build.

This doc is a sibling to `NEXT-STEPS.md` (session-by-session handoff) and `docs/adr/` (architecture decisions). The domain language is defined in `CONTEXT.md`.

## Current state (Features #1 + #7 + #5 + #2 + #3 — auth/session, staff management, history viewer, forgotten finish-day, finish-day warn — complete)

The core loop works: 6 checklists (Area × Cadence × Phase), tap-to-complete with derived state, manager finish-day, full audit trail in `CompletionLog` — including **who** completed each duty (Feature #1). PIN-based login via onboarding wizard (no seeded demo users), shared-device session, finish-day gated on the signed-in manager, manager-only staff directory & duty editing (Feature #7). Manager-only business-day history viewer with edit (`note` + `completedBy`) and delete; rolling 30-day hard-delete retention (Feature #5). Manager-only stale-business-day alert on cold launch (24h threshold) with one-tap recovery via existing `finishDay()` (Feature #2). Manager-only warn-and-confirm dialog when Finish Day is tapped with closing duties still incomplete — lists the duties, requires a deliberate "Finish Anyway" second tap (Feature #3). 94/94 tests green. What's missing for a real restaurant to use this daily is below.

## Priority features

### 1. Auth & current-user session ✅ DONE (2026-07-20)

**What:** Replace the seeded default manager with a real login / current-user session.

**Status:** Shipped. PIN-based (4 digits), shared device, one PIN per session, `@Observable AuthStore` in `.environment`, PIN stored as SHA-256 + per-user salt. `CompletionLog.completedBy` is now populated on every new log; Finish Day gates on the signed-in manager. See `docs/adr/0002-auth-and-current-user-session.md`. 44/44 tests green at the time; the rolling total is now 78/78 (Feature #5 added 12).

**Deferred follow-ups (not blocking, captured in ADR 0002):**
- ~~Staff-management UI~~ — ✅ Shipped as Feature #7 below.
- ~~Forgotten-PIN recovery~~ — ✅ Shipped: managers reset any non-self user's PIN via the Staff screen (Feature #7).
- Auto sign-out on idle for shared-device hygiene.

### 7. Staff management & duty permissions ✅ DONE (2026-07-20)

**What:** Manager-only UI for managing the user directory (add, rename, promote/demote, reset PIN, delete users) and manager-only editing of the duty catalog (add duties). Replaces the seeded demo users with a first-launch onboarding wizard that creates the first manager.

**Status:** Shipped. Pure permission helpers in `StaffManagement.swift` (`canCreateUser`/`canEdit`/`canPromote`/`canDemote`/`canDelete`) backed by 19 unit tests; `StaffManagementView` (list/add/edit/delete/reset-PIN); `OnboardingView` (first-launch wizard); gear icon in `AreaListView` toolbar (manager-only); `+` button on `DutyListView` hidden for staff with defense-in-depth `onAppear` check in `AddDutySheet`. Self-protection (no demote/delete self) and last-manager protection enforced. See `docs/adr/0003-staff-management-and-duty-permissions.md`. 66/66 tests green at the time; the rolling total is now 78/78.

**Deferred follow-ups (captured in ADR 0003):**
- Bulk staff import (CSV / paste-a-list) — real restaurants onboard 10-30 staff at once.
- Audit trail of management actions ("who promoted whom," "who reset whose PIN") — would need a separate `ManagementActionLog` aggregate.
- Required PIN complexity / rotation.
- Duty edit/delete UI — the *permission* is locked here; the UI is its own piece of work.

### 5. Business-day history & log viewer ✅ DONE (2026-07-21)

**What:** A read-only (plus manager edit/delete) view of past business days — who completed what, when, with notes. Grouped by Area.

**Status:** Shipped. Manager-only `HistoryView` (reached from a new clock icon beside the staff gear): list of business days (most recent first, open day at top) → drill into FOH / BOH / Other sections → logs sorted newest-first within each. Tap a log to edit `note` + `completedBy` via `LogEditSheet` (manager-only, defense-in-depth `onAppear` re-check, stamps `lastEditedAt`/`lastEditedBy` atomically). Swipe-left on a log to delete with `.alert` confirmation. Rolling 30-day hard-delete retention runs on app launch via `LogRetention` pure helper. See `docs/adr/0004-history-viewer-and-retention.md`. 78/78 tests green.

**Deferred follow-ups (captured in ADR 0004):**
- Bulk log actions (e.g. "delete all logs for user X who left").
- Configurable retention per restaurant — currently hardcoded 30 days.
- Deletion audit trail (`LogMutationAudit` aggregate) — deletes are silent today.
- Search / filter within the history view.
- "Edited" indicator UX — revision history would be its own design question.

### 2. Forgotten finish-day handling ✅ DONE (2026-07-27)

**What:** Warn (or auto-prompt) on launch if the current open `BusinessDay` is older than a threshold.

**Status:** Shipped. Manager-only `.alert` on cold launch when `currentBusinessDay.openedAt` is older than 24 hours (hardcoded, mirrors `LogRetention.retentionWindow` pattern). "Finish Day" primary button calls existing `finishDay()` directly (one-tap recovery); "Not Now" cancel. Staff see nothing. Dismiss is not persisted — alert re-fires next cold launch while still stale. Pure helper `BusinessDayHealth.isStale(openedAt:asOf:)` is the single source of truth for the rule, framework-free, pinned by 8 tests including the strict-greater-than boundary at exactly 24h. See `docs/adr/0005-forgotten-finish-day.md`. 86/86 tests green at landing; rolling total is now 86/86.

**Resolved decisions (in ADR 0005):**
- Threshold: 24 hours hardcoded (not 18h, not configurable).
- Auto-prompt via `.alert` (not badge, not banner).
- One-tap recovery via existing `finishDay()` — no new "recovery" code path.
- Staff see nothing (can't act; surfacing broken-but-unfixable is friction).

**Deferred follow-ups (captured in ADR 0005):**
- Auto sign-out on idle (ADR 0002 follow-up, unchanged).
- Configurable threshold per restaurant (deferred to multi-tenant — ADR 0004).
- Notification-based reminder (ROADMAP Feature #6) — would catch the problem before morning; this feature is the "morning-of" detection path.

### 3. Finish-day with incomplete closing duties ✅ DONE (2026-07-27)

**What:** Decide what happens when a manager hits Finish Day with closing duties still pending.

**Status:** Shipped as **Warn**. A non-empty list of incomplete closing daily duties triggers a `.alert` titled "Finish Day?" with the count, a bullet list of duty titles, and two buttons: "Finish Anyway" (calls existing `finishDay()`) and "Cancel" (does nothing). Applied uniformly across FOH + BOH; no per-duty criticality, no per-Area variation. Both Finish Day entry points (toolbar button + stale-day recovery alert from ADR 0005) route through the same gate so the warn policy is uniform. Pure helper `FinishDayPolicy.incompleteClosingDuties(in:businessDay:)` is the single source of truth for the rule, framework-free, pinned by 8 tests using an in-memory SwiftData container (mirrors `AuthStoreTests`). No model change — completion is derived per ADR 0001. See `docs/adr/0006-finish-day-with-incomplete-closing-duties.md`. 94/94 tests green at landing (rolling total 86 + 8 new).

**Resolved decisions (in ADR 0006):**
- Policy: Warn (not Block, not Allow-silent).
- Scope: Uniform — every closing daily duty, both Areas.
- Surfaced in the alert: the duty titles (bullet list, pluralized header).
- Definition of "closing duty": `checklist.cadence == .daily && checklist.phase == .closing`. Weekly checklists have `phase == nil` by design and are excluded.
- Override is **not** audited (deferred).

**Deferred follow-ups (captured in ADR 0006):**
- Override audit trail (`BusinessDay.closedWithIncompleteDuties` snapshot or `FinishDayOverrideLog` aggregate).
- Per-duty criticality (`.required` / `.skippable` flag on `TaskItem` — naturally pairs with the still-unbuilt duty edit UI from ADR 0003).
- Block mode as opt-in (helper already returns the list; UI swap is one method).
- Staff visibility of "can't leave yet, closing duties incomplete" (separate feature, separate ADR).

### 4. Duty templates & seed data

**What:** Ship a default set of restaurant duties per checklist so the first user doesn't have to enter ~40 items by hand.

**Why:** Currently every duty is manual entry. That's fine for development, brutal for first-run experience. A restaurant-ops-savvy default set gets a new installation to "useful" in one tap.

**Scope:** Medium. Data, not code — but needs careful domain input.

**Dependencies:** None technically. Wants input from a real restaurant manager to choose the right defaults.

**Open questions:**
- Per-checklist templates (6 files), or one JSON blob keyed by `(area, cadence, phase)`?
- Should templates vary by restaurant type (quick-service vs full-service vs cafe)?
- Reset to defaults — feature or anti-feature? (If a manager deletes a templated duty, do software updates restore it?)
- Where does the seed data live — bundled JSON, Swift constants, or a SwiftData seed-on-first-launch like the current `seedOnLaunch`?

### 6. Notifications & reminders

**What:** Local notifications for overdue weekly duties, a before-close Finish Day reminder, and (optionally) at-open nudges.

**Why:** Weekly duties in particular are easy to miss — a Wednesday duty that doesn't get done becomes invisible by Thursday without active checking. A nudge closes that loop.

**Scope:** Medium. Needs `UNUserNotificationCenter`, permission flow, and timing rules that respect the business-day concept (not midnight).

**Dependencies:** None for basic reminders. Wants Feature #1 (auth) for "remind *this* user about *their* duties."

**Open questions:**
- iOS local notifications only, or also a server-side push path later?
- Reminder timing — fixed times of day, or relative to business-day open/close?
- Overdue escalation — one nudge, or repeating until dismissed/done?

## Future / out of scope (for now)

These are real but not next:

- **Multi-location / multi-restaurant:** one app, many sites, per-site business days. Significant model change — surfaces `Restaurant` as a new aggregate root. Wait until single-site is genuinely daily-driven.
- **Offline mode & sync:** restaurants often have spotty WiFi in BOH. SwiftData + CloudKit would help, but introduces conflict resolution. Not next.
- **Custom cadences:** monthly or quarterly duties (e.g. "deep clean the walk-in"). The `Cadence` enum is currently closed; adding cases is cheap but the surfacing logic needs generalizing.
- **Photos & attachments on completion logs:** "here's the clean hood" proof. Schema addition, not architectural — but storage and review UX are real work.
- **Recurrence patterns beyond weekday:** "every other Monday", "first of month", etc. Likely better as a small recurrence mini-DSL than enum cases.

## How to use this doc

1. Pick a feature.
2. Read its **Open questions** — resolve them with the stakeholder first (don't guess mid-build).
3. If the resolution changes the architecture, write an ADR in `docs/adr/` before coding.
4. Build it test-first where possible (Phase 0-style pure logic, then SwiftData model, then UI).
5. Update `docs/NEXT-STEPS.md` with a session handoff when you stop.
