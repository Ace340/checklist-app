//
//  ContentView.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import SwiftUI
import SwiftData

// MARK: - Level 1: Area picker (Home)

/// Home screen: two cards — FOH and BOH (the `Area`s). Primary grouping.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    /// The current business day = the one `BusinessDay` with `closedAt == nil`.
    @Query(filter: #Predicate<BusinessDay> { $0.closedAt == nil })
    private var openBusinessDays: [BusinessDay]

    /// Manager presence gates the Finish Day action. TODO: gate on a real
    /// current-user session once auth exists (see checklist_appApp.swift).
    @Query(filter: #Predicate<User> { $0.role.rawValue == "manager" })
    private var managers: [User]

    private var currentBusinessDay: BusinessDay? { openBusinessDays.first }

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
                if !managers.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Finish Day", action: finishDay)
                            .disabled(currentBusinessDay == nil)
                    }
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
            Text(AreaView.title(area)).font(.headline)
            Text(AreaView.subtitle(area))
                .font(.caption)
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
        .navigationTitle(AreaView.title(area))
    }

    static func title(_ area: Area) -> String {
        switch area {
        case .foh: return "FOH"
        case .boh: return "BOH"
        }
    }

    static func subtitle(_ area: Area) -> String {
        switch area {
        case .foh: return "Front of House"
        case .boh: return "Back of House"
        }
    }
}

// MARK: - Level 3: duties with derived status

private struct DutyListView: View {
    let area: Area
    let cadence: Cadence
    let phase: Phase?

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

    private var duties: [TaskItem] {
        allDuties
            .filter { duty in
                guard let list = duty.checklist else { return false }
                return list.area == area && list.cadence == cadence && list.phase == phase
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

    private var navigationTitle: String {
        switch (cadence, phase) {
        case (.daily, .opening): return "Opening"
        case (.daily, .closing): return "Closing"
        case (.weekly, _): return "Weekly"
        default: return "Duties"
        }
    }

    // MARK: Derived state (ADR #1 — never stored)

    /// Derives the scheduling status of a duty from its logs via the
    /// `DutyStatus` seam in `Scheduling/DutyStatus.swift`.
    private func status(of duty: TaskItem) -> DutyStatus {
        let calendar = Calendar.current
        switch cadence {
        case .daily:
            return dailyDutyStatus(completedInCurrentBusinessDay: doneInCurrentBusinessDay(duty))
        case .weekly:
            // A weekly duty without a weekday is malformed; treat as pending.
            guard let scheduled = duty.weekday else { return .pending }
            return weeklyDutyStatus(
                scheduled: scheduled,
                now: .now,
                completedThisWeek: doneThisWeek(duty, calendar: calendar),
                calendar: calendar
            )
        }
    }

    /// Daily "done" ↔ a log exists for this duty whose `businessDay` is the
    /// current open business day. Compared by identity — within a single
    /// `mainContext` SwiftData returns the same instance for a given row.
    private func doneInCurrentBusinessDay(_ duty: TaskItem) -> Bool {
        guard let current = currentBusinessDay else { return false }
        return duty.logs.contains { log in
            log.businessDay != nil && log.businessDay === current
        }
    }

    /// Weekly "done this week" ↔ a log exists whose `timestamp` falls inside
    /// the Monday-start week containing now.
    private func doneThisWeek(_ duty: TaskItem, calendar: Calendar) -> Bool {
        let interval = mondayStartWeekInterval(containing: .now, calendar: calendar)
        return duty.logs.contains { interval.contains($0.timestamp) }
    }

    // MARK: Mutations

    /// Tap a duty to log completion; tap a done duty to undo (remove the
    /// current-period log). The new log is attributed to the current business
    /// day so a completion at 1:30am Sunday still belongs to Saturday's day.
    private func toggle(_ duty: TaskItem) {
        let calendar = Calendar.current
        switch status(of: duty) {
        case .done:
            undoCompletion(of: duty, calendar: calendar)
        default:
            let log = CompletionLog()
            log.task = duty
            log.businessDay = currentBusinessDay
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
        Button(action: onToggle) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text(duty.title)
                    if duty.checklist?.cadence == .weekly, let day = duty.weekday {
                        Text(DutyRow.weekdayLabel(day))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch status {
        case .done: return "checkmark.circle.fill"
        case .pending: return "circle"
        case .due: return "circle.dotted"
        case .overdue: return "exclamationmark.circle.fill"
        case .notYetDue: return "circle.dashed"
        }
    }

    private var iconColor: Color {
        switch status {
        case .done: return .green
        case .overdue: return .red
        case .due: return .orange
        case .pending, .notYetDue: return .secondary
        }
    }

    private var statusLabel: String {
        switch status {
        case .done: return "Done"
        case .pending: return "Pending"
        case .due: return "Due"
        case .overdue: return "Overdue"
        case .notYetDue: return "Not yet due"
        }
    }

    private var statusColor: Color {
        switch status {
        case .overdue: return .red
        case .due: return .orange
        default: return .secondary
        }
    }

    static func weekdayLabel(_ day: Weekday) -> String {
        switch day {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
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
                                Text(DutyRow.weekdayLabel(day)).tag(day)
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
        switch (cadence, phase) {
        case (.daily, .opening): return "\(AreaView.title(area)) Opening"
        case (.daily, .closing): return "\(AreaView.title(area)) Closing"
        case (.weekly, _): return "\(AreaView.title(area)) Weekly"
        default: return AreaView.title(area)
        }
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
}
