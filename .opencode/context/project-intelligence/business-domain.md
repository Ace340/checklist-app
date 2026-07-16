<!-- Context: project-intelligence/business | Priority: critical | Version: 2.0 | Updated: 2026-07-14 -->

# Business Domain

**Purpose**: Why this iOS app exists — the restaurant operations problem it solves.
**Last Updated**: 2026-07-14

## Quick Reference
- **Update Triggers**: New user role | new checklist type | business-model change | expansion beyond restaurants
- **Audience**: Developers, product, AI agents needing domain context

## Project Identity
```
Name:            checklist-app
Tagline:         Digital checklists for restaurant operations
Problem:         Paper/whiteboard checklists are lost, skipped, and unverifiable
Solution:        On-device iOS app with role-based, ordered, auditable checklists
Stage:           Early (MVP models + list UI; no auth/network/analytics yet)
```

## Target Users
| Segment | Who | What They Need | Pain Point |
|---------|-----|----------------|------------|
| **Staff** (primary) | Front-line restaurant workers | Clear, ordered opening/closing/weekly tasks; quick check-off | Paper checklists get lost/smudged; no accountability |
| **Manager** (primary) | Shift supervisors / owners | Verification that tasks were completed; audit history | Can't prove compliance; no completion records |
| **Owner** (secondary) | Multi-location operator (future) | Cross-location consistency | Inconsistent procedures across shifts/locations |

## Value Proposition
**For Staff**:
- Always-available task list on their phone (no hunting for the clipboard)
- Clear ordering — knows exactly what to do next
- One-tap completion logging

**For Managers / Business**:
- Auditable completion history (`CompletionLog`) — proof tasks were done
- Standardized procedures across shifts (opening/closing/weekly templates)
- Role-based access — staff execute, managers oversee
- Replaces paper waste and verbal handoffs

## Domain Model (how the business maps to data)
```
Checklist (opening | closing | weekly)
   └── owns → TaskItem (ordered: 1, 2, 3...)
                 └── logs → CompletionLog (history per completion)

User (staff | manager) — role gates features (enforced in app logic)
```
- **Checklist** = a named procedure (e.g. "Morning Opening"). `type` drives scheduling.
- **TaskItem** = one step. `order` enforces sequence. Named `TaskItem` (not `Task`) to avoid Swift stdlib clash.
- **CompletionLog** = immutable evidence a task was done (timestamped).
- **UserRole** = `.staff` (execute) vs `.manager` (oversee/configure).

## Success Metrics
| Metric | Definition | Target | Current |
|--------|-----------|--------|---------|
| Checklist adoption | % shifts using app vs paper | 100% | 0% (pre-launch) |
| Completion rate | % tasks checked off per checklist | >95% | unmeasured |
| Audit availability | % checklists w/ completable history | 100% | ✅ (model supports) |

## Business Constraints
- **Single-device / offline-first** — no backend; all data on-device via SwiftData. Constraint: no cross-device sync yet (future: iCloud/CloudKit).
- **iOS-only** — restaurant staff use provisioned iPhones/iPads. Android not in scope.
- **No authentication yet** — role is a model field, not a login. Constraint: trust-based until auth added.
- **Restaurant schedule** — three checklist types (`opening`, `closing`, `weekly`) mirror the industry's standard shift rhythm.

## Roadmap Context
- **Current focus**: Core models + list/detail UI (done as of 2026-07-14)
- **Next milestone**: Task creation/editing UI; completion logging flow
- **Long-term vision**: Manager dashboard, multi-device sync (CloudKit), analytics, multi-location

## Key Stakeholders
| Role | Responsibility |
|------|----------------|
| Product/Owner | Defines checklist templates and procedures |
| iOS Developer (Ace) | Builds app, owns SwiftData models |
| End users (Staff/Managers) | Execute and verify checklists |

## 📂 Codebase References
- **Domain models**: `checklist-app/Models/{Checklist,TaskItem,CompletionLog,User,Enums}.swift`
- **Role enum** (`staff`/`manager`): `checklist-app/Models/Enums.swift`
- **Checklist types** (`opening`/`closing`/`weekly`): `checklist-app/Models/Enums.swift`
- **Root UI**: `checklist-app/ContentView.swift`

## Related Files
- `technical-domain.md` ✅ — How this is built (SwiftUI + SwiftData, iOS 17+)
- `business-tech-bridge.md` — Business need → technical solution mapping *(template — fill next)*
- `decisions-log.md` — Why SwiftData, why iOS-only, etc.
- `development/frameworks/swiftdata/` — Deep-dive SwiftData reference (harvested)
