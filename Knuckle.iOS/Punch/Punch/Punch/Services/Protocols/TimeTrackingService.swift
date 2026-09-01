//
//  TimeTrackingService.swift
//  Punch
//
//  Protocol for time tracking services (Harvest, Toggl, Clockify, etc.)
//

import Foundation

// MARK: - Domain Models

/// A project from the time tracking service
struct Project: Identifiable, Codable, Hashable {
    let id: Int64
    let name: String
    let code: String?
    let clientId: Int64?
    let clientName: String?
    let isActive: Bool
    let isBillable: Bool
}

/// A task that can be assigned to a project
struct ProjectTask: Identifiable, Codable, Hashable {
    let id: Int64
    let name: String
    let isBillable: Bool
    let isActive: Bool
}

/// A time entry from the time tracking service
struct TrackedTimeEntry: Identifiable, Codable {
    let id: Int64
    let projectId: Int64
    let projectName: String
    let taskId: Int64
    let taskName: String
    let spentDate: Date
    let hours: Double
    let notes: String?
    let isRunning: Bool
    let isBilled: Bool
    let startedTime: Date?
    let endedTime: Date?
    let createdAt: Date
    let updatedAt: Date
}

/// A running timer from the time tracking service
struct RunningTimer: Codable {
    let id: Int64
    let projectId: Int64
    let projectName: String
    let taskId: Int64
    let taskName: String
    let startedAt: Date
    let hours: Double
    let notes: String?
}

/// Statistics for time tracking
struct TimeStats: Codable {
    let hoursToday: Double
    let hoursThisWeek: Double
    let hoursThisMonth: Double
}

/// Request to start a timer
struct StartTimerInput {
    let projectId: Int64
    let taskId: Int64
    let notes: String?
}

/// Request to create a manual time entry
struct CreateEntryInput {
    let projectId: Int64
    let taskId: Int64
    let spentDate: Date
    let hours: Double
    let notes: String?
}

/// Request to update a time entry
struct UpdateEntryInput {
    let projectId: Int64?
    let taskId: Int64?
    let spentDate: Date?
    let hours: Double?
    let notes: String?
}

/// Remembers the most recently tracked project/task so manual starts
/// default to what the user last used rather than the first project
enum LastTrackedDefaults {
    private static let projectKey = "lastTrackedProjectId"
    private static let taskKey = "lastTrackedTaskId"

    static func save(projectId: Int64, taskId: Int64) {
        UserDefaults.standard.set(Int(projectId), forKey: projectKey)
        UserDefaults.standard.set(Int(taskId), forKey: taskKey)
    }

    static var projectId: Int64? {
        (UserDefaults.standard.object(forKey: projectKey) as? Int).map(Int64.init)
    }

    static var taskId: Int64? {
        (UserDefaults.standard.object(forKey: taskKey) as? Int).map(Int64.init)
    }
}

// MARK: - Protocol

/// Protocol for time tracking services
/// Implementations: HarvestService, TogglService (future), ClockifyService (future)
protocol TimeTrackingService: Actor {
    /// Check if the user is authenticated
    var isAuthenticated: Bool { get async }

    /// Get the current user's display name
    var currentUserName: String? { get async }

    // MARK: - Projects & Tasks

    /// Fetch all active projects the user can track time to
    func getProjects() async throws -> [Project]

    /// Fetch tasks assigned to a specific project
    func getTasks(forProjectId projectId: Int64) async throws -> [ProjectTask]

    // MARK: - Timer Operations

    /// Get the currently running timer (if any)
    func getRunningTimer() async throws -> RunningTimer?

    /// Start a new timer
    func startTimer(_ input: StartTimerInput) async throws -> RunningTimer

    /// Stop the running timer
    func stopTimer(entryId: Int64, notes: String?) async throws -> TrackedTimeEntry

    // MARK: - Time Entries

    /// Fetch time entries for a date range
    func getEntries(from: Date, to: Date) async throws -> [TrackedTimeEntry]

    /// Create a manual time entry
    func createEntry(_ input: CreateEntryInput) async throws -> TrackedTimeEntry

    /// Update an existing time entry
    func updateEntry(id: Int64, _ input: UpdateEntryInput) async throws -> TrackedTimeEntry

    /// Delete a time entry
    func deleteEntry(id: Int64) async throws

    // MARK: - Statistics

    /// Get time statistics (today, this week, this month)
    func getStats() async throws -> TimeStats

    // MARK: - Authentication

    /// Clear authentication tokens and log out
    func logout() async
}
