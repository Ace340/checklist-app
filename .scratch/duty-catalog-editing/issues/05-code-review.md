# 05 — Code review (ADR 0007 + 0008 work)

**What to build:** Run the `/code-review` skill against the work delivered in tickets 01–04. Standards axis reads `CONTEXT.md` + ADRs 0001–0008 + the Fowler smell baseline (mirrors prior review passes — commits `4094f62`, `cb23703`, `e0a0e96`). Spec axis reads ADRs 0007 + 0008. Address hard findings in code with follow-up commits; defer soft findings with explicit reasoning captured in a NEXT-STEPS handoff entry.

Per prior pattern, the two axes run in parallel as sub-agents.

**Blocked by:** 01, 02, 03, 04.

**Status:** ready-for-agent

- [ ] `/code-review` skill executed against the ticket 01–04 diff (range will be determined at execution time)
- [ ] Standards axis reads `CONTEXT.md` + ADRs 0001–0008 + the Fowler smell baseline
- [ ] Spec axis reads ADR 0007 (archive + edit + restore + catalog editor) and ADR 0008 (default seed data)
- [ ] Hard findings addressed in code with follow-up commits
- [ ] Deferred findings documented with reasoning in a `NEXT-STEPS.md` handoff entry
- [ ] All tests still pass at the end of the review pass
