//
//  EntryFormView.swift
//  Punch
//
//  Create/edit time entry form with project/task pickers
//

import SwiftUI

struct EntryFormView: View {
    @StateObject private var viewModel: EntryFormViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false

    init(entry: TrackedTimeEntry? = nil) {
        _viewModel = StateObject(wrappedValue: EntryFormViewModel(entry: entry))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Project/Task section
                Section("Project & Task") {
                    // Project picker
                    Picker("Project", selection: $viewModel.selectedProject) {
                        Text("Select Project").tag(nil as Project?)
                        ForEach(viewModel.projects) { project in
                            VStack(alignment: .leading) {
                                Text(project.name)
                                if let clientName = project.clientName {
                                    Text(clientName)
                                        .font(.caption)
                                        .foregroundColor(.textTertiary)
                                }
                            }
                            .tag(project as Project?)
                        }
                    }
                    .onChange(of: viewModel.selectedProject) { _, newProject in
                        if let project = newProject {
                            Task {
                                await viewModel.loadTasks(for: project.id)
                            }
                        }
                    }

                    // Task picker
                    Picker("Task", selection: $viewModel.selectedTask) {
                        Text("Select Task").tag(nil as ProjectTask?)
                        ForEach(viewModel.tasks) { task in
                            Text(task.name).tag(task as ProjectTask?)
                        }
                    }
                    .disabled(viewModel.selectedProject == nil)
                }

                // Time section
                Section("Time") {
                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)

                    HStack {
                        Text("Duration")
                        Spacer()
                        TextField("0:00", text: $viewModel.hoursText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: viewModel.hoursText) { _, _ in
                                viewModel.syncHoursFromText()
                            }
                    }
                }

                // Notes section
                Section("Notes") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 80)
                }

                // Delete section (edit mode only)
                if viewModel.isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Entry")
                                Spacer()
                            }
                        }
                    }
                }

                // Error display
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .navigationTitle(viewModel.isEditing ? "Edit Entry" : "New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.isValid)
                }
            }
            .task {
                await viewModel.loadData()
            }
            .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
}

#Preview("New Entry") {
    EntryFormView()
}

#Preview("Edit Entry") {
    EntryFormView(entry: TrackedTimeEntry(
        id: 123,
        projectId: 1,
        projectName: "Website Redesign",
        taskId: 1,
        taskName: "Development",
        spentDate: Date(),
        hours: 2.0,
        notes: "Test notes",
        isRunning: false,
        isBilled: false,
        startedTime: nil,
        endedTime: nil,
        createdAt: Date(),
        updatedAt: Date()
    ))
}
