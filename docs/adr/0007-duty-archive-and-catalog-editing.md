# Duty archive (soft-delete), restoration, and catalog editing

**Status:** Accepted (locked during a `/grill-with-docs` session, 2026-08-04). Implementation pending.

Managers need to remove duties that are no longer part of service without destroying the audit trail those duties accumulated. We introduce **archive** as a reversible soft-delete on `TaskItem`, paired with a manager-only catalog editor covering edit, archive, and restore. This closes the ADR 0003 follow-up ("duty edit/delete UI") and unblocks Feature #4 (duty templates & seed data) by giving the templated duties a place to live and a way to be retired.

This ADR extends ADR 0003 (which locked the *permission* model — manager-only) and revises the consequence of ADR 0001's "history stays intact" clause: archive replaces hard-delete precisely so that clause can stay true.

## Decisions

- **Soft-delete via `TaskItem.archivedAt: Date?`.** `nil` = active; non-nil = archived. The single source of truth for archive state. A duty is never hard-deleted through UI action; only archive (reversible) and SwiftData's existing `.cascade` rule on `logs` (now effectively unreachable via UI) govern end-of-life.
- **Two-way door — restore is a first-class action.** A manager can restore an archived duty; it returns to its original checklist at its original `order`, with all historical logs intact. Matches the seasonal-duty workflow (patio checklist archived in winter, restored in spring).
- **No `archivedBy: User?`.** Only managers can archive (ADR 0003), and the action is housekeeping, not compliance-sensitive. Adding it would mean a new `@Relationship` inverse on `User` for low audit value. Reconsider only if "who archived this" becomes a real question.
- **`checklist` and `order` are preserved through archive.** The duty stays attached to its original checklist at its original position; it is merely hidden from surfacing. This makes restore trivial — clear the flag.
- **Restore collisions are tolerated.** If two duties share an `order` value after restore (because a new duty was created in the meantime), SwiftData's stable sort handles the tie. No bespoke merge logic.
- **Surfacing hides archived duties.** `DutyStatus.shouldSurface` gains a clause: hide when `archivedAt != nil`. Same predicate flavor as the existing weekday/cadence surfacing.
- **Finish-day warn ignores archived duties.** `FinishDayPolicy.incompleteClosingDuties` excludes archived closing duties — a retired closing duty must not block finish-day.
- **History viewer surfaces archived duties with a badge.** Logs belonging to archived duties remain visible in `HistoryView` (per ADR 0004), with an "Archived" badge on those rows so a manager scanning history understands why a duty absent from the catalog appears in the log.
- **Manager-only, gated by `currentUser.isManager`.** Consistent with ADR 0003. Archive, restore, and edit are all manager-only actions; staff see only the active catalog.

## Edit semantics (field-by-field)

- **`title` — editable.** Renames propagate retroactively to all historical `CompletionLog`s because logs reference the duty, not a title snapshot. A log from months ago in the history viewer shows the *current* title, not the title-at-the-time. Standard pattern (matches how tasks/todos work everywhere); accepted cost.
- **`order` — editable (drag-to-reorder).** Pure display concern; zero blast radius on logs.
- **`weekday` (weekly duties only) — editable.** Past logs don't care (they're timestamps, not weekday-bound); future surfacing changes accordingly. A Wednesday→Monday switch leaves last week's Wednesday log in last week; this week surfaces Monday. Correct.
- **`checklist` (move duty to a different checklist) — NOT editable. Deliberate no.** Moving between checklists is effectively "this duty as it was is over; a new duty in a new context takes its place." A log recorded when "Sharpen knives" was a Wednesday weekly duty would appear in history under the new context (say, daily closing) — confusing forever, not just once. The clean pattern is **archive the old + create a new one in the right slot.** Logs stay with the archived original; the new duty starts fresh.
- **No title-edit audit fields** (`lastEditedAt` / `lastEditedBy` on `TaskItem`). Same reasoning as `archivedBy`: low value (housekeeping, manager-only by gating), high cost (new schema surface). `CompletionLog`'s lastEditedAt/lastEditedBy (ADR 0004) are kept because log edits are a compliance-relevant mutability; duty renames aren't.

## Catalog editor UI (in-context, no new top-level chrome)

- **Tap duty row** is unchanged — toggles completion. The sacred primary gesture stays untouched; nothing in this feature may conflict with it.
- **Swipe-left on an active duty row** (manager-only; staff get no swipe actions) reveals:
  - **Edit** (blue) → opens `EditDutySheet`, same form as `AddDutySheet`, prefilled. `title` and `weekday` (weekly only) editable; `checklist` shown read-only (per *Edit semantics* above).
  - **Archive** (red) → `.alert` confirmation, then `archivedAt = .now`. Duty disappears from active list, appears in the Archived section below.
- **"Archived" disclosure section at the bottom of each `DutyListView`** — collapsed by default, header "Archived (N)". Tap to expand. Shows archived duties that originally belonged to *this* checklist.
- **Swipe-left on an archived row** reveals one action: **Restore** (green) → clears `archivedAt`, duty returns to active list at its original `order`.
- **No new top-level icon.** Catalog editing lives in-context where the duties do. The existing toolbar (gear → `StaffManagementView`, clock → `HistoryView`) stays as-is.
- **Staff see none of this** — no swipe actions, no Archived section. Consistent with ADR 0003's hide-don't-disable.
- **Drag-to-reorder is explicitly out of scope** for this feature. The `TaskItem.order` field exists but no reordering UI ships today; if a real reordering need surfaces, it's a follow-up.

## What changes in the existing model

- **`TaskItem`** — gains `archivedAt: Date?` (defaults to `nil`). Optional field, automatic migration under SwiftData. The existing `@Relationship(deleteRule: .cascade, inverse: \CompletionLog.duty)` on `logs` stays — it is now effectively unreachable via UI (duties are archived, never hard-deleted), but remains correct as a defensive invariant if a SwiftData cascade is ever triggered programmatically.
- **`Scheduling/DutyStatus.swift`** — `shouldSurface` gains an `archivedAt == nil` clause.
- **`Scheduling/FinishDayPolicy.swift`** — `incompleteClosingDuties` filters out `archivedAt != nil`.
- **`History/HistoryView.swift`** — `LogRow` gains an "Archived" badge when `duty?.archivedAt != nil`.
- **New file** (TBD name) — manager-only catalog editor: list duties per checklist with edit/archive actions, plus an "Archived" section/screen with restore. Shape to be grilled next.
- **Pure helper namespace** (TBD name, likely `DutyCatalog`) — caseless-enum mirror of `StaffManagement` / `PinHasher` / `LogRetention` / `BusinessDayHealth` / `FinishDayPolicy`. Permission helpers + state predicates, framework-free, unit-testable.

## Rejected alternatives

- **Hard-delete (current schema).** The `.cascade` rule on `TaskItem.logs` would silently destroy every `CompletionLog` ever recorded against the duty — irreversibly violating the spirit of ADR 0001's "history stays intact" promise. Rejected because audit trails are the app's core value; silent destruction is the worst-case action.
- **Hard-delete duty, `.nullify` logs (orphaned-log option).** Flipping the delete rule keeps logs but loses the duty title and context — orphaned logs become unreadable. The history viewer's "Other" section becomes a graveyard rather than a useful audit surface. Rejected because orphans lose meaning.
- **One-way archive (no restore).** Simpler model, but blocks the seasonal-duty workflow (a real restaurant pattern) and forces managers to recreate duties from scratch when business changes. Rejected because the cost of the restore affordance is small and the value is real.
- **`archivedBy: User?` audit field.** Rejected for low value (housekeeping action, manager-only by gating) and high cost (new `@Relationship` inverse on `User`, more schema surface). Revisit only if a real "who archived this" need surfaces.
- **Move-between-checklists as an edit.** Rejected — see *Edit semantics* above. Confusing forever after logs exist; archive-and-recreate covers the "I miscategorized it" case cleanly if caught early.
- **Title-edit audit fields (`lastEditedAt` / `lastEditedBy`) on `TaskItem`.** Rejected for parity with `archivedBy` reasoning. `CompletionLog`'s audit fields stay (ADR 0004) because log mutability is compliance-relevant; duty renames aren't.
- **New top-level "Manage Catalog" toolbar icon.** Rejected — catalog editing lives in-context where duties do. A third icon beside gear (staff) and clock (history) adds chrome without value at single-restaurant scale. Revisit if seasonal-restore-at-scale becomes a real workflow (managers browsing archives across all 6 checklists at once).
- **Footer-link "View archived duties →" navigating to a separate screen.** Rejected — at bounded single-restaurant catalog volume (tens of duties per checklist), an inline collapsed disclosure section is simpler and sufficient. Separate screen would be cleaner only if archived lists ever get long.
- **Drag-to-reorder in scope.** Rejected for this feature — no reordering UI exists today, and bundling it inflates scope. The `order` field is set at creation and unchanged by this feature.

## Open questions

None. All design decisions for the archive + edit + restore + catalog-editor scope are locked. Implementation may surface smaller decisions (file names, exact sheet layouts), which will be captured in commits, not in this ADR. Feature #4 (seed data) is recorded separately in ADR 0008.
