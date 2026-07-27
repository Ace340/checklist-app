# Past business days are reviewable in a manager-only history view; managers can edit notes / re-attribute and delete logs; logs roll off after 30 days

The app gains its first read surface for the audit trail ADR 0001 promised. Managers can browse past business days, drill into FOH / BOH, and see every `CompletionLog` captured in each Area. They can also correct logs (`note` and `completedBy` only) and delete them outright. To keep the store from growing without bound on a shared device, logs older than 30 days are hard-deleted on app launch.

This ADR **revises one clause of ADR 0001**: that decision said *"every previous day's history stays intact forever in the logs."* The forever claim was made before any retention pressure existed. With history now readable and editable, retention becomes a real concern — a shared device left in service for years would otherwise accumulate thousands of logs per duty with no recovery path and no value. Thirty days is the new contract: managers get a generous correction window; the store stays bounded. ADR 0001's core decision — *state is derived from logs, not stored on duties* — is unchanged.

This ADR extends ADR 0002 (auth/current-user) and ADR 0003 (manager-only permissions) by adding two more manager-gated surfaces (history view, log mutation). The threat model is unchanged: manager-only actions, soft PIN credential, single-device single-restaurant.

## Decisions

- **New `HistoryView`, manager-only, reached from a clock icon.** Sits in `AreaListView`'s toolbar beside the staff gear. Opens as a `.sheet` containing a `NavigationStack` + `List` of past business days (most recent first), drill into FOH / BOH / Other sections, then logs under each. The currently-open business day is included at the top.
- **One canonical grouping: business day → Area → logs.** No alternate groupings (by duty, by user, by Phase). Managers answering "what happened in BOH last Wednesday night" get a single, predictable path. A small "Other" section catches logs whose Area can't be derived (`duty?.checklist?.area == nil` — deleted duty, deleted checklist) so they remain visible rather than silently dropping. Revisit if a real reporting need surfaces.
- **Screen only — no PDF / CSV export.** Out of scope for this feature. Adding export later is additive (a toolbar button that reads the same query); it doesn't shape today's model.
- **Rolling 30-day retention, hard delete, no tombstone.** A log is eligible for deletion once its `timestamp` is older than 30 × 24 hours from "now." Cleanup runs on app launch as part of the existing `seedOnLaunch` touch — no background task, no `BGTaskScheduler` dependency. Hard delete (no `archivedAt`, no soft-delete field) — the 30-day window *is* the recovery path; a tombstone would re-introduce unbounded growth with extra steps.
- **Edit scope: `note` + `completedBy` only.** A manager can correct a log's note text and re-attribute it to a different user (the canonical "I logged this under the wrong name" fix). `timestamp` and `duty` are not editable — changing either would silently move the log to a different business day / week or reattach it to a different duty, breaking derived state. The explicit, auditable path for those cases is delete + recreate.
- **Delete is irreversible.** Manager-only, no undo toast, no recycle bin. Confirmed via a standard `.alert` (destructive-button + cancel) before the `modelContext.delete` call. Same destructive-action shape as `StaffManagementView`'s delete-user flow — both use `.alert` rather than `.confirmationDialog` because the action target is already known (no selection step the dialog would solve).
- **Audit stamps on edit: `lastEditedAt` + `lastEditedBy`.** Two new nullable fields on `CompletionLog`. `nil` means the log has never been edited — a clean signal that the row is original. First edit sets both fields; subsequent edits update both. Deletion leaves no stamp (there is nothing to stamp on).
- **`LogRetention` is a namespace of pure helpers** (`cutoffDate(asOf:)`, `logsToDelete(in:asOf:)`). Framework-free, unit-testable, mirrors `PinHasher` / `StaffManagement`. The UI / app entry point calls `LogRetention.logsToDelete(...)` and performs the deletes; the helper itself never touches SwiftData.
- **No `LogEditPolicy` helper namespace.** The only rule is "the current user is a manager" — same shape as `DutyListView`'s existing `+` button gate, which is inline. A helper file for a single `isManager` check would be ceremony without payoff.
- **Retention applies uniformly.** All `CompletionLog`s regardless of area / cadence / phase / age-of-business-day. No "keep closing logs longer" carve-outs; if a real reporting need surfaces (e.g. legal hold on incident logs), it becomes a separate field on the log.

## Threat model (unchanged from ADR 0002 / 0003)

Nothing structural changes. The PIN's job remains audit attribution, not protecting money or PII. The new risk surface — a manager editing or deleting logs — is itself manager-gated, so the only escalation beyond "I know a PIN" is "I know a *manager's* PIN," which is what a manager is. The `lastEditedAt` / `lastEditedBy` stamps preserve *who changed what when* for edited logs; deletions are silent today (see deferred questions). Hard-delete retention is destructive by design — the 30-day window is the recovery contract, and managers are the trusted role for that contract.

## What changes in the existing model

- **`CompletionLog`** — gains two nullable fields: `lastEditedAt: Date?` and `lastEditedBy: User?` (to-one inverse, `.nullify` on the User side for symmetry with `completedBy`). Default `nil` on both. No other schema change; `timestamp`, `note`, `duty`, `completedBy`, `businessDay` are unchanged. The class doc comment updates to reflect that the log is now mutable under manager edit (was "immutable audit record").
- **`checklist_appApp.swift`** — `seedOnLaunch` fetches all `CompletionLog`s, calls `LogRetention.logsToDelete(in:asOf:)`, and `modelContext.delete`s each result. Runs after the open-business-day seed, before the UI appears. No user-visible latency (data volume is bounded by the 30-day window; an empty result is a no-op).
- **`ContentView.swift` (`AreaListView`)** — toolbar gains a clock icon (`clock.arrow.circlepath`) beside the staff gear. Manager-only, sheet presentation.
- **New file `checklist-app/History/HistoryView.swift`** — `NavigationStack` + `List` of past business days (most recent first). Drill into FOH / BOH / Other groups. Logs under each group show duty name, timestamp, completer name, note (if any), and an "edited" badge if `lastEditedBy != nil`. Swipe-left on a log row to delete (with confirmation). Tap a row to open `LogEditSheet`.
- **New file `checklist-app/History/LogEditSheet.swift`** — manager-only edit sheet. Two fields: `note` (text) and `completedBy` (picker over all `User`s). Save sets `lastEditedAt = .now` and `lastEditedBy = currentUser`. Cancel does nothing.
- **New file `checklist-app/History/LogRetention.swift`** — pure helper namespace. `cutoffDate(asOf: Date) -> Date` returns `asOf - 30 * 24 * 60 * 60 seconds`. `logsToDelete(in logs: [CompletionLog], asOf: Date) -> [CompletionLog]` filters by `timestamp < cutoff`. Framework-free.

## Rejected alternatives

- **Soft delete / tombstone (`archivedAt: Date?`).** Adds a field, complicates every history query (`where archivedAt == nil`), and re-introduces unbounded growth. Hard delete with a 30-day window is simpler and honest about what's happening.
- **Calendar-month retention (e.g. "delete on the 1st").** Gives 28–31 days of history unpredictably; rolling 30 days is always 30 days. Also avoids the "everything from last month vanishes at once" UX surprise.
- **Edit-any-field (including `timestamp` and `duty`).** Silently moves a log across business-day / week / duty boundaries — the kind of mutation that makes an audit trail worse than none. Delete + recreate is the explicit, visible path.
- **CSV / PDF export.** Adds dependencies (PDF generation, file sharing) and UX surface for a need no stakeholder has raised. Revisit when (a) a manager asks to email a business-day report or (b) legal hold requires it. Export is additive later — it reads the same queries.
- **Alternate groupings (by duty, by user, by weekday).** One canonical hierarchy = simpler UX and simpler tests. Add a toggle later if managers complain; don't pre-build.
- **`BGTaskScheduler` for retention cleanup.** Overkill for a per-launch query against an indexed `timestamp`. Background tasks also add entitlement / capability surface and require a scheduler API the app doesn't otherwise touch.
- **`LogEditPolicy` helper namespace.** The only rule is "current user is a manager." A separate file for `canEditLog(currentUser:) -> Bool { currentUser.isManager }` would mirror `StaffManagement` mechanically without its multi-rule substance. Inline gate matches the existing `DutyListView` `+` button.
- **Deletion audit log (`LogMutationAudit` aggregate).** Capturing *who deleted what when* would require a new model and a parallel trail. Defer until a real "who deleted this" question surfaces; the manager-only gate is the trust boundary for now.
- **Undo toast on delete.** Adds transient UI state for a recovery that the 30-day window already covers in the obvious direction (re-create the log). Defer until managers complain.

## Open questions deferred to follow-ups

- **Bulk log actions** (e.g. "delete all logs for user X who left the restaurant"). Out of scope; the per-row swipe path handles today's volume.
- **Configurable retention per restaurant.** Currently hardcoded 30 days. Revisit when multi-tenant (single-site multi-restaurant) surfaces — retention as a `Restaurant` property.
- **Deletion audit trail.** See "Rejected alternatives" — `LogMutationAudit` is the shape if a "who deleted this" need surfaces.
- **Search / filter within the history view.** Chronological scroll is fine for one month of logs; revisit if a busy restaurant makes scroll painful.
- **"Edited" indicator UX.** Currently a small "edited" badge with `lastEditedBy`'s name on tap. Whether to show the *previous* value (revision history) is its own design question; deferred.
