//
//  BusinessDayHealth.swift
//  checklist-app
//
//  Pure, framework-free staleness check governing when an open
//  `BusinessDay` is considered "forgotten" — open longer than the
//  staleness threshold. The UI layer (`AreaListView`) calls this on
//  launch to decide whether to alert the manager; this module never
//  touches SwiftData, so it unit-tests without a container.
//
//  Rule locked in by `docs/adr/0005-forgotten-finish-day.md`:
//  a business day is stale once its `openedAt` is *strictly older*
//  than 24 hours from "now." Detection is rolling (not clock-based),
//  runs on app launch, and the alert reappears every cold launch
//  while the day remains stale.
//
//  Mirrors the `History/LogRetention.swift` and
//  `StaffManagement/StaffManagement.swift` pattern: helpers collected
//  as a `caseless enum` namespace.
//

import Foundation

/// Namespace for business-day staleness checks. `caseless enum` so it
/// can't be accidentally instantiated — same trick used for `LogRetention`
/// and `StaffManagement`.
enum BusinessDayHealth {

    /// Staleness threshold in seconds. 24 hours = 24 × 60 × 60. Mirrors
    /// `LogRetention.retentionWindow` as a named constant so the policy
    /// is searchable from one place;
    /// `docs/adr/0005-forgotten-finish-day.md` is the source of truth
    /// for the *value*. 24 hours is unambiguous — no legitimate single
    /// business day is this long.
    static let staleThreshold: TimeInterval = 24 * 60 * 60

    /// Whether a business day that opened at `openedAt` is considered
    /// stale as of `asOf`. Strict greater-than: a day exactly 24 hours
    /// old is NOT stale (still within the legitimate-range boundary).
    /// A future `openedAt` (clock skew) returns false — defensive, no
    /// false positives on plausible device clock drift.
    ///
    /// Uses `timeIntervalSince(_:)` rather than the `-` operator: the
    /// latter is ambiguous to the Swift 5 compiler under the project's
    /// `MemberImportVisibility` upcoming-feature flag + SwiftUI/SwiftData
    /// cross-import overlays (tries to resolve `Strideable.-` and falls
    /// through to a `_Pointer` overload). `timeIntervalSince` is
    /// unambiguous and idiomatic — positive when `asOf` is later.
    static func isStale(openedAt: Date, asOf: Date) -> Bool {
        asOf.timeIntervalSince(openedAt) > staleThreshold
    }
}
