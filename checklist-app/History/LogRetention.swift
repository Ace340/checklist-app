//
//  LogRetention.swift
//  checklist-app
//
//  Pure, framework-free retention helpers governing which `CompletionLog`s
//  are eligible for hard deletion. The app layer (`seedOnLaunch`) calls
//  these and performs the `modelContext.delete`; this module never touches
//  SwiftData, so it unit-tests without a container.
//
//  Rule locked in by `docs/adr/0004-history-viewer-and-retention.md`:
//  a log is eligible for deletion once its `timestamp` is *strictly older*
//  than 30 × 24 hours from "now." Cleanup is rolling (not calendar-month),
//  hard (no tombstone), and runs on app launch.
//
//  Mirrors the `Auth/PinHasher.swift` and `StaffManagement/StaffManagement.swift`
//  pattern: top-level functions collected as a `caseless enum` namespace.
//

import Foundation

/// Namespace for completion-log retention checks. `caseless enum` so it
/// can't be accidentally instantiated — same trick used for `StaffManagement`
/// and the stdlib's `Mirror`.
enum LogRetention {

    /// Retention window in seconds. Rolling 30 days = 30 × 24 × 60 × 60.
    /// Exposed as a named constant so the policy is searchable from one
    /// place; `docs/adr/0004-history-viewer-and-retention.md` is the source
    /// of truth for the *value*.
    static let retentionWindow: TimeInterval = 30 * 24 * 60 * 60

    /// The cutoff `Date`: any log whose `timestamp` is *strictly older*
    /// than this is eligible for deletion. A log whose `timestamp` equals
    /// the cutoff is NOT eligible — exactly-30-days-old is still within
    /// the retention window.
    static func cutoffDate(asOf: Date) -> Date {
        asOf - retentionWindow
    }

    /// Filters `logs` to those eligible for hard deletion: any log whose
    /// `timestamp` is strictly older than `cutoffDate(asOf:)`. Input order
    /// is preserved (matters for predictable call-site iteration).
    ///
    /// The caller is expected to pass the result of a `@Query` or
    /// `FetchDescriptor` — this helper does no fetching itself, by design.
    static func logsToDelete(in logs: [CompletionLog], asOf: Date) -> [CompletionLog] {
        let cutoff = cutoffDate(asOf: asOf)
        return logs.filter { $0.timestamp < cutoff }
    }
}
