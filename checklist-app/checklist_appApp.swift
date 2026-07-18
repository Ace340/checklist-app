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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Checklist.self,
            TaskItem.self,
            CompletionLog.self,
            User.self,
            BusinessDay.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Ensures the invariants the UI relies on hold before any view loads.
///
/// - The "current business day" is the one `BusinessDay` with `closedAt == nil`.
///   Seed one if none is open (derived daily state needs a business day to
///   attribute logs to).
/// - A default manager exists so manager-only actions (e.g. Finish Day) are
///   available. TODO: replace with real auth / current-user session — today
///   the app is trust-based, role is a model field, not a login
///   (see business-domain.md).
private func seedOnLaunch(into context: ModelContext) {
    let openDayDescriptor = FetchDescriptor<BusinessDay>(
        predicate: #Predicate { $0.closedAt == nil }
    )
    if (try? context.fetchCount(openDayDescriptor)) == 0 {
        context.insert(BusinessDay())
    }

    let managerDescriptor = FetchDescriptor<User>(
        predicate: #Predicate { $0.role.rawValue == "manager" }
    )
    if (try? context.fetchCount(managerDescriptor)) == 0 {
        context.insert(User(name: "Manager", role: .manager))
    }

    try? context.save()
}
