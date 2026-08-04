# Restaurant Checklists

A restaurant operations app where staff complete recurring duty checklists, grouped by where the work happens and how often it recurs.

## Language

**FOH (Front of House)**:
The guest-facing areas of the restaurant — dining room, counter, restrooms, host stand.
_Avoid_: front, dining room, floor

**BOH (Back of House)**:
The kitchen and support areas — prep stations, dish pit, walk-in, storage, offices.
_Avoid_: back, kitchen

**Area**:
Which side of the restaurant a checklist belongs to — FOH or BOH. The primary grouping on the home screen.
_Avoid_: section, zone, department

**Phase**:
The stage of the service day a daily checklist covers — Opening or Closing.
_Avoid_: stage (in restaurants a *stage* is an unpaid kitchen intern — confusing), shift, period

**Cadence**:
How often a duty recurs. A **daily** duty runs every day in either the Opening or Closing phase. A **weekly** duty is bound to a specific day of the week (e.g. "sharpen knives" on Wednesday) and surfaces only on that day.
_Avoid_: frequency, schedule

**Business Day**:
The operating period from one close-out to the next. Because closings land anywhere from 11pm to 2am depending on traffic, a business day is ended by an explicit "finish day" action (not midnight) — which also resets the daily checklists. Completions belong to the business day they happened in, so a log written at 1:30am Sunday is still *Saturday's*.
_Avoid_: day (ambiguous with calendar day), shift, service

**Duty**:
A single actionable item on a checklist (e.g. "Turn on dining room lights"). Modeled in code as `TaskItem`.
_Avoid_: task (collides with Swift's concurrency `Task`), item, chore

**Catalog**:
The set of all active duties a restaurant expects staff to perform, across all 6 checklists. Archived duties are not part of the catalog. Managers edit the catalog via archive, restore, and edit actions (ADR 0007).
_Avoid_: directory, inventory, roster

**Archived Duty**:
A duty removed from the active catalog by a manager but preserved with its full completion history. Archived duties do not surface on any active checklist; their past `CompletionLog`s remain visible in the business-day history. The action is reversible — a manager can **restore** an archived duty back to its original checklist, with all historical logs intact.
_Avoid_: retired, deleted, hidden, removed, inactive
