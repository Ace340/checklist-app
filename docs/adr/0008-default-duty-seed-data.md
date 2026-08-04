# Default duty seed data on first launch

**Status:** Accepted (locked during a `/grill-with-docs` session, 2026-08-04). Implementation pending.

The app ships with a default set of restaurant duties so the first user doesn't have to enter ~40 items by hand. We seed once, at first launch, into the 6 checklists created by `seedOnLaunch`. After seeding, the duties are just duties — there is no `Template` entity, no template-library UI, no special status. The manager can edit, archive, and restore them like any user-created duty (per ADR 0007).

This ADR closes Feature #4 from `docs/ROADMAP.md` and pairs with ADR 0007 (archive + catalog editing), which lands the manager-facing affordances the seeded duties will be managed with.

## Decisions

- **Seed data, not a reusable template library.** A one-time population of the 6 checklists at first launch. No `Template` model entity, no template-library browsing UI, no apply-template action. The ROADMAP motivation is first-run UX ("so the first user doesn't enter ~40 items by hand"); that is solved entirely by seed-once. If a reusable-template need surfaces later, it composes cleanly on top of seed data without revisiting this ADR.
- **Detection: store-derived, no `UserDefaults` flag.** Seed fires when any checklist has zero duties. Consistent with ADR 0003's first-launch detection pattern (a store-derived check is self-correcting against a defaults wipe). A manager who archives every default duty keeps them archived — there is no aggressive reseed.
- **Seed predicate counts all duties, not just active ones.** `checklist.tasks.isEmpty`, not `checklist.tasks.filter { $0.archivedAt == nil }.isEmpty`. A checklist where the manager has archived every duty still has duties (just archived ones), so seed does *not* refire. Without this, a fully-archived checklist would silently reseed defaults on next launch — overwriting the manager's choice.
- **No "reset to defaults" feature.** Anti-feature — silently overwrites customizations. Out of scope. Managers who want a fresh start archive their customizations; in extreme cases, delete and reinstall.
- **Single "generic restaurant" set.** Not restaurant-type variation (cafe vs quick-service vs full-service). Variation is real but inflates scope; the manager can edit, archive, and add to fit their context after seeding. Defer multi-set variation to a real request from a specific deployment.
- **Where the seed data lives: bundled JSON in the app bundle.** Easier to review and diff in PRs than Swift constants; type-checked at load time via `Codable`. Loading is fail-fast — a malformed `defaults.json` is a build-time / launch-time bug, not a runtime graceful-degradation case.
- **One file, `defaults.json`, keyed by `(area, cadence, phase?)`.** Daily slots nest `opening` / `closing`; weekly slots nest by `weekday`. One file is easier to keep consistent than six per-checklist files. The actual JSON shape is an implementation detail; the decision is "one file, Codable-typed, read once at first launch."

## What changes in the existing model

- **No schema change.** Seeded duties are plain `TaskItem` rows in plain `Checklist`s — the model already supports everything we need. This is purely a data + loading-feature change.
- **`checklist_appApp.swift` (`seedOnLaunch`)** — extended to load `defaults.json` once and insert duties into each empty checklist. Gated by the "any empty checklist" predicate above. Runs after the existing 6-checklist seeding.
- **New file (TBD path)** — `Codable` structs decoding `defaults.json` into `[DefaultSlot: [DefaultDuty]]` or similar. Pure data; no behavior.
- **New file (TBD path)** — pure helper (caseless-enum namespace, mirrors `LogRetention` / `BusinessDayHealth` / `FinishDayPolicy`) that owns the "should we seed?" predicate and the "which slots need seeding?" logic. Framework-free, unit-testable. The predicate is the load-bearing piece — it must be `tasks.isEmpty`, not `tasks.filter { isActive }.isEmpty`.

## Rejected alternatives

- **Reusable template library (`Template` entity, browse/import UI).** Rejected — the ROADMAP motivation is first-run UX, solved by seed-once. The library adds significant model/UI surface for a hypothetical workflow with no documented use case. Composes cleanly later if needed.
- **`UserDefaults` first-launch flag.** Rejected — a defaults wipe with the store intact would either miss the seed (stranding the user with empty checklists) or worse, reseed aggressively. Store-derived detection is self-correcting. Consistent with ADR 0003's pattern.
- **"Reset to defaults" feature.** Rejected as anti-feature — silently destroys customizations. The cost of doing nothing (managers who want a fresh start must archive manually or reinstall) is bounded; the cost of getting reset wrong (silent data loss) is unbounded.
- **Multi-set variation by restaurant type.** Rejected for scope — variation is real but requires curating N default sets, a restaurant-type picker at onboarding, and ongoing maintenance. Defer to a real request from a specific deployment.
- **Swift constants instead of bundled JSON.** Rejected — JSON diffs cleanly in PRs and reads as data rather than code. Swift constants would compile-check the structure but lose review readability at the ~40-item scale.
- **Six per-checklist files.** Rejected — six files are harder to keep consistent than one. The slot tuple `(area, cadence, phase?)` is small enough to fit in one dictionary.

## Open questions

None at the design level. The actual default-duty *content* (which ~40 duties ship in `defaults.json`) needs real-restaurant input per the ROADMAP, and will be iterated on in PRs rather than locked in this ADR.
