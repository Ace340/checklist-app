//
//  ContentView.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Checklist.title) private var checklists: [Checklist]

    var body: some View {
        NavigationSplitView {
            List {
                if checklists.isEmpty {
                    ContentUnavailableView(
                        "No Checklists",
                        systemImage: "checklist",
                        description: Text("Add a checklist to get started.")
                    )
                }
                ForEach(checklists) { checklist in
                    NavigationLink {
                        ChecklistDetailView(checklist: checklist)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(checklist.title).font(.headline)
                            Text(checklist.type.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteChecklists)
            }
            .navigationTitle("Checklists")
            .toolbar {
                ToolbarItem {
                    Button(action: addChecklist) {
                        Label("Add Checklist", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select a checklist")
        }
    }

    private func addChecklist() {
        let checklist = Checklist(title: "New Checklist", type: .opening)
        modelContext.insert(checklist)
    }

    private func deleteChecklists(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(checklists[index])
        }
    }
}

struct ChecklistDetailView: View {
    let checklist: Checklist

    var body: some View {
        List {
            Section("Tasks") {
                if checklist.tasks.isEmpty {
                    Text("No tasks yet").foregroundStyle(.secondary)
                }
                ForEach(checklist.tasks.sorted { $0.order < $1.order }) { task in
                    HStack {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? .green : .secondary)
                        Text(task.title)
                    }
                }
            }
            Section("Details") {
                LabeledContent("Type", value: checklist.type.rawValue.capitalized)
                LabeledContent("Tasks", value: "\(checklist.tasks.count)")
            }
        }
        .navigationTitle(checklist.title)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Checklist.self, TaskItem.self, CompletionLog.self, User.self], inMemory: true)
}
