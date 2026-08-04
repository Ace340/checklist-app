# 04 — Default duty seed data on first launch

**What to build:** On first launch (after the onboarding wizard from ADR 0003), each of the 6 checklists is populated with a curated set of default restaurant duties loaded from a bundled `defaults.json`. After seeding, the duties are plain duties — the manager can edit, archive, and restore them like any user-created duty. A manager who archives every default duty keeps them archived; there is no aggressive reseeding on next launch.

The seed predicate is load-bearing: it fires when any checklist has zero duties, where "zero duties" counts *all* duties (active AND archived). An all-archived checklist must NOT reseed — that would silently overwrite the manager's choice. First-launch detection remains store-derived (no `UserDefaults` flag), consistent with ADR 0003.

The seed-data *content* (which ~40 duties ship in `defaults.json`) is informed by the research sub-task — `docs/research/default-duty-sets.md` — which gathers public real-restaurant-ops checklist examples. This ticket does not start until that research lands, because the JSON content is the deliverable.

**Blocked by:** 03 (the full archive/restore loop must be in place before defaults land — otherwise managers have default duties they cannot remove), and the research sub-task producing `defaults.json` content.

**Status:** ready-for-agent

- [ ] `defaults.json` is bundled in the app and decodes via `Codable` structs into a slot → duty-list map keyed by `(area, cadence, phase?)` — daily slots nest opening/closing; weekly slots nest by weekday
- [ ] A pure helper namespace owns the seed predicate: fires when any checklist has zero duties, where "zero duties" counts all duties (active AND archived) — so an all-archived checklist does NOT reseed
- [ ] Existing first-launch seed (the 6 empty checklists) gains a follow-up step that loads defaults into each empty checklist
- [ ] First-launch detection remains store-derived (no `UserDefaults` flag), consistent with ADR 0003
- [ ] Loading is fail-fast: a malformed `defaults.json` is a launch-time bug, not graceful degradation
- [ ] Unit tests pin the seed predicate (empty-checklist seeds; partially-populated does not seed; all-archived does not reseed)
- [ ] Unit tests pin the JSON decoding shape
- [ ] Default duty content reflects the research sub-task's real-restaurant-ops sources
