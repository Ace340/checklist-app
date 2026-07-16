<!-- Context: development/frameworks/swiftdata/best-practices | Priority: high | Version: 1.0 | Updated: 2026-07-14 -->

# Best Practices, Pitfalls & This App's Models

**Scope**: Common pitfalls (relationships, predicates, CloudKit, `@Query`) + the **concrete model set** for this restaurant checklist app.
> Cross-ref: short version in `project-intelligence/technical-domain.md`; relationship mechanics in `models-and-relationships.md`.

---

## ⚠️ Predicate gotchas (runtime crashes!)

```swift
// ✅ string search
@Query(filter: #Predicate<Movie> { $0.name.localizedStandardContains("titanic") })

// ✅ safe isEmpty — use `!`, NEVER `== false`
@Query(filter: #Predicate<Movie> { !$0.cast.isEmpty })

// ❌ CRASH: $0.cast.isEmpty == false
// ❌ CRASH: regex in predicate — $0.name.contains(/Titanic/)
// ❌ won't compile/crash: computed props, @Transient, hasSuffix, lowercased,
//    map, reduce, count(where:), first inside #Predicate

// ✅ use starts(with:) instead of hasPrefix()
#Predicate<Website> { $0.type.starts(with: "https://apple.com") }
```

## @Query vs FetchDescriptor
```swift
// ❌ NEVER use @Query outside a SwiftUI view
// ✅ FetchDescriptor + ModelContext elsewhere
let descriptor = FetchDescriptor<Destination>()
let count = try context.fetchCount(descriptor)

// ✅ optimize: prefetch relationships + limit fetched properties
var d = FetchDescriptor<Destination>()
d.relationshipKeyPathsForPrefetching = [\.sights]
d.propertiesToFetch = [\.name]
return try context.fetch(d)
```

## Saving & cross-actor identifiers
```swift
context.insert(obj)
try context.save()                      // ✅ just save(); don't gate on hasChanges
let id = obj.persistentModelID          // ✅ stable only AFTER first save
// PersistentIdentifier is the ONLY value safe across actors/contexts
```

## CloudKit sync constraints
If you (ever) use CloudKit-backed SwiftData:
- ❌ No `@Attribute(.unique)`, no `#Unique<...>`
- ✅ ALL props & relationships **optional or have default values**
- ✅ Code must tolerate not-yet-synced data

> Tip: even local-only apps should prefer optional/defaulted props so a future CloudKit migration is painless.

## Relationships (recap — see `models-and-relationships.md`)
- ✅ Explicit `deleteRule` on **every** relationship.
- ✅ `@Relationship` + `inverse` on **ONE side only** (the to-many owner).
- ⚠️ `.cascade` is recursive & destructive; use only when child lifetime == parent's.
- ⚠️ `.noAction` → dangling references; prefer `.nullify`.

---

## This app's concrete models

> **Naming note**: this project uses `TaskItem` (NOT `Task`) to avoid shadowing Swift's stdlib `Task`. The fetched reference docs use `Task` as a generic example.

```swift
enum ChecklistType: String, Codable, CaseIterable { case opening, closing, weekly }
enum UserRole:     String, Codable, CaseIterable { case staff, manager }

@Model final class User {
    var name: String
    var role: UserRole                                        // ✅ Codable enum
    @Relationship(deleteRule: .nullify, inverse: \CompletionLog.completedBy)
    var logs: [CompletionLog] = []
    init(name: String, role: UserRole = .staff) { self.name = name; self.role = role }
}

@Model final class Checklist {
    var title: String
    var type: ChecklistType                                   // ✅ Codable enum
    var createdAt: Date; var updatedAt: Date                  // ✅ Date first-class
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.checklist)
    var tasks: [TaskItem] = []                                // ✅ owns the cascade
    init(title: String, type: ChecklistType) {
        self.title = title; self.type = type
        self.createdAt = Date(); self.updatedAt = Date()
    }
}

@Model final class TaskItem {
    var title: String; var order: Int; var isCompleted: Bool
    var checklist: Checklist?                                 // plain optional inverse
    @Relationship(deleteRule: .cascade, inverse: \CompletionLog.task)
    var logs: [CompletionLog] = []
    init(title: String, order: Int, isCompleted: Bool = false) {
        self.title = title; self.order = order; self.isCompleted = isCompleted
    }
}

@Model final class CompletionLog {
    var timestamp: Date; var note: String?                    // optional = absence meaningful
    var task: TaskItem?                                        // plain optional inverses
    var completedBy: User?
    init(timestamp: Date = .now, note: String? = nil) { self.timestamp = timestamp; self.note = note }
}
```

### Relationship map
| Owner side | Property | deleteRule | inverse | Effect |
|---|---|---|---|---|
| `Checklist` | `tasks` | `.cascade` | `\TaskItem.checklist` | Delete checklist → delete its tasks |
| `TaskItem` | `logs` | `.cascade` | `\CompletionLog.task` | Delete task → delete its logs |
| `User` | `logs` | `.nullify` | `\CompletionLog.completedBy` | Delete user → keep logs, clear `completedBy` |

### Querying & role gating
```swift
@Query(sort: \Checklist.title) private var checklists: [Checklist]
@Query(filter: #Predicate<Checklist> { $0.type == .opening }) private var opening: [Checklist]

func canEdit(_ user: User) -> Bool { user.role == .manager }  // app-layer enforcement only
```

---

## Model design checklist
- ✅ `@Model final class` + explicit `init`
- ✅ `var` properties only
- ✅ Explicit `deleteRule` + single-side `inverse`
- ✅ `Date` first-class; `UUID` only with `@Attribute(.unique)` (local-only)
- ✅ Enums → `Codable` (string raw value recommended)
- ✅ Optional/defaulted props for CloudKit-friendliness
- ✅ `@Query` in views only; `FetchDescriptor` elsewhere
- ✅ Just call `save()`; pass `persistentModelID` across actors
- ✅ `ContentUnavailableView` for empty states; never rely on insertion order

## Sources
- https://github.com/twostraws/swiftdata-agent-skill (SwiftData Pro)
- https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches
- https://developer.apple.com/documentation/swiftdata/deleting-persistent-data-from-your-app

## 📂 Codebase References
- **Models (canonical source of truth)**: `checklist-app/Models/{Checklist,TaskItem,CompletionLog,User,Enums}.swift`
- **Container + Schema wiring**: `checklist-app/checklist_appApp.swift`
- **`@Query` + `modelContext` usage, empty state**: `checklist-app/ContentView.swift`
- If these docs ever drift from the models, the `.swift` files win — update this doc.
