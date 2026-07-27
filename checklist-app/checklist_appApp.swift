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
    // (ADR 0004). The "strictly older than 30 days" rule lives in exactly
    // one place — `LogRetention.logsToDelete` — and is pinned by
    // `LogRetentionTests`. We fetch the candidate set here (the helper is
    // framework-free by design and never touches SwiftData), then perform
    // the deletes. An empty result set is a no-op. Data volume is bounded
    // (single restaurant, rolling 30-day window), so the in-memory filter
    // is immaterial; the single-source-of-truth win outweighs the marginal
    // cost of fetching logs without a DB-layer predicate.
    let allLogsDescriptor = FetchDescriptor<CompletionLog>()
    if let allLogs = try? context.fetch(allLogsDescriptor) {
        for log in LogRetention.logsToDelete(in: allLogs, asOf: .now) {
            context.delete(log)
        }
    }

    try? context.save()
}
