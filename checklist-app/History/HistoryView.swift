//
//  HistoryView.swift
//  checklist-app
//
//  Manager-only browser for past business days and the `CompletionLog`s
//  captured in each. Opens from a clock icon in `AreaListView`'s toolbar
//  (gated on `currentUser.isManager`). Hierarchy: business day → Area
//  (FOH / BOH) → logs. Tap a log to edit (`note` / `completedBy` only,
//  via `LogEditSheet`); swipe-left to delete with confirmation.
//
//  See `docs/adr/0004-history-viewer-and-retention.md` for the locked-in
//  policy: 30-day rolling retention (hard-deleted on app launch), edit
//  stamps `lastEditedAt` / `lastEditedBy`, delete is irreversible.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss

    /// All business days, most recent first. Includes the currently-open
    /// day at the top so managers can review today's logs as they accrue.
    /// Past days are bounded by the rolling 30-day retention window
    /// (cleanup runs in `seedOnLaunch`); a day whose logs have all aged
    /// out simply appears empty rather than vanishing from the list —
    /// the day still happened, the audit trail for it is just gone.
    @Query(sort: \BusinessDay.openedAt, order: .reverse) private var businessDays: [BusinessDay]

    var body: some View {
        NavigationStack {
            List {
                if businessDays.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Past business days will appear here as they close.")
                    )
                }
                ForEach(businessDays) { day in
                    NavigationLink {
                        BusinessDayDetailView(day: day)
                    } label: {
                        BusinessDayRow(day: day)
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: { dismiss() })
                }
            }
        }
    }
}

// MARK: - Business-day row

private struct BusinessDayRow: View {
    let day: BusinessDay

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.openedAt.formatted(date: .complete, time: .omitted))
                .font(.headline)
            HStack(spacing: 8) {
                if day.isOpen {
                    Text("Open")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if let closed = day.closedAt {
                    Text("Closed \(closed.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(day.logs.count) logs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Drill-down: logs in one business day, grouped by Area

private struct BusinessDayDetailView: View {
    let day: BusinessDay

    @Environment(\.modelContext) private var modelContext

    /// The log a manager is about to edit (tap) — drives the edit sheet.
    @State private var editingLog: CompletionLog?

    /// The log a manager has swiped-to-delete and is confirming — drives
    /// the destructive confirmation alert. Cleared on dismiss.
    @State private var logPendingDeletion: CompletionLog?

    /// Logs whose `duty?.checklist?.area == .foh`. Sorted newest-first
    /// within the day — the natural reading order for an audit log.
    private var fohLogs: [CompletionLog] {
        day.logs
            .filter { $0.duty?.checklist?.area == .foh }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var bohLogs: [CompletionLog] {
        day.logs
            .filter { $0.duty?.checklist?.area == .boh }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Logs whose duty or checklist is gone (e.g. a duty was deleted
    /// post-completion). Kept visible instead of silently dropped — the
    /// completion still happened, the manager still needs to see it.
    private var orphanedLogs: [CompletionLog] {
        day.logs
            .filter { $0.duty?.checklist?.area == nil }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        List {
            if day.logs.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "checklist",
                    description: Text("No completion logs were recorded in this business day.")
                )
            }
            if !fohLogs.isEmpty {
                Section {
                    ForEach(fohLogs) { log in logRow(log) }
                } header: {
                    Text(Area.foh.displayName)
                }
            }
            if !bohLogs.isEmpty {
                Section {
                    ForEach(bohLogs) { log in logRow(log) }
                } header: {
                    Text(Area.boh.displayName)
                }
            }
            if !orphanedLogs.isEmpty {
                Section {
                    ForEach(orphanedLogs) { log in logRow(log) }
                } header: {
                    Text("Other")
                }
            }
        }
        .navigationTitle(day.openedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingLog) { log in
            LogEditSheet(log: log)
        }
        .alert(
            "Delete log?",
            isPresented: Binding(
                get: { logPendingDeletion != nil },
                set: { if !$0 { logPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { logPendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let log = logPendingDeletion {
                    modelContext.delete(log)
                    try? modelContext.save()
                }
                logPendingDeletion = nil
            }
        } message: {
            Text("This completion log will be permanently removed. This action cannot be undone.")
        }
    }

    /// One row shape, used in all three sections. Factored out so the
    /// tap-to-edit and swipe-to-delete affordances can't drift between
    /// FOH / BOH / Other.
    @ViewBuilder
    private func logRow(_ log: CompletionLog) -> some View {
        LogRow(log: log)
            .contentShape(Rectangle())
            .onTapGesture { editingLog = log }
            .swipeActions {
                Button(role: .destructive) {
                    logPendingDeletion = log
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

// MARK: - Log row

private struct LogRow: View {
    let log: CompletionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(log.duty?.title ?? "(deleted duty)")
                    .font(.body)
                // "Edited" badge — small pencil glyph when the log has
                // been touched. Full edit history (who/when) is visible
                // inside `LogEditSheet`'s footer.
                if log.lastEditedBy != nil {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(log.completedBy?.name ?? "Unattributed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = log.note, !note.isEmpty {
                    Text("— \(note)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
