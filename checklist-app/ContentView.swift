//
//  ContentView.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import SwiftUI
import SwiftData

/// Short time-slot label ("Opening" / "Closing" / "Weekly") shared by the
/// navigation title and the default checklist title. Extracted so the two
/// sites can't drift.
fileprivate func slotName(cadence: Cadence, phase: Phase?) -> String {
    switch (cadence, phase) {
    case (.daily, .opening): return "Opening"
    case (.daily, .closing): return "Closing"
    case (.weekly, _): return "Weekly"
    default: return "Duties"
    }
}

// MARK: - Root: login gate

/// Root view. Shows `LoginView` when no current user is signed in (ADR 0002);
/// otherwise shows the area list. Splitting here (instead of inside
/// `AreaListView`) keeps the auth gate visible at the top of the view tree
/// where debugging is easiest.
struct ContentView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if authStore.currentUser(in: modelContext) != nil {
            AreaListView()
        } else {
            LoginView()
        }
    }
}

// MARK: - Level 1: Area picker (Home)

/// Home screen: two cards — FOH and BOH (the `Area`s). Primary grouping.
private struct AreaListView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.modelContext) private var modelContext

    /// The current business day = the one `BusinessDay` with `closedAt == nil`.
    @Query(filter: #Predicate<BusinessDay> { $0.closedAt == nil })
    private var openBusinessDays: [BusinessDay]

    private var currentBusinessDay: BusinessDay? { openBusinessDays.first }
    private var currentUser: User? { authStore.currentUser(in: modelContext) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Area.allCases, id: \.self) { area in
                    NavigationLink {
                        AreaView(area: area)
                    } label: {
                        AreaRow(area: area)
                    }
                }
            }
            .navigationTitle("Checklists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if currentUser?.isManager == true {
                        Button("Finish Day", action: finishDay)
                            .disabled(currentBusinessDay == nil)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    SwitchUserButton(userName: currentUser?.name ?? "")
                }
            }
        }
    }

    /// Manager action: close the current business day and open the next.
    /// Daily duties reset automatically — the new business day has no logs,
    /// so derived state reads every daily duty as `.pending`. Weekly duties
    /// are scoped by Monday-start week, so they are unaffected.
    private func finishDay() {
        guard let current = currentBusinessDay else { return }
        current.closedAt = .now
        modelContext.insert(BusinessDay())
        try? modelContext.save()
    }
}

private struct AreaRow: View {
    let area: Area

    var body: some View {
        VStack(alignment: .leading) {
            Text(area.displayName).font(.headline)
            Text(area.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// "Signed in as {name}. Tap to switch." Signs out on tap; the root
/// `ContentView` flips back to `LoginView` because `currentUser` becomes nil.
private struct SwitchUserButton: View {
    @Environment(AuthStore.self) private var authStore
    let userName: String

    var body: some View {
        Button {
            authStore.signOut()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                Text(userName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Level 2: phase / cadence groupings for one area

private struct AreaView: View {
    let area: Area

    var body: some View {
        List {
            NavigationLink {
                DutyListView(area: area, cadence: .daily, phase: .opening)
            } label: {
                Label("Opening", systemImage: "sunrise")
            }
            NavigationLink {
                DutyListView(area: area, cadence: .daily, phase: .closing)
            } label: {
                Label("Closing", systemImage: "sunset")
            }
            NavigationLink {
                DutyListView(area: area, cadence: .weekly, phase: nil)
            } label: {
                Label("Weekly", systemImage: "calendar")
            }
        }
        .navigationTitle(area.displayName)
    }
}

// MARK: - Level 3: duties with derived status

private struct DutyListView: View {
    let area: Area
    let cadence: Cadence
    let phase: Phase?

    @Environment(AuthStore.self) private var authStore
    @Environment(\.modelContext) private var modelContext

    /// All duties; filtered to this checklist in Swift. Filtering on a nil-vs-
    /// non-nil `phase` across a relationship is awkward in `#Predicate`, and
    /// the safe-in-Swift path avoids the predicate pitfalls in
    /// `swiftdata/best-practices.md`.
    @Query private var allDuties: [TaskItem]

    @Query(filter: #Predicate<BusinessDay> { $0.closedAt == nil })
    private var openBusinessDays: [BusinessDay]

    @State private var showingAddDuty = false

    private var currentBusinessDay: BusinessDay? { openBusinessDays.first }
    private var currentUser: User? { authStore.currentUser(in: modelContext) }

    private var duties: [TaskItem] {
        allDuties
            .filter { duty in
                guard let list = duty.checklist else { return false }
                guard list.area == area && list.cadence == cadence && list.phase == phase else { return false }
                // Hide weekly duties whose weekday hasn't arrived yet this
                // week (`DutyStatus.shouldSurface`). The other half of this
                // rule — preventing early taps — is automatic: a hidden row
                // can't be tapped. See ADR #1 and CONTEXT.md.
                return shouldSurface(status(of: duty))
            }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            if duties.isEmpty {
                ContentUnavailableView(
                    "No Duties",
                    systemImage: "checklist",
                    description: Text("Add a duty to this checklist.")
                )
            }
            ForEach(duties) { duty in
                DutyRow(
                    duty: duty,
                    status: status(of: duty),
                    onToggle: { toggle(duty) }
                )
            }
            .onDelete(perform: deleteDuties)
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem {
                Button(action: { showingAddDuty = true }) {
                    Label("Add Duty", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddDuty) {
            AddDutySheet(area: area, cadence: cadence, phase: phase)
        }
    }

    private var navigationTitle: String { slotName(cadence: cadence, phase: phase) }

    // MARK: Derived state (ADR #1 — never stored)

    /// Derives the scheduling status of a duty from its logs via the
    /// `DutyStatus` seam in `Scheduling/DutyStatus.swift`. The ADR #1
    /// derivation (`isDone(in:)` / `isDoneThisWeek(asOf:calendar:)`) lives
    /// on `TaskItem` so the XCTest target can cover it with an in-memory
    /// SwiftData container.
    private func status(of duty: TaskItem) -> DutyStatus {
        let calendar = Calendar.current
        switch cadence {
        case .daily:
            let done = currentBusinessDay.map { duty.isDone(in: $0) } ?? false
            return dailyDutyStatus(completedInCurrentBusinessDay: done)
        case .weekly:
            // A weekly duty without a weekday is malformed; treat as pending.
            guard let scheduled = duty.weekday else { return .pending }
            return weeklyDutyStatus(
                scheduled: scheduled,
                now: .now,
                completedThisWeek: duty.isDoneThisWeek(asOf: .now, calendar: calendar),
                calendar: calendar
            )
        }
    }

    // MARK: Mutations

    /// Tap a duty to log completion; tap a done duty to undo (remove the
    /// current-period log). The new log is attributed to the current
    /// business day (so a completion at 1:30am Sunday still belongs to
    /// Saturday's day) and to the current user (ADR 0002 — every log
    /// carries attribution for the audit trail).
    private func toggle(_ duty: TaskItem) {
        let calendar = Calendar.current
        switch status(of: duty) {
        case .done:
            undoCompletion(of: duty, calendar: calendar)
        default:
            // Guard required: a log without a `businessDay` reference is
            // silently invisible forever — the derivation filters out
            // nil-attributed logs. This window exists transiently if
            // `finishDay` just ran and the @Query hasn't refreshed, or if
            // `seedOnLaunch` hasn't fired yet.
            guard let current = currentBusinessDay else { return }
            let log = CompletionLog()
            log.duty = duty
            log.businessDay = current
            log.completedBy = currentUser
            modelContext.insert(log)
        }
        try? modelContext.save()
    }

    private func undoCompletion(of duty: TaskItem, calendar: Calendar) {
        if cadence == .daily {
            guard let current = currentBusinessDay else { return }
            if let log = duty.logs.first(where: { $0.businessDay === current }) {
                modelContext.delete(log)
            }
        } else {
            let interval = mondayStartWeekInterval(containing: .now, calendar: calendar)
            if let log = duty.logs.first(where: { interval.contains($0.timestamp) }) {
                modelContext.delete(log)
            }
        }
    }

    private func deleteDuties(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(duties[index])
        }
    }
}

private struct DutyRow: View {
    let duty: TaskItem
    let status: DutyStatus
    let onToggle: () -> Void

    var body: some View {
        let style = DutyStatusStyle.style(for: status)
        Button(action: onToggle) {
            HStack {
                Image(systemName: style.icon)
                    .foregroundStyle(style.iconColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text(duty.title)
                    if duty.checklist?.cadence == .weekly, let day = duty.weekday {
                        Text(day.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(style.label)
                    .font(.caption)
                    .foregroundStyle(style.labelColor)
            }
        }
        .buttonStyle(.plain)
    }
}

/// UI presentation for a single `DutyStatus` — one switch instead of four
/// parallel ones (icon, icon color, label, label color). Collocated so a new
/// `DutyStatus` case forces one compiler error here, not four.
private struct DutyStatusStyle {
    let icon: String
    let iconColor: Color
    let label: String
    let labelColor: Color

    static func style(for status: DutyStatus) -> DutyStatusStyle {
        switch status {
        case .done:      return .init(icon: "checkmark.circle.fill",       iconColor: .green,     label: "Done",         labelColor: .secondary)
        case .pending:   return .init(icon: "circle",                      iconColor: .secondary, label: "Pending",      labelColor: .secondary)
        case .due:       return .init(icon: "circle.dotted",               iconColor: .orange,    label: "Due",          labelColor: .orange)
        case .overdue:   return .init(icon: "exclamationmark.circle.fill", iconColor: .red,       label: "Overdue",      labelColor: .red)
        case .notYetDue: return .init(icon: "circle.dashed",               iconColor: .secondary, label: "Not yet due",  labelColor: .secondary)
        }
    }
}

// MARK: - Add duty

private struct AddDutySheet: View {
    let area: Area
    let cadence: Cadence
    let phase: Phase?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var checklists: [Checklist]

    @State private var title = ""
    @State private var weekday: Weekday = .monday

    var body: some View {
        NavigationStack {
            Form {
                Section("Duty") {
                    TextField("Title", text: $title)
                    if cadence == .weekly {
                        Picker("Day", selection: $weekday) {
                            ForEach(Weekday.allCases, id: \.self) { day in
                                Text(day.displayName).tag(day)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Duty")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addDuty() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespaces)
    }

    /// Lazily creates the `Checklist` for this area/cadence/phase on first use.
    private var targetChecklist: Checklist? {
        checklists.first { $0.area == area && $0.cadence == cadence && $0.phase == phase }
    }

    private func addDuty() {
        let list: Checklist
        if let existing = targetChecklist {
            list = existing
        } else {
            list = Checklist(title: defaultChecklistTitle, area: area, cadence: cadence, phase: phase)
            modelContext.insert(list)
        }
        let order = (list.tasks.map(\.order).max() ?? -1) + 1
        let duty = TaskItem(
            title: trimmedTitle,
            order: order,
            weekday: cadence == .weekly ? weekday : nil
        )
        duty.checklist = list
        modelContext.insert(duty)
        try? modelContext.save()
        dismiss()
    }

    private var defaultChecklistTitle: String {
        "\(area.displayName) \(slotName(cadence: cadence, phase: phase))"
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Checklist.self,
            TaskItem.self,
            CompletionLog.self,
            User.self,
            BusinessDay.self,
        ], inMemory: true)
        .environment(AuthStore())
}
