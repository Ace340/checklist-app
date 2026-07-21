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

/// Ensures two invariants hold before any view loads:
///   1. The "current business day" exists: the one `BusinessDay` with
///      `closedAt == nil`. Derived daily state needs an open business day
///      to attribute logs to; without it the first tap on a duty would be
///      silently invisible.
///   2. No `CompletionLog` is older than the rolling 30-day retention
///      window (ADR 0004). Stale logs are hard-deleted here on every
///      launch — bounded store, no tombstones, no background task.
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

    // Hard-delete logs older than the rolling 30-day retention window
    // (ADR 0004). The cutoff comes from the pure `LogRetention` helper
    // (testable in isolation); the fetch + delete happens here because
    // SwiftData's `#Predicate` filters at the DB layer — more efficient
    // than fetching all and filtering in memory via the helper. An empty
    // result set is a no-op.
    let cutoff = LogRetention.cutoffDate(asOf: .now)
    let staleLogsDescriptor = FetchDescriptor<CompletionLog>(
        predicate: #Predicate { $0.timestamp < cutoff }
    )
    if let staleLogs = try? context.fetch(staleLogsDescriptor) {
        for log in staleLogs {
            context.delete(log)
        }
    }

    try? context.save()
}
