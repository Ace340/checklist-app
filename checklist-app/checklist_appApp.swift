//
//  checklist_appApp.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import SwiftUI
import SwiftData

@main
struct checklist_appApp: App {
    /// The current-user session. `@State` is the canonical owner for an
    /// `@Observable` model in SwiftUI; passing it via `.environment` lets
    /// every view read/write the session without prop-drilling. Survives
    /// app backgrounding because `AuthStore` persists the user's UUID in
    /// `UserDefaults` (the PIN is never persisted — see ADR 0002).
    @State private var authStore = AuthStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Checklist.self,
            TaskItem.self,
            CompletionLog.self,
            User.self,
            BusinessDay.self,
        ])
        // Use an in-memory store under SwiftUI Previews and XCTest. Both run
        // the app's full App.main() in a sandbox where the default on-disk
        // SwiftData store URL isn't writable, which would trip the
        // `fatalError` below and kill the host before XCTest/Previews could
        // connect. In-memory also gives tests a fresh, isolated store each run.
        let env = ProcessInfo.processInfo.environment
        let isRunningUnderTooling =
            env["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || env["XCTestConfigurationFilePath"] != nil
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isRunningUnderTooling
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            seedOnLaunch(into: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authStore)
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Ensures the invariants the UI relies on hold before any view loads.
///
/// - The "current business day" is the one `BusinessDay` with `closedAt == nil`.
///   Seed one if none is open (derived daily state needs a business day to
///   attribute logs to).
/// - On first launch (no `User` rows yet), seed demo users per ADR 0002:
///   one manager (PIN `0000`) and one staff user (PIN `1111`). These PINs
///   are intentionally documented in the ADR — production deployments will
///   replace them via a future staff-management UI.
private func seedOnLaunch(into context: ModelContext) {
    let openDayDescriptor = FetchDescriptor<BusinessDay>(
        predicate: #Predicate { $0.closedAt == nil }
    )
    if (try? context.fetchCount(openDayDescriptor)) == 0 {
        context.insert(BusinessDay())
    }

    let userDescriptor = FetchDescriptor<User>()
    if (try? context.fetchCount(userDescriptor)) == 0 {
        let manager = User(name: "Manager", role: .manager)
        try? manager.setPin("0000")
        let staff = User(name: "Staff", role: .staff)
        try? staff.setPin("1111")
        context.insert(manager)
        context.insert(staff)
    }

    try? context.save()
}
