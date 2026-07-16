<!-- Context: development/frameworks/swiftdata/attributes-and-enums | Priority: high | Version: 1.0 | Updated: 2026-07-14 -->

# @Attribute Options & Codable Enums

**Scope**: `@Attribute` options (`.unique` / `.externalStorage` / `.ephemeral`), `@Transient`, persisting enums, role pattern.

---

## @Attribute — `Schema.Attribute.Option`

### `.unique` — value is unique across all models of that type (iOS 17+)
```swift
@Attribute(.unique) var name: String
@Attribute(.unique) var sourceURL: URL
```
> ⚠️ **NOT supported with CloudKit sync.** Don't use `.unique` (or `#Unique`) if you may adopt CloudKit. Local-only.

### `.externalStorage` — large binary stored adjacent to the model
```swift
@Attribute(.externalStorage) var avatarData: Data
```

### `.ephemeral` — change-tracked in memory, NOT persisted
```swift
@Attribute(.ephemeral) var draftProgress: Double
```

### `@Transient` macro — exclude from persistence AND tracking (pure runtime state)
```swift
@Transient var isFavorite: Bool = false
```

| Need | Use |
|---|---|
| Don't persist, but observe changes | `@Attribute(.ephemeral)` |
| Don't persist, don't track | `@Transient` |

### Full option list
`allowsCloudEncryption`, `externalStorage`, `preserveValueOnDeletion`, `spotlight`, `unique`, `transformable(by:)`, `ephemeral`, `codable`.
> `.codable` is iOS 27+ Beta. On iOS 17–26, store a `Codable` enum/struct directly.

---

## Enums in SwiftData

Enums **must conform to `Codable`** to be persisted.

### String-backed enum (recommended — stable raw values)
```swift
enum Diet: String, CaseIterable, Codable {
    case herbivorous = "Herbivore"
    case carnivorous = "Carnivore"
    case omnivorous = "Omnivore"
}

@Model final class Animal {
    var name: String
    var diet: Diet                    // ✅ Codable enum stored directly
}
```

### Associated values are supported
```swift
enum ArticleStatus: Codable {
    case draft
    case published(Date)              // ✅ associated values persist fine
    case archived(reason: String)
}
```

### Enum vs relationship — when to choose which
| Fixed, small value set (roles, types, status) | Dynamic, user-created data |
|---|---|
| → `Codable` enum | → `@Model` relationship |

---

## Pattern: role-based access via Codable enum

For staff vs manager (fixed role set), model as an enum — **not** a separate model:

```swift
enum UserRole: String, Codable, CaseIterable {
    case staff
    case manager
}

@Model final class User {
    var name: String
    var role: UserRole                 // ✅ persisted enum
    init(name: String, role: UserRole = .staff) {
        self.name = name; self.role = role
    }
}
```
Enforce permissions in app logic:
```swift
if user.role == .manager { /* show admin actions */ }
```
> ⚠️ SwiftData enforces **no row-level security**. Access control is your app's responsibility. For per-record ownership add `owner: User?` with `deleteRule: .nullify`.

## Sources
- https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:)
- https://developer.apple.com/documentation/swiftdata/schema/attribute/option/unique
- https://developer.apple.com/documentation/swiftdata/schema/attribute/option/ephemeral
- https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes

## 📂 Codebase References
- **`Codable` enums**: `checklist-app/Models/Enums.swift` — `ChecklistType` (`.opening`/`.closing`/`.weekly`), `UserRole` (`.staff`/`.manager`)
- **Enum-typed properties**: `Checklist.type`, `User.role` in `checklist-app/Models/{Checklist,User}.swift`
- See `project-intelligence/technical-domain.md` for the project's role-gating conventions.
