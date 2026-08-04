# 03 — Manager can browse and restore archived duties

**What to build:** Each `DutyListView` shows an "Archived (N)" disclosure section at the bottom, collapsed by default. Tap the header to expand. Swipe-left on an archived row reveals a **Restore** (green) action; confirming clears `archivedAt` and the duty returns to the active list at its original `order`. The section is hidden entirely when this checklist has zero archived duties.

This makes archive a two-way door (ADR 0007) and matches the seasonal-duty workflow — patio duties archived in winter, restored in spring — without forcing the manager to leave the checklist where the duty originally lived.

Restore collisions are tolerated: if two duties end up with the same `order` after restore (because a new duty was created in the meantime), SwiftData's stable sort handles the tie. No bespoke merge logic.

**Blocked by:** 01 (needs archive to exist before restore is meaningful).

**Status:** ready-for-agent

- [ ] "Archived (N)" disclosure section appears at the bottom of each `DutyListView` when at least one archived duty belongs to this checklist; section is hidden when N=0
- [ ] Section is collapsed by default; tapping the header expands it
- [ ] Swipe-left on an archived row reveals **Restore** (green) action for managers
- [ ] Staff do not see the Archived section (hide-don't-disable, ADR 0003)
- [ ] Restore clears `archivedAt`; the duty returns to the active list at its original `order` (preserved through archive, per ADR 0007)
- [ ] Restore collisions (two duties with the same `order` value after restore) are tolerated — stable sort handles the tie, no merge logic
- [ ] Pure helper owns restore permission/state predicates; unit tests pin the behavior
- [ ] Permission gates re-checked on appearance (defense-in-depth, mirroring `AddDutySheet` per ADR 0003)
