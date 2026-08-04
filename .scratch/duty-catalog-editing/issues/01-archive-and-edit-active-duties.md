# 01 — Manager can archive or edit active duties

**What to build:** A manager swipes left on any active duty row to reveal two actions: **Edit** (blue) opens a sheet pre-filled with the duty's title and weekday (for weekly duties); **Archive** (red) asks for confirmation, then hides the duty from the active list. Renames propagate retroactively through history (logs reference the duty, not a title snapshot). Archived closing duties no longer block finish-day warn — a retired closing duty must not gate finish-day. Staff see no swipe actions at all (hide-don't-disable, ADR 0003).

The `TaskItem` model gains an `archivedAt: Date?` field (the single source of truth for archive state). A new pure-helper namespace — caseless enum, framework-free, mirroring `StaffManagement` / `LogRetention` / `BusinessDayHealth` / `FinishDayPolicy` — owns the permission and state predicates. Surfacing logic (`DutyStatus.shouldSurface`) hides archived duties from active lists.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `TaskItem.archivedAt: Date?` added (defaults to `nil`); schema migration is automatic under SwiftData; in-memory test stores continue to work
- [ ] Pure helper namespace owns archive/edit permission + state predicates, framework-free, unit-tested (mirror the existing helper pattern)
- [ ] `DutyStatus.shouldSurface` hides duties where `archivedAt != nil`
- [ ] `FinishDayPolicy.incompleteClosingDuties` excludes archived closing duties
- [ ] Swipe-left on an active duty row reveals **Edit** (blue) + **Archive** (red) actions for managers only
- [ ] Staff see no swipe actions on duty rows
- [ ] Edit opens a sheet pre-filled with title (and weekday for weekly duties); `checklist` shown read-only (move-between-checklists is not editable, per ADR 0007)
- [ ] Saving the edit sheet mutates the duty; rename is immediately visible in past history logs (logs reference the duty, not a title snapshot)
- [ ] Archive shows a `.alert` confirmation; confirming sets `archivedAt` to current date and the duty disappears from the active list
- [ ] Permission gates re-checked on appearance (defense-in-depth, mirroring `AddDutySheet` per ADR 0003)
- [ ] ADR 0007 *Edit semantics* decisions enforced: title/order/weekday editable; checklist not editable; no title-edit audit fields
- [ ] All existing tests still pass; new tests pin the helper, surfacing, and finish-day-policy behavior
