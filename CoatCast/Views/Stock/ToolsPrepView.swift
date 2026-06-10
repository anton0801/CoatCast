//
//  ToolsPrepView.swift
//  CoatCast
//
//  Feature 09 (Tools & Prep): a prep checklist (tape, film, roller, sandpaper…)
//  with real toggles, progress, custom items and delete.
//

import SwiftUI

struct ToolsPrepView: View {
    @EnvironmentObject var store: AppStore
    @State private var newTitle = ""

    var body: some View {
        ScreenScaffold("Tools & Prep", subtitle: "Get the room ready") {
            VStack(spacing: Theme.Space.m) {
                CardView(tint: Theme.ready) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Prep progress").font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text(Formatters.percent(store.prepProgress * 100))
                                .font(Theme.heading(16)).foregroundColor(Theme.ready)
                        }
                        ProgressBar(progress: store.prepProgress, tint: Theme.ready)
                    }
                }

                // Add custom
                CardView {
                    HStack(spacing: 10) {
                        TextField("Add a prep step…", text: $newTitle)
                            .font(Theme.body()).foregroundColor(Theme.textPrimary)
                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.textInactive : Theme.accent)
                                .font(.system(size: 26))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if store.prepTasks.isEmpty {
                    EmptyStateCard(icon: "checklist", title: "Checklist empty",
                                   message: "Add prep steps so nothing gets missed.")
                } else {
                    ForEach(store.prepTasks) { task in
                        taskRow(task)
                    }
                    ActionButton(title: "Reset Default Checklist", systemImage: "arrow.counterclockwise", kind: .secondary) {
                        SampleData.defaultPrepTasks().forEach { store.addPrep($0) }
                    }
                }
            }
        }
    }

    private func taskRow(_ task: PrepTask) -> some View {
        CardView {
            HStack(spacing: 12) {
                Button(action: { store.togglePrep(task) }) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(task.isDone ? Theme.ready : Theme.textInactive)
                }
                .buttonStyle(PlainButtonStyle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(Theme.body())
                        .foregroundColor(task.isDone ? Theme.textSecondary : Theme.textPrimary)
                        .strikethrough(task.isDone, color: Theme.textSecondary)
                    Text(task.category).font(Theme.caption(11)).foregroundColor(Theme.textInactive)
                }
                Spacer()
                Button(action: { store.deletePrep(task) }) {
                    Image(systemName: "trash").foregroundColor(Theme.defect).font(.system(size: 15))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func addTask() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addPrep(PrepTask(title: trimmed, category: "Custom"))
        newTitle = ""
        UIApplication.shared.dismissKeyboard()
    }
}
