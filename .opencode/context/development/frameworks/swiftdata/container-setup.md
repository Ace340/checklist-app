<!-- Context: development/frameworks/swiftdata/container-setup | Priority: high | Version: 1.0 | Updated: 2026-07-14 -->

# ModelContainer, Schema & ModelConfiguration

**Scope**: Registering models via `Schema`, `ModelContainer` initializers, `ModelConfiguration` (in-memory/previews), wiring into a SwiftUI `App`, reading via `@Query`/`modelContext`.

---

## Schema — register all model types
```swift
let schema = Schema([
    Checklist.self,
    TaskItem.self,
    CompletionLog.self,
    User.self
])
```

## ModelContainer initializers

### 1. Variadic model types (simplest)
```swift
let container = try ModelContainer(
    for: Trip.self, Accommodation.self,
    configurations: configuration
)
```

### 2. Explicit Schema + configs (required: ≥1 config)
```swift
let container = try ModelContainer(for: schema, configurations: config)
```

## ModelConfiguration — customize storage
```swift
// init(_:schema:url:allowsSave:cloudKitDatabase:)
let config = ModelConfiguration(
    "MyConfig", schema: mySchema, url: myURL,
    allowsSave: true, cloudKitDatabase: .automatic
)
```

### In-memory / read-only (previews & tests)
```swift
let configuration = ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: false)
let container = try ModelContainer(for: Trip.self, configurations: configuration)
```

---

## Wiring into a SwiftUI App — `.modelContainer(for:)`

Creates the container and injects `ModelContext` into the SwiftUI environment.

### Multiple model types (this checklist app)
```swift
@main
struct ChecklistApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(for: [
                Checklist.self, TaskItem.self,
                CompletionLog.self, User.self
            ])
    }
}
```

### Explicit Schema + custom configuration (custom store path / previews)
```swift
@main
struct ChecklistApp: App {
    let container: ModelContainer
    init() {
        let schema = Schema([Checklist.self, TaskItem.self,
                             CompletionLog.self, User.self])
        let config = ModelConfiguration("ChecklistStore", schema: schema,
                                        isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create container: \(error)")
        }
    }
    var body: some Scene {
        WindowGroup { ContentView() }.modelContainer(container)
    }
}
```

---

## Using the context in a view
```swift
struct DestinationListView: View {
    @Query(sort: \Destination.name) private var destinations: [Destination]
    @Environment(\.modelContext) private var context

    var body: some View {
        List(destinations) { d in Text(d.name) }
            .toolbar {
                Button("Add") {
                    let d = Destination(name: "Paris")
                    context.insert(d)
                    try? context.save()           // ✅ just save()
                }
            }
    }
}
```
> ✅ `@Query` is for SwiftUI **views only**. Outside views, use `FetchDescriptor` + `ModelContext` (see `best-practices.md`).

### SwiftUI preview (in-memory)
```swift
#Preview {
    ContentView()
        .modelContainer(for: Checklist.self, inMemory: true)
}
```

## Sources
- https://developer.apple.com/documentation/swiftdata/modelcontainer
- https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(_:schema:url:allowsave:cloudkitdatabase:)
- https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches

## 📂 Codebase References
- **App entry / `sharedModelContainer` wiring**: `checklist-app/checklist_appApp.swift` (uses explicit `Schema` + `ModelConfiguration(isStoredInMemoryOnly: false)`)
- **`.modelContainer(for:)` consumers / previews**: `checklist-app/ContentView.swift`
- **Models registered in the Schema**: `checklist-app/Models/{Checklist,TaskItem,CompletionLog,User}.swift`
- See `project-intelligence/technical-domain.md` § "Container Wiring" for this project's exact `checklist_appApp` source.
