//
//  HarvestService.swift
//  Punch
//
//  TimeTrackingService implementation for Harvest
//

import Foundation

actor HarvestService: TimeTrackingService {
    static let shared = HarvestService()

    private let client = HarvestAPIClient.shared

    // Cache for project assignments (includes tasks)
    private var cachedProjectAssignments: [HarvestProjectAssignment]?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 5 * 60  // 5 minutes

    private init() {}

    // MARK: - Authentication

    var isAuthenticated: Bool {
        get async {
            await client.hasTokens
        }
    }

    var currentUserName: String? {
        get async {
            await client.currentUserName
        }
    }

    var currentUserEmail: String? {
        get async {
            await client.currentUserEmail
        }
    }

    func logout() async {
        await client.clearTokens()
        cachedProjectAssignments = nil
        cacheTimestamp = nil
    }

    // MARK: - Projects & Tasks

    func getProjects() async throws -> [Project] {
        let assignments = try await getProjectAssignments()
        return assignments.map { assignment in
            Project(
                id: assignment.project.id,
                name: assignment.project.name,
                code: assignment.project.code,
                clientId: assignment.client?.id,
                clientName: assignment.client?.name,
                isActive: (assignment.project.isActive ?? true) && assignment.isActive,
                isBillable: assignment.project.isBillable ?? true
            )
        }
    }

    func getTasks(forProjectId projectId: Int64) async throws -> [ProjectTask] {
        let assignments = try await getProjectAssignments()
        guard let projectAssignment = assignments.first(where: { $0.project.id == projectId }) else {
            return []
        }

        return projectAssignment.taskAssignments
            .filter { $0.isActive }
            .map { taskAssignment in
                ProjectTask(
                    id: taskAssignment.task.id,
                    name: taskAssignment.task.name,
                    isBillable: taskAssignment.isBillable,
                    isActive: taskAssignment.isActive
                )
            }
    }

    private func getProjectAssignments() async throws -> [HarvestProjectAssignment] {
        // Check cache
        if let cached = cachedProjectAssignments,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            return cached
        }

        // Fetch from API - paginate through all pages
        var allAssignments: [HarvestProjectAssignment] = []
        var page = 1
        var totalPages = 1

        repeat {
            let response: HarvestProjectAssignmentsResponse = try await client.get(
                "users/me/project_assignments",
                queryParams: [
                    "is_active": "true",
                    "page": String(page),
                    "per_page": "100"
                ]
            )

            allAssignments.append(contentsOf: response.projectAssignments)
            totalPages = response.totalPages
            page += 1
        } while page <= totalPages

        // Update cache
        cachedProjectAssignments = allAssignments
        cacheTimestamp = Date()

        return allAssignments
    }

    // MARK: - Timer Operations

    func getRunningTimer() async throws -> RunningTimer? {
        let response: HarvestTimeEntriesResponse = try await client.get(
            "time_entries",
            queryParams: ["is_running": "true"]
        )

        guard let entry = response.timeEntries.first else {
            return nil
        }

        // Calculate startedAt from timerStartedAt or use spent_date with time
        let startedAt = entry.timerStartedAt ?? parseStartedAt(entry)

        return RunningTimer(
            id: entry.id,
            projectId: entry.project.id,
            projectName: entry.project.name,
            taskId: entry.task.id,
            taskName: entry.task.name,
            startedAt: startedAt,
            hours: entry.hours,
            notes: entry.notes
        )
    }

    func startTimer(_ input: StartTimerInput) async throws -> RunningTimer {
        // First check if a timer is already running
        if let existingTimer = try await getRunningTimer() {
            return existingTimer
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let spentDate = dateFormatter.string(from: Date())

        let request = HarvestStartTimerRequest(
            projectId: input.projectId,
            taskId: input.taskId,
            spentDate: spentDate,
            notes: input.notes
        )

        let entry: HarvestTimeEntry = try await client.post("time_entries", body: request)
        let startedAt = entry.timerStartedAt ?? Date()

        // Every successful start — manual, geofence, or replay — becomes the
        // default for the next manual start
        LastTrackedDefaults.save(projectId: entry.project.id, taskId: entry.task.id)

        return RunningTimer(
            id: entry.id,
            projectId: entry.project.id,
            projectName: entry.project.name,
            taskId: entry.task.id,
            taskName: entry.task.name,
            startedAt: startedAt,
            hours: entry.hours,
            notes: entry.notes
        )
    }

    func stopTimer(entryId: Int64, notes: String?) async throws -> TrackedTimeEntry {
        // Stop the timer
        let stoppedEntry: HarvestTimeEntry = try await client.patch("time_entries/\(entryId)/stop")

        // If notes were provided, update the entry
        var finalEntry = stoppedEntry
        if let notes = notes, !notes.isEmpty {
            let updateRequest = HarvestUpdateEntryRequest(
                projectId: nil,
                taskId: nil,
                spentDate: nil,
                hours: nil,
                notes: notes
            )
            finalEntry = try await client.patch("time_entries/\(entryId)", body: updateRequest)
        }

        return mapToTrackedTimeEntry(finalEntry)
    }

    // MARK: - Time Entries

    func getEntries(from: Date, to: Date) async throws -> [TrackedTimeEntry] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var allEntries: [HarvestTimeEntry] = []
        var page = 1
        var totalPages = 1

        repeat {
            let response: HarvestTimeEntriesResponse = try await client.get(
                "time_entries",
                queryParams: [
                    "from": dateFormatter.string(from: from),
                    "to": dateFormatter.string(from: to),
                    "page": String(page),
                    "per_page": "100"
                ]
            )

            allEntries.append(contentsOf: response.timeEntries)
            totalPages = response.totalPages
            page += 1
        } while page <= totalPages

        return allEntries.map { mapToTrackedTimeEntry($0) }
    }

    func createEntry(_ input: CreateEntryInput) async throws -> TrackedTimeEntry {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let request = HarvestCreateEntryRequest(
            projectId: input.projectId,
            taskId: input.taskId,
            spentDate: dateFormatter.string(from: input.spentDate),
            hours: input.hours,
            notes: input.notes
        )

        let entry: HarvestTimeEntry = try await client.post("time_entries", body: request)
        return mapToTrackedTimeEntry(entry)
    }

    func updateEntry(id: Int64, _ input: UpdateEntryInput) async throws -> TrackedTimeEntry {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let request = HarvestUpdateEntryRequest(
            projectId: input.projectId,
            taskId: input.taskId,
            spentDate: input.spentDate.map { dateFormatter.string(from: $0) },
            hours: input.hours,
            notes: input.notes
        )

        let entry: HarvestTimeEntry = try await client.patch("time_entries/\(id)", body: request)
        return mapToTrackedTimeEntry(entry)
    }

    func deleteEntry(id: Int64) async throws {
        try await client.delete("time_entries/\(id)")
    }

    // MARK: - Statistics

    func getStats() async throws -> TimeStats {
        let calendar = Calendar.current
        let now = Date()

        // Calculate date ranges
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return TimeStats(hoursToday: 0, hoursThisWeek: 0, hoursThisMonth: 0)
        }

        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfDay
        guard let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) else {
            return TimeStats(hoursToday: 0, hoursThisWeek: 0, hoursThisMonth: 0)
        }

        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfDay
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return TimeStats(hoursToday: 0, hoursThisWeek: 0, hoursThisMonth: 0)
        }

        // Fetch entries for the month (covers all needed ranges)
        let entries = try await getEntries(from: startOfMonth, to: endOfMonth)

        // Calculate totals
        let hoursToday = entries
            .filter { $0.spentDate >= startOfDay && $0.spentDate < endOfDay }
            .reduce(0) { $0 + $1.hours }

        let hoursThisWeek = entries
            .filter { $0.spentDate >= startOfWeek && $0.spentDate < endOfWeek }
            .reduce(0) { $0 + $1.hours }

        let hoursThisMonth = entries
            .reduce(0) { $0 + $1.hours }

        return TimeStats(
            hoursToday: hoursToday,
            hoursThisWeek: hoursThisWeek,
            hoursThisMonth: hoursThisMonth
        )
    }

    // MARK: - Helpers

    private func mapToTrackedTimeEntry(_ entry: HarvestTimeEntry) -> TrackedTimeEntry {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let spentDate = dateFormatter.date(from: entry.spentDate) ?? Date()

        let startedTime = parseTime(entry.startedTime, on: spentDate)
        let endedTime = parseTime(entry.endedTime, on: spentDate)

        return TrackedTimeEntry(
            id: entry.id,
            projectId: entry.project.id,
            projectName: entry.project.name,
            taskId: entry.task.id,
            taskName: entry.task.name,
            spentDate: spentDate,
            hours: entry.hours,
            notes: entry.notes,
            isRunning: entry.isRunning,
            isBilled: entry.isBilled,
            startedTime: startedTime,
            endedTime: endedTime,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    private func parseStartedAt(_ entry: HarvestTimeEntry) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let spentDate = dateFormatter.date(from: entry.spentDate) ?? Date()

        if let startedTime = entry.startedTime {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            if let time = timeFormatter.date(from: startedTime) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                     minute: timeComponents.minute ?? 0,
                                     second: 0,
                                     of: spentDate) ?? spentDate
            }
        }

        // Fallback: calculate from hours elapsed
        if entry.hours > 0 {
            return Date().addingTimeInterval(-entry.hours * 3600)
        }

        return Date()
    }

    private func parseTime(_ timeString: String?, on date: Date) -> Date? {
        guard let timeString = timeString else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        guard let time = timeFormatter.date(from: timeString) else { return nil }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        return calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: date
        )
    }

    // MARK: - Cache Management

    func invalidateCache() {
        cachedProjectAssignments = nil
        cacheTimestamp = nil
    }
}
