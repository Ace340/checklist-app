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

/// Ensures the "current business day" invariant holds before any view
/// loads: the one `BusinessDay` with `closedAt == nil`. Derived daily
/// state needs an open business day to attribute logs to; without it the
/// first tap on a duty would be silently invisible.
///
/// User seeding was removed in ADR 0003 — the first manager is now created
/// by `OnboardingView` on first launch, and subsequent users are added via
/// `StaffManagementView`. No `User` rows exist until onboarding runs.
private func seedOnLaunch(into context: ModelContext) {
    let openDayDescriptor = FetchDescriptor<BusinessDay>(
        predicate: #Predicate { $0.closedAt == nil }
    )
    if (try? context.fetchCount(openDayDescriptor)) == 0 {
        context.insert(BusinessDay())
    }

    try? context.save()
}
