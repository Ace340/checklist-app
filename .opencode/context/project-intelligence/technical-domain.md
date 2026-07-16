<!-- Context: project-intelligence/technical | Priority: critical | Version: 2.0 | Updated: 2026-07-14 -->

# Technical Domain

**Purpose**: Tech stack, architecture & SwiftData/SwiftUI patterns for this iOS app.
**Last Updated**: 2026-07-14

## Quick Reference
- **Update Triggers**: iOS version bump | new SwiftData models | new SwiftUI screens | architecture change
- **Audience**: iOS developers, AI agents generating Swift code

## Primary Stack
| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Language | Swift | 5.x | Apple's modern, type-safe language |
| UI Framework | SwiftUI | iOS 17+ | Declarative UI; required for SwiftData bindings |
| Persistence | SwiftData | iOS 17+ | Apple-native, macro-driven ORM; replaces Core Data |
| Build | Xcode + SPM | 15+ | Single-target app, Swift Package Manager |
| Testing | XCTest | built-in | Standard iOS unit/UI testing |

## Architecture Pattern
```
Type:     Native iOS single-target app
Pattern:  SwiftUI declarative UI + SwiftData local persistence (offline-first)
DI:       Environment-based (@Environment(\.modelContext), .modelContainer(_:))
Sync:     None yet (isStoredInMemoryOnly: false → on-device SQLite)
```

**Why**: Small restaurant checklist tool, single-user-per-device, no backend needs.
SwiftData gives macro-based persistence with minimal boilerplate and integrates
natively with SwiftUI (`@Query`, `@Model`). Alternative considered: Core Data
(rejected — more boilerplate, older API surface).

## Project Structure
```
checklist-app/
├── checklist-app/
│   ├── checklist_appApp.swift   # @main App — ModelContainer + Schema wiring
│   ├── ContentView.swift        # Root NavigationSplitView + ChecklistDetailView
│   ├── Assets.xcassets/         # AccentColor, AppIcon
│   └── Models/
│       ├── Checklist.swift      # @Model: owns ordered tasks (.cascade)
│       ├── TaskItem.swift       # @Model: ordered task w/ completion logs
│       ├── CompletionLog.swift  # @Model: history record per completion
│       ├── User.swift           # @Model: staff member w/ role
│       └── Enums.swift          # ChecklistType, UserRole (Codable enums)
└── checklist-app.xcodeproj/
```

## Code Patterns

### SwiftData Model (owner side defines @Relationship)
```swift
@Model
final class Checklist {
    var title: String
    var type: ChecklistType        // Codable enum stored by rawValue
    var createdAt: Date
    var updatedAt: Date

    // Owner side: explicit @Relationship w/ cascade delete + inverse
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.checklist)
    var tasks: [TaskItem] = []

    init(title: String, type: ChecklistType, createdAt: Date = .now) {
        self.title = title; self.type = type
        self.createdAt = createdAt; self.updatedAt = createdAt
    }
}

// Child side: plain optional inverse — NO @Relationship macro here
@Model final class TaskItem {
    var checklist: Checklist?
    @Relationship(deleteRule: .cascade, inverse: \CompletionLog.task)
    var logs: [CompletionLog] = []
}
```

### Container Wiring (@main App)
```swift
@main
struct checklist_appApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Checklist.self, TaskItem.self,
                             CompletionLog.self, User.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do { return try ModelContainer(for: schema, configurations: [config]) }
        catch { fatalError("Could not create ModelContainer: \(error)") }
    }()

    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(sharedModelContainer)
    }
}
```

### SwiftUI View (read via @Query, write via modelContext)
```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Checklist.title) private var checklists: [Checklist]

    var body: some View {
        NavigationSplitView {
            List {
                if checklists.isEmpty {
                    ContentUnavailableView("No Checklists", systemImage: "checklist",
                        description: Text("Add a checklist to get started."))
                }
                ForEach(checklists) { checklist in /* NavigationLink ... */ }
                    .onDelete(perform: deleteChecklists)
            }
        } detail: { Text("Select a checklist") }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Checklist.self, TaskItem.self,
                              CompletionLog.self, User.self], inMemory: true)
}
```

## Naming Conventions
| Type | Convention | Example |
|------|-----------|---------|
| Types (struct/class/enum) | PascalCase | `Checklist`, `TaskItem`, `UserRole` |
| Files | PascalCase.swift | `TaskItem.swift` |
| Properties / functions | camelCase | `completedAt`, `deleteChecklists` |
| Enums | `String, Codable, CaseIterable` | `ChecklistType.opening` |
| Models | `final class` + `@Model` | `final class User` |

## Code Standards
- `@Model` classes **must** be `final`
- Owner side of a relationship declares `@Relationship(deleteRule:, inverse:)`; child side is a plain optional (no macro)
- Use `.cascade` for owned children (checklist→tasks→logs); use `.nullify` for optional parents
- Document every model + relationship with `///` doc comments
- Avoid shadowing Swift stdlib (e.g. `TaskItem`, **not** `Task`)
- Use `Date` for timestamps; rely on `@Model`'s implicit persistent identifier
- Empty list states use `ContentUnavailableView`
- Previews use `.modelContainer(for:, inMemory: true)`
- Sort in `@Query` or via `.sorted { $0.order < $1.order }` — never rely on insertion order

## Security Requirements
- Role-based access via `UserRole` (`.staff`, `.manager`) — enforce in app logic (`user.role == .manager`); SwiftData does not enforce row-level security
- No secrets/network/auth code yet — when added: store credentials in **Keychain** (never UserDefaults/plaintext)
- Validate all model input before `modelContext.insert(_:)` — SwiftData has no schema-level constraints beyond `@Attribute(.unique)`
- Sanitize user-entered `String` fields before display if ever rendered as attributed text

## 📂 Codebase References
- **App entry / container**: `checklist-app/checklist_appApp.swift`
- **Root view + detail view**: `checklist-app/ContentView.swift`
- **Models**: `checklist-app/Models/{Checklist,TaskItem,CompletionLog,User,Enums}.swift`
- **Project config**: `checklist-app.xcodeproj/`
- **External SwiftData deep-dive** (fetched docs, harvest later): `.tmp/external-context/swiftdata/` — 6 files covering `@Model`, relationships, attributes, container setup, pitfalls, and app-specific model examples

## Related Files
- `business-domain.md` — Why this app exists (restaurant checklist problem) *(still template — fill next)*
- `business-tech-bridge.md` — Business → technical mapping
- `decisions-log.md` — Architecture decisions (SwiftData vs Core Data, etc.)
- `living-notes.md` — Active issues and open questions
- `.tmp/external-context/swiftdata/` — Authoritative SwiftData reference (run `/context harvest` to promote)
