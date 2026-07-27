# A manager who launches the app with a stale open business day is alerted and can recover in one tap

If nobody hits Finish Day, the open `BusinessDay` stays open indefinitely. The next morning's `CompletionLog`s silently attach to yesterday's still-open business day. The data is correct per the model (the day didn't end), but the *meaning* is wrong — yesterday looks under-counted (today's logs mixed in), and there's no clean "today" yet. Today's work cannot be cleanly reviewed later because there's no boundary between yesterday and today.

This ADR adds a launch-time staleness check and a one-tap recovery. It touches no model — `BusinessDay` already carries `openedAt`, and the existing `finishDay()` already atomically closes the current day and opens the next. The new surface is a manager-only alert driven by a pure helper that decides when "open for too long" becomes "forgotten."

## Decisions

- **Threshold: 24 hours, hardcoded.** Any legitimate business day fits inside 24 hours — a restaurant open 6am to 2am next day is 20 hours, and even that is an outlier. 24 hours is "definitely forgotten, not borderline." Mirrors `LogRetention.retentionWindow` as a named constant in a pure helper, single source of truth.
- **Manager-only auto-alert on launch.** Surfaces as a `.alert` when `currentBusinessDay.openedAt` is older than the threshold. Modal interruption is warranted — this is a data-correctness issue, not a preference. The alert reappears on every cold launch while still stale; dismiss is not persisted, so a manager who dismisses without fixing will see it again next cold launch.
- **Staff see nothing.** Staff cannot act on a stale day (`finishDay` is manager-only — ADR 0003), and surfacing "something is broken that you can't fix" is friction without payoff. Staff logs still attach to the stale day; the audit trail stays intact; the data is correct per the model. The meaning problem is the manager's to resolve.
- **One-tap recovery via the existing `finishDay()`.** The alert's primary button is labeled "Finish Day" and calls the existing `AreaListView.finishDay()` directly. No new "recovery" code path; reuses what's tested. A manager who dismisses and then taps the toolbar "Finish Day" button gets the same behavior — the alert is just a louder version of the existing affordance.
- **Pure helper, framework-free.** `BusinessDayHealth.isStale(openedAt:asOf:) -> Bool` lives in `checklist-app/Scheduling/`, mirrors the `LogRetention` / `StaffManagement` caseless-enum pattern. Takes primitives, not `BusinessDay` — unit-testable without a SwiftData container. The strict-greater-than boundary is pinned by tests.

## What changes in the existing code

- **New file `checklist-app/Scheduling/BusinessDayHealth.swift`** — caseless enum namespace. `staleThreshold: TimeInterval = 24 * 60 * 60` (named so the policy is searchable from one place). `isStale(openedAt: Date, asOf: Date) -> Bool` returns `asOf - openedAt > staleThreshold`. Framework-free.
- **New file `checklist-appTests/BusinessDayHealthTests.swift`** — pins the strict-greater-than boundary at 24 hours with three dedicated tests (`==threshold` not stale, `threshold-1s` not stale, `threshold+1s` stale). Plus common cases (just opened, 7 days ago) and a defensive clock-skew case (future `openedAt` must not flag stale).
- **`checklist-app/ContentView.swift` (`AreaListView`)** — gains `@State showingStaleDayAlert` and `@State didCheckStalenessOnAppear`. Computed `isStaleDay` derived from `currentBusinessDay.openedAt` via the helper. `.onAppear` (gated by the one-shot flag) sets the alert state if `currentUser?.isManager == true && isStaleDay`. `.alert` with two buttons: "Finish Day" (calls existing `finishDay()`) and "Not Now" (cancel). Staff never trigger the alert.

## Threat model (unchanged from ADR 0002 / 0003 / 0004)

Nothing structural changes. The staleness check is read-only; the recovery is the existing manager-only `finishDay()`. No new privileged surface, no new persistent state, no new authentication boundary. The risk of *not* having this surface (silent meaning-drift in the audit trail) is greater than the risk of an occasional modal interruption.

## Rejected alternatives

- **18-hour threshold.** Catches forgotten days earlier but false-positives on slow-closing restaurants (20-hour legitimate days exist for early-open / late-close service). 24h is unambiguous.
- **Badge the Finish Day button instead of a modal alert.** Easy to miss; silent meaning-drift is exactly what this feature exists to prevent. Revisit if managers complain the alert is too aggressive — but start with the loud version.
- **Persist "don't show me this again" dismissal.** If the manager dismisses without fixing, the next cold launch should re-alert. Persisted dismissal would let a stale day drift indefinitely, defeating the feature.
- **Configurable threshold per restaurant.** Scope creep — ADR 0004 explicitly deferred "configurable per restaurant" to multi-tenant. Hardcoded 24h is honest about the policy and easy to find.
- **Banner instead of alert.** A passive banner is appropriate for "FYI"; a stale business day is "this needs your attention now." Modal alert matches the urgency.
- **Show staff a "the manager needs to finish the previous day" banner.** Friction without payoff — staff can't act. The audit trail stays correct under a stale day; only the *meaning* is wrong, and meaning is the manager's call.
- **Auto-finish the stale day on launch without asking.** Removes manager agency and could surprise a manager who intentionally left the day open (e.g. auditing after close). The alert is one tap; auto-recovery is the same number of actions but less predictable.
- **Server-side / cron reminder.** No server exists. Local on-launch is the right scope for a single-device app.
- **Re-alert on warm-launch (background → foreground).** The check fires on cold launch (view creation), not on every scene-phase transition to `.active`. A manager who dismisses and re-foregrounds the app seconds later is continuing the same session; re-alerting within that session is friction. If the manager kills and reopens the app, the view re-creates and the check re-fires.

## Open questions deferred to follow-ups

- **Auto sign-out on idle** (ADR 0002 follow-up, unchanged): a shared device left signed in misattributes logs. A stale-day alert reaches whoever launches the app — a signed-out device with no manager PIN still has the problem but no UI surface to fix it from.
- **Configurable threshold per restaurant** (deferred to multi-tenant — ADR 0004).
- **Notification-based reminder** (ROADMAP Feature #6): a push reminder at, say, 2am if the day is still open would catch the problem before the next morning. Separate feature; this ADR addresses the "morning-of" detection path.
