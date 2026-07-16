<!-- Context: development/frameworks/swiftdata/models-and-relationships | Priority: high | Version: 1.0 | Updated: 2026-07-14 -->

# @Model Classes & Relationships

**Scope**: `@Model` macro, `final class`, init patterns, `@Relationship`, the 4 delete rules, inverse rules.
> Cross-ref: project-specific wiring lives in `project-intelligence/technical-domain.md`.

---

## @Model macro

Annotate a Swift **class** — the macro adds `PersistentModel` + `Observable` conformance. iOS 17+.

```swift
@Model
final class Trip {
    var name: String
    var destination: String
    var startDate: Date
    var accommodation: Accommodation?   // optional = may be absent
}
```

### Model design rules (high signal)
| Concern | Rule |
|---|---|
| **Type** | `class` required (struct/enum can't). `final class` is idiomatic & safe. |
| **Properties** | Stored props must be `var` (mutable). |
| **Init** | Provide explicit `init`. Give collections a default (`= []`). |
| **Optionals** | Use `Type?` where absence is meaningful. **CloudKit → ALL props optional or defaulted.** |
| **Dates** | Use `Date` directly — first-class persisted type. |
| **IDs** | SwiftData auto-provides `persistentModelID`. Add a `UUID` only with `@Attribute(.unique)` (local-only). |

### Stable identifier across actors/contexts
```swift
context.insert(obj)
try context.save()                      // save BEFORE reading the ID
let id = obj.persistentModelID          // stable only after first save
let fetched = otherContext.model(for: id) as? Foo   // re-fetch elsewhere
```
> `PersistentIdentifier` is the **only** value safe to send across actors/contexts — and only after a save.

---

## @Relationship macro

```swift
@Relationship(
    deleteRule: .nullify,               // DEFAULT
    inverse: \Other.prop,               // key path of the inverse (almost always set explicitly)
    minimumModelCount: Int? = 0,
    maximumModelCount: Int? = 0
)
```

### To-many with cascade + inverse
```swift
@Model final class AnimalCategory {
    @Attribute(.unique) var name: String
    @Relationship(deleteRule: .cascade, inverse: \Animal.category)
    var animals = [Animal]()
}

@Model final class Animal {
    var name: String
    var category: AnimalCategory?       // inverse side: plain optional, NO @Relationship
}
```
### To-one
```swift
@Relationship(.cascade) var accommodation: Accommodation?
```

---

## The 4 delete rules — `Schema.Relationship.DeleteRule`

| Rule | Behavior | Use when |
|---|---|---|
| **`.cascade`** | Deletes all related models when parent is deleted (**recursive & destructive**). | Child's life is bounded by parent's (e.g. `Task` belongs to a `Checklist`). |
| **`.nullify`** *(default)* | Sets the child's reference to `nil`; child survives. | Child should live on, just detach. |
| **`.deny`** | **Blocks** parent deletion while references exist. | Force caller to clean up first (strong integrity). |
| **`.noAction`** | Does nothing. ⚠️ Leaves dangling references → almost always a bug. | Only if you manually clean up. Prefer `.nullify`. |

> Default is `.nullify` — but **always write the rule explicitly** to avoid silent orphaning.

---

## Inverse rules (critical pitfalls)

1. **Apply `@Relationship` to ONE side only** — put `inverse:` on the owner (usually to-many). The other side is a plain optional/array. Annotating both sides → circular management.
2. **Always define the inverse explicitly.** SwiftData can misinterpret inferred inverses.
3. **Reciprocal two-way navigation is fine** if inverse is declared on one side; SwiftData keeps both sides consistent.
4. **`.cascade` is recursive** — a parent's deletion cascades to children, grandchildren, etc. Use only when lifetime is truly shared.
5. **`.noAction`** almost always a bug — leaves references to non-existent models.

```swift
// ❌ easy to forget, implicit nullify
var sights: [Sight]
// ✅ explicit rule + inverse on the owner side
@Relationship(deleteRule: .cascade, inverse: \Sight.destination) var sights: [Sight]
```

## Sources
- https://developer.apple.com/documentation/swiftdata/model()
- https://developer.apple.com/documentation/swiftdata/relationship(_:deleterule:minimummodelcount:maximummodelcount:originalname:inverse:hashmodifier:)
- https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/
- https://github.com/twostraws/swiftdata-agent-skill

## 📂 Codebase References
- **Models using `@Model final class`**: `checklist-app/Models/Checklist.swift`, `TaskItem.swift`, `CompletionLog.swift`, `User.swift`
- **`.cascade` owner-side examples**: `Checklist.tasks → TaskItem`, `TaskItem.logs → CompletionLog`
- **`.nullify` example**: `User.logs → CompletionLog.completedBy`
- See `best-practices.md` for the full relationship map of this app.
