# Roadmap

What to build next, in priority order. Each feature is sized so it can land in one session (Small/Medium) or a short series (Large). Pick one, resolve its open questions with the stakeholder, then build.

This doc is a sibling to `NEXT-STEPS.md` (session-by-session handoff) and `docs/adr/` (architecture decisions). The domain language is defined in `CONTEXT.md`.

## Current state (Feature #1 — auth/session — complete)

The core loop works: 6 checklists (Area × Cadence × Phase), tap-to-complete with derived state, manager finish-day, full audit trail in `CompletionLog` — now including **who** completed each duty (Feature #1). PIN-based login, shared-device session, finish-day gated on the signed-in manager. 44/44 tests green. What's missing for a real restaurant to use this daily is below.

## Priority features

### 1. Auth & current-user session ✅ DONE (2026-07-20)

**What:** Replace the seeded default manager with a real login / current-user session.

**Status:** Shipped. PIN-based (4 digits), shared device, one PIN per session, `@Observable AuthStore` in `.environment`, PIN stored as SHA-256 + per-user salt. `CompletionLog.completedBy` is now populated on every new log; Finish Day gates on the signed-in manager. See `docs/adr/0002-auth-and-current-user-session.md`. 44/44 tests green.

**Deferred follow-ups (not blocking, captured in ADR 0002):**
- Staff-management UI (add/edit/remove users, change PINs) — currently seed-only.
- Auto sign-out on idle for shared-device hygiene.
- Forgotten-PIN recovery flow.

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
