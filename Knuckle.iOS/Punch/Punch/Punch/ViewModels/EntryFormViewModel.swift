//
//  EntryFormViewModel.swift
//  Punch
//
//  Entry form view model for creating/editing time entries with Harvest
//

import Foundation
import SwiftUI
import Combine

@MainActor
class EntryFormViewModel: ObservableObject {
    // Project/Task selection
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var tasks: [ProjectTask] = []
    @Published var selectedTask: ProjectTask?

    // Entry details
    @Published var date: Date = Date()
    @Published var hours: Double = 1.0
    @Published var hoursText: String = "1:00"
    @Published var notes: String = ""

    @Published var isLoading = false
    @Published var error: String?

    let entryId: Int64?
    let isEditing: Bool

    private let harvestService = HarvestService.shared

    init(entry: TrackedTimeEntry? = nil) {
        self.entryId = entry?.id
        self.isEditing = entry != nil

        if let entry = entry {
            self.date = entry.spentDate
            self.hours = entry.hours
            self.hoursText = Self.hoursToText(entry.hours)
            self.notes = entry.notes ?? ""
            // Project/task will be loaded in loadData()
        }
    }

    var isValid: Bool {
        selectedProject != nil &&
        selectedTask != nil &&
        hours > 0
    }

    /// Parse "H:MM" or ":MM" text into decimal hours. Returns nil if invalid.
    static func textToHours(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let h: Int
        let m: Int
        if parts.count == 2 {
            h = Int(parts[0]) ?? 0
            guard let mins = Int(parts[1]), mins >= 0, mins < 60 else { return nil }
            m = mins
        } else if parts.count == 1, let mins = Int(parts[0]) {
            // Bare number without colon — treat as minutes
            guard mins >= 0, mins < 60 else { return nil }
            h = 0
            m = mins
        } else {
            return nil
        }
        guard h >= 0, h + m > 0 else { return nil }
        return Double(h) + Double(m) / 60.0
    }

    /// Convert decimal hours to "H:MM" text
    static func hoursToText(_ hours: Double) -> String {
        let totalMinutes = Int(round(hours * 60))
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h):\(String(format: "%02d", m))"
    }

    /// Called when hoursText changes to sync the decimal hours value
    func syncHoursFromText() {
        if let parsed = Self.textToHours(hoursText) {
            hours = parsed
        }
    }

    func loadData() async {
        isLoading = true

        do {
            // Load projects from Harvest
            projects = try await harvestService.getProjects()

            // If editing, find and select the existing project/task
            if isEditing, let entryId = entryId {
                // Fetch the entry to get project/task IDs
                // For now, we'll search through entries to find it
                let entries = try await harvestService.getEntries(
                    from: date.addingTimeInterval(-86400),
                    to: date.addingTimeInterval(86400)
                )
                if let entry = entries.first(where: { $0.id == entryId }) {
                    selectedProject = projects.first { $0.id == entry.projectId }

                    if let project = selectedProject {
                        tasks = try await harvestService.getTasks(forProjectId: project.id)
                        selectedTask = tasks.first { $0.id == entry.taskId }
                    }
                }
            } else if let firstProject = projects.first {
                // Auto-select first project for new entries
                selectedProject = firstProject
                tasks = try await harvestService.getTasks(forProjectId: firstProject.id)
                selectedTask = tasks.first
            }
        } catch {
            self.error = "Failed to load data"
        }

        isLoading = false
    }

    func loadTasks(for projectId: Int64) async {
        do {
            tasks = try await harvestService.getTasks(forProjectId: projectId)
            if selectedTask == nil || !tasks.contains(where: { $0.id == selectedTask?.id }) {
                selectedTask = tasks.first
            }
        } catch {
            tasks = []
        }
    }

    func save() async -> Bool {
        guard let project = selectedProject else {
            error = "Please select a project"
            return false
        }

        guard let task = selectedTask else {
            error = "Please select a task"
            return false
        }

        guard hours > 0 else {
            error = "Hours must be greater than 0"
            return false
        }

        isLoading = true
        error = nil

        do {
            if isEditing, let id = entryId {
                let input = UpdateEntryInput(
                    projectId: project.id,
                    taskId: task.id,
                    spentDate: date,
                    hours: hours,
                    notes: notes.isEmpty ? nil : notes
                )
                _ = try await harvestService.updateEntry(id: id, input)
            } else {
                let input = CreateEntryInput(
                    projectId: project.id,
                    taskId: task.id,
                    spentDate: date,
                    hours: hours,
                    notes: notes.isEmpty ? nil : notes
                )
                _ = try await harvestService.createEntry(input)
            }
            isLoading = false
            return true
        } catch let apiError as HarvestAPIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to save entry"
        }

        isLoading = false
        return false
    }

    func delete() async -> Bool {
        guard let id = entryId else { return false }

        isLoading = true
        error = nil

        do {
            try await harvestService.deleteEntry(id: id)
            isLoading = false
            return true
        } catch let apiError as HarvestAPIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to delete entry"
        }

        isLoading = false
        return false
    }
}
