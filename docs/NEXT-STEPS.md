# Next Steps — Resume Here

Handoff for the restaurant checklists feature. This doc is self-contained: read it, plus `CONTEXT.md` and `docs/adr/0001-derived-completion-state.md`, and you have everything needed to continue.

---

## Where we are

| Phase | Status |
|-------|--------|
| **Grilling / domain model** | ✅ Done — captured in `CONTEXT.md` (7 terms) + `docs/adr/0001-derived-completion-state.md` |
| **Phase 0 — pure scheduling logic** | ✅ Done — 18/18 tests green |
| **Phase 1 — SwiftData models** | ⛔ Blocked on toolchain (see below) |
| **Phase 2 — UI** | ⏳ After Phase 1 |
| **Phase 3 — code review + commit** | ⏳ Last |

All work is **uncommitted** on `main`. Decide whether to checkpoint-commit Phase 0 before continuing.

---

## ⛔ Unblock first — the toolchain gate

`xcode-select` points at Command Line Tools, so `xcodebuild` and simulators are unavailable. Phase 1 requires a live typecheck loop. Run:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify:
```sh
xcodebuild -version                                    # prints a version
xcrun simctl list devices available | grep -c iPhone   # nonzero
```

---

## What Phase 0 delivered (already done, verified)

`checklist-app/Scheduling/DutyStatus.swift` — pure, framework-free (no SwiftData/SwiftUI), auto-joins the target via Xcode 16 synced folders. Public seam:

- `Weekday` — Monday-first, `Comparable` (Int rawValue so SwiftData can store it)
- `DutyStatus` — `.pending | .done | .notYetDue | .due | .overdue`
- `weekday(of:calendar:)` — Monday-first weekday from a `Date`
- `weeklyDutyStatus(scheduled:now:completedThisWeek:calendar:)` — weekly boundary logic
- `dailyDutyStatus(completedInCurrentBusinessDay:)` — daily done/pending
- `shouldSurface(_:)` — hide only `.notYetDue`
- `mondayStartWeekInterval(containing:calendar:)` + `sameWeek(_:_:calendar:)` — week boundary for "done this week"

**Run the Phase 0 tests now** (no Xcode needed — uses `swiftc`):
```sh
swiftc checklist-app/Scheduling/DutyStatus.swift .tmp/tdd/Tests.swift -o /tmp/dutytest && /tmp/dutytest
```
Expect: `ALL PASSED` (18 checks).

Key behaviour pinned by tests: a weekly duty done **early** (before its weekday) correctly shows `.done` (completion outranks day-position).

---

## Phase 1 — SwiftData models  (requires toolchain unblocked)

> ⚠️ The model changes below break the **current `ContentView.swift`** (it reads `checklist.type` and `task.isCompleted`, both being removed). Either stub-update `ContentView` to compile at the end of Phase 1, or do Phase 1 + Phase 2 together. Recommended: do them together to avoid a broken intermediate commit.

**1. `checklist-app/Models/Enums.swift`**
- Delete `ChecklistType`.
- Add: `enum Area: String, Codable, CaseIterable { case foh, boh }`
- Add: `enum Cadence: String, Codable, CaseIterable { case daily, weekly }`
- Add: `enum Phase: String, Codable, CaseIterable { case opening, closing }`
- `Weekday` already exists in `DutyStatus.swift` — reuse it. Keep Int rawValue (SwiftData stores it; logic needs `Comparable`).

**2. `checklist-app/Models/Checklist.swift`**
- Replace `var type: ChecklistType` with three properties: `var area: Area`, `var cadence: Cadence`, `var phase: Phase?` (nil for weekly).
- Update `init`.

**3. `checklist-app/Models/TaskItem.swift`**
- **Delete** `var isCompleted: Bool` and `var completedAt: Date?` (see ADR #1 — state is now derived).
- **Add** `var weekday: Weekday?` (set only on weekly duties).
- Update `init` (drop the removed params).

**4. New `checklist-app/Models/BusinessDay.swift`**
```swift
@Model
final class BusinessDay {
    var openedAt: Date
    var closedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \CompletionLog.businessDay)
    var logs: [CompletionLog] = []
    var isOpen: Bool { closedAt == nil }
    init(openedAt: Date = .now) { self.openedAt = openedAt; self.closedAt = nil }
}
```

**5. `checklist-app/Models/CompletionLog.swift`**
- Add `var businessDay: BusinessDay?` (to-one inverse). Keep `timestamp`, `note`, `task`, `completedBy`.

**6. `checklist-app/checklist_appApp.swift`**
- Add `BusinessDay.self` to the `Schema([...])`.
- Seed an open `BusinessDay` on launch if none exists (the "current business day" = the one `BusinessDay` with `closedAt == nil`).

**7. XCTest target**
- Create a Unit Testing bundle target (in Xcode: File → New → Target → Unit Testing Bundle — adding a *target* needs GUI/pbxproj; synced folders only auto-include files, not targets).
- Port the 18 tests from `.tmp/tdd/Tests.swift` into XCTest `XCTestCase` methods.
- Run: `xcodebuild test -scheme checklist-app -destination 'platform=iOS Simulator,name=iPhone 16'` (adjust simulator name).

**No migration needed** — no shipped data exists. If a stale dev store errors on schema change, delete it on first run.

---

## Phase 2 — UI  (after Phase 1 typechecks)

Rebuild `ContentView.swift` to the 3-level navigation agreed in grilling:

1. **Home**: two cards — **FOH**, **BOH** (the `Area`s).
2. **Tap an area**: cards **Opening**, **Closing**, **Weekly** (filtered by `cadence`/`phase`).
3. **Tap a card**: the duties, each showing **derived** state via the `DutyStatus` seam.

**Derived state** (never stored — ADR #1):
- Current business day = the `BusinessDay` with `closedAt == nil` (seed if none).
- Daily duty done ↔ a `CompletionLog` exists for it whose `businessDay == currentBusinessDay`.
- Weekly duty done ↔ a `CompletionLog` exists for it with `timestamp` inside `mondayStartWeekInterval(containing: now)`.
- Status via `dailyDutyStatus(...)` / `weeklyDutyStatus(...)`; show only duties where `shouldSurface(status)` is true.

**"Finish day" button** (manager-only — gate on `user.role == .manager`):
- Sets `currentBusinessDay.closedAt = .now`.
- Creates a new open `BusinessDay`.
- Daily duties reset automatically (new business day has no logs → derived state reads undone).

---

## Phase 3 — finish

- Run the **`/code-review`** skill against `CONTEXT.md` + `docs/adr/0001-derived-completion-state.md`.
- Run full `xcodebuild test`.
- Commit to `main`.

---

## Open edge cases (not blocking — decide during implementation)

- **Forgotten finish-day**: if nobody hits "Finish day", the next morning's logs attach to yesterday's still-open business day. Mitigation options: warn on launch if the open business day is >24h old; auto-prompt manager.
- **Finish-day with incomplete duties**: allowed (just closes the day) or blocked until all closing duties done? Decide.
- **Un-done Sunday weekly duty**: clears Monday (week rollover) — already handled correctly by the tested logic.

---

## Quick domain refresher (full detail in `CONTEXT.md` + ADR #1)

- **6 checklists** = Area `{FOH,BOH}` × Cadence `{daily,weekly}` × (Phase `{opening,closing}` for daily only).
- **Weekly duties** are bound to a `Weekday`; surface from that day onward; haunt as `.overdue` until done; clear at Monday rollover.
- **The tick is derived, not stored** — `isCompleted`/`completedAt` are gone. "Done" = a completion log exists in the current business day (daily) or Monday-start week (weekly).
- **Business day** ends on an explicit manager "Finish day" action (closings happen 11pm–2am, not midnight). A log at 1:30am Sunday belongs to Saturday's business day → `CompletionLog` must carry a `businessDay` reference, not just a timestamp.
