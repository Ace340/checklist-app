<!-- Context: development/frameworks/swiftdata/navigation | Priority: critical | Version: 1.0 | Updated: 2026-07-14 -->

# SwiftData Reference (Deep Dive)

**Purpose**: Authoritative SwiftData (iOS 17+) patterns, pitfalls & API reference — fetched from Apple docs + SwiftData Pro via Context7 (2026-07-14). This is the framework deep dive.

> **Cross-reference**: For this project's specific model wiring (the short version), see `project-intelligence/technical-domain.md`. The files here are the exhaustive reference with pitfalls & alternatives.

---

## Files in this folder

| File | Covers | When to read |
|------|--------|--------------|
| **[models-and-relationships.md](models-and-relationships.md)** | `@Model` macro, `final class`, init, `@Relationship`, 4 delete rules, inverse rules | Defining/editing a model or relationship |
| **[attributes-and-enums.md](attributes-and-enums.md)** | `@Attribute` options (`.unique`/`.externalStorage`/`.ephemeral`/`@Transient`), `Codable` enums, role pattern | Customizing property storage; using an enum value |
| **[container-setup.md](container-setup.md)** | `ModelContainer`, `Schema`, `ModelConfiguration`, `.modelContainer(for:)`, in-memory previews | App entry wiring; previews/tests |
| **[best-practices.md](best-practices.md)** | Pitfalls + the **concrete checklist-app models** (Checklist/TaskItem/CompletionLog/User) | Before adding models; debugging predicates/cascades |

---

## Quick mental model

```
@Model final class Foo {           ← macro expands to PersistentModel + Observable
    var stored: Type               ← must be `var`; optionals need default for CloudKit
    @Attribute(.unique) var id     ← local-only; NOT CloudKit-compatible
    @Relationship(deleteRule: .cascade, inverse: \Bar.foo)
    var bars: [Bar] = []           ← inverse on ONE side only (owner/to-many)
}
```

## See also
- **`project-intelligence/technical-domain.md`** — short SwiftData overview for THIS app's models
- Source files (until cleanup): `.tmp/external-context/swiftdata/01..06*.md`
- Official: https://developer.apple.com/documentation/swiftdata

## 📂 Codebase References
- **App entry**: `checklist-app/checklist_appApp.swift`
- **Models**: `checklist-app/Models/{Checklist,TaskItem,CompletionLog,User,Enums}.swift`
- **Root view**: `checklist-app/ContentView.swift`
