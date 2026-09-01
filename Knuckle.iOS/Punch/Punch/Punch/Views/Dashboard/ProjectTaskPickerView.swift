//
//  ProjectTaskPickerView.swift
//  Punch
//
//  Two-step picker for selecting a Harvest project and task
//

import SwiftUI

struct ProjectTaskPickerView: View {
    let projects: [Project]
    @Binding var selectedProject: Project?
    @Binding var selectedTask: ProjectTask?
    let tasksForProject: (Int64) async -> [ProjectTask]
    @Environment(\.dismiss) var dismiss

    @State private var availableTasks: [ProjectTask] = []
    @State private var isLoadingTasks = false

    var body: some View {
        NavigationStack {
            List {
                // Project Section
                Section("Project") {
                    ForEach(projects) { project in
                        Button {
                            selectProject(project)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.name)
                                        .foregroundColor(.textPrimary)

                                    if let clientName = project.clientName {
                                        Text(clientName)
                                            .font(.caption)
                                            .foregroundColor(.textTertiary)
                                    }
                                }

                                Spacer()

                                if selectedProject?.id == project.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accent)
                                }
                            }
                        }
                    }
                }

                // Task Section (only show when project selected)
                if selectedProject != nil {
                    Section("Task") {
                        if isLoadingTasks {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Loading tasks...")
                                    .foregroundColor(.textSecondary)
                            }
                        } else if availableTasks.isEmpty {
                            Text("No tasks available")
                                .foregroundColor(.textMuted)
                        } else {
                            ForEach(availableTasks) { task in
                                Button {
                                    selectTask(task)
                                } label: {
                                    HStack {
                                        Text(task.name)
                                            .foregroundColor(.textPrimary)

                                        Spacer()

                                        if selectedTask?.id == task.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accent)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .navigationTitle("Select Project & Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(selectedProject == nil || selectedTask == nil)
                }
            }
            .task {
                // Load tasks for initially selected project
                if let project = selectedProject {
                    await loadTasks(for: project.id)
                }
            }
        }
    }

    private func selectProject(_ project: Project) {
        if selectedProject?.id != project.id {
            selectedProject = project
            selectedTask = nil
            Task {
                await loadTasks(for: project.id)
            }
        }
    }

    private func selectTask(_ task: ProjectTask) {
        selectedTask = task
    }

    private func loadTasks(for projectId: Int64) async {
        isLoadingTasks = true
        availableTasks = await tasksForProject(projectId)
        isLoadingTasks = false

        // Auto-select first task if available
        if selectedTask == nil, let firstTask = availableTasks.first {
            selectedTask = firstTask
        }
    }
}

#Preview {
    ProjectTaskPickerView(
        projects: [
            Project(id: 1, name: "Website Redesign", code: "WEB", clientId: 1, clientName: "Acme Corp", isActive: true, isBillable: true),
            Project(id: 2, name: "Mobile App", code: "APP", clientId: 1, clientName: "Acme Corp", isActive: true, isBillable: true),
            Project(id: 3, name: "Internal Tools", code: nil, clientId: 2, clientName: "Internal", isActive: true, isBillable: false)
        ],
        selectedProject: .constant(nil),
        selectedTask: .constant(nil),
        tasksForProject: { _ in
            [
                ProjectTask(id: 1, name: "Development", isBillable: true, isActive: true),
                ProjectTask(id: 2, name: "Design", isBillable: true, isActive: true),
                ProjectTask(id: 3, name: "Meeting", isBillable: false, isActive: true)
            ]
        }
    )
}
