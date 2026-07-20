# Roadmap

What to build next, in priority order. Each feature is sized so it can land in one session (Small/Medium) or a short series (Large). Pick one, resolve its open questions with the stakeholder, then build.

This doc is a sibling to `NEXT-STEPS.md` (session-by-session handoff) and `docs/adr/` (architecture decisions). The domain language is defined in `CONTEXT.md`.

## Current state (Feature #1 + #7 — auth/session + staff management — complete)

The core loop works: 6 checklists (Area × Cadence × Phase), tap-to-complete with derived state, manager finish-day, full audit trail in `CompletionLog` — now including **who** completed each duty (Feature #1). PIN-based login via onboarding wizard (no seeded demo users), shared-device session, finish-day gated on the signed-in manager, manager-only staff directory & duty editing (Feature #7). 66/66 tests green. What's missing for a real restaurant to use this daily is below.

## Priority features

### 1. Auth & current-user session ✅ DONE (2026-07-20)

**What:** Replace the seeded default manager with a real login / current-user session.

**Status:** Shipped. PIN-based (4 digits), shared device, one PIN per session, `@Observable AuthStore` in `.environment`, PIN stored as SHA-256 + per-user salt. `CompletionLog.completedBy` is now populated on every new log; Finish Day gates on the signed-in manager. See `docs/adr/0002-auth-and-current-user-session.md`. 44/44 tests green at the time; the rolling total is now 66/66 (Feature #7 added 22).

**Deferred follow-ups (not blocking, captured in ADR 0002):**
- ~~Staff-management UI~~ — ✅ Shipped as Feature #7 below.
- ~~Forgotten-PIN recovery~~ — ✅ Shipped: managers reset any non-self user's PIN via the Staff screen (Feature #7).
- Auto sign-out on idle for shared-device hygiene.

### 7. Staff management & duty permissions ✅ DONE (2026-07-20)

**What:** Manager-only UI for managing the user directory (add, rename, promote/demote, reset PIN, delete users) and manager-only editing of the duty catalog (add duties). Replaces the seeded demo users with a first-launch onboarding wizard that creates the first manager.

**Status:** Shipped. Pure permission helpers in `StaffManagement.swift` (`canCreateUser`/`canEdit`/`canPromote`/`canDemote`/`canDelete`) backed by 19 unit tests; `StaffManagementView` (list/add/edit/delete/reset-PIN); `OnboardingView` (first-launch wizard); gear icon in `AreaListView` toolbar (manager-only); `+` button on `DutyListView` hidden for staff with defense-in-depth `onAppear` check in `AddDutySheet`. Self-protection (no demote/delete self) and last-manager protection enforced. See `docs/adr/0003-staff-management-and-duty-permissions.md`. 66/66 tests green.

**Deferred follow-ups (captured in ADR 0003):**
- Bulk staff import (CSV / paste-a-list) — real restaurants onboard 10-30 staff at once.
- Audit trail of management actions ("who promoted whom," "who reset whose PIN") — would need a separate `ManagementActionLog` aggregate.
- Required PIN complexity / rotation.
- Duty edit/delete UI — the *permission* is locked here; the UI is its own piece of work.

### 2. Forgotten finish-day handling

**What:** Warn (or auto-prompt) on launch if the current open `BusinessDay` is older than a threshold.

**Why:** If nobody hit Finish Day last night, this morning's logs silently attach to yesterday's still-open business day. The data is correct per the model (the day didn't end), but the *meaning* is wrong — yesterday looks incomplete, today looks empty.

**Scope:** Small. Pure UI logic — compare `BusinessDay.openedAt` to `.now`, show an alert.

**Dependencies:** Benefits from Feature #1 (auth) so the warning reaches a manager specifically.

**Open questions:**
- Threshold: 24 hours? 18 hours? Configurable per restaurant?
- Auto-prompt the manager, or just badge the Finish Day button?
- Should "close the stale business day AND open a fresh one" be a single recovery action?

### 3. Finish-day with incomplete closing duties

**What:** Decide what happens when a manager hits Finish Day with closing duties still pending.

**Why:** Currently allowed silently. Restaurants will want one of three policies; this is a product call, not a technical one.

**Scope:** Small once the policy is decided. Likely a confirmation dialog listing the incomplete duties.

**Dependencies:** None.

**Open questions:**
- **Block** (force completion first)? **Warn** (alert + require second tap)? **Allow** (current behavior)?
- Does the policy vary by Area (FOH vs BOH) or by duty (e.g. "count the drawer" is required, "wipe menus" isn't)?
- Should "override with reason" be logged to the audit trail?

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

### 5. Business-day history & log viewer

**What:** A read-only view of past business days — who completed what, when, with notes. Filter by Area, Phase, duty, user.

**Why:** The audit trail already exists in `CompletionLog` — the data is perfect — but there's no UI to read it. Managers can't review last Wednesday's closings today. This is the pay-off for ADR #1's "logs are forever" guarantee.

**Scope:** Medium. Mostly a new view layer; reuses existing models.

**Dependencies:** Much more valuable after Feature #1 (auth) populates `completedBy`. Without auth, the history shows *what* happened but not *who* did it.

**Open questions:**
- Group by business day, then Area? Or by duty, then date?
- Export — PDF report, CSV, or just on-screen?
- How long to retain logs? (Currently forever. Restaurant-legal hold periods vary.)
- Undo window — should managers be able to edit or delete logs within X minutes of creation?

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
