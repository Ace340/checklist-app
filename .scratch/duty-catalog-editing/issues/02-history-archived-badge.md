# 02 — Archived duties visible in history with "Archived" badge

**What to build:** In the business-day history viewer (ADR 0004), logs belonging to archived duties display a subtle "Archived" badge. A manager scanning past business days needs to understand *why* a duty absent from the active catalog appears in the log — without the badge, an archived duty's past completions look like ghosts. The badge is the visual bridge between "I removed this from the catalog" and "I'm still seeing it in history."

Small UI change on a distinct surface (`HistoryView`), kept as its own ticket for a distinct demoable behavior: archive a duty (ticket 01), then view past business days, then see the badge.

**Blocked by:** 01 (needs `archivedAt` field to exist).

**Status:** ready-for-agent

- [ ] `LogRow` in the history viewer shows an "Archived" badge when `duty?.archivedAt != nil`
- [ ] Badge styling is subtle — does not dominate the row, consistent with existing row affordances (e.g. the existing "edited" pencil badge from ADR 0004)
- [ ] Non-archived duties show no badge
- [ ] Logs whose `duty == nil` (truly orphaned, not archived) are unaffected — they continue to surface in the existing "Other" section per ADR 0004
