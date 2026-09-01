//
//  DashboardViewModel.swift
//  Punch
//
//  Dashboard view model using Harvest TimeTrackingService
//

import Foundation
import SwiftUI
import Combine
import UIKit
import CoreLocation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var runningTimer: RunningTimer?
    @Published var stats: TimeStats?
    @Published var todayEntries: [TrackedTimeEntry] = []
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var selectedTask: ProjectTask?
    @Published var notes: String = ""
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Optimistic UI State
    @Published var isTogglingTimer = false  // Button loading state (prevents double-tap)
    @Published var isSyncing = false        // Background sync indicator
    @Published var showErrorToast = false   // Error toast visibility
    @Published var errorToastMessage: String?

    private let harvestService = HarvestService.shared
    private var cancellables = Set<AnyCancellable>()

    // State capture for rollback
    private struct TimerState {
        let runningTimer: RunningTimer?
        let wasRunning: Bool
    }

    init() {
        // Listen for timer state changes from LocationService/TimerManager
        // This notification is posted when timer starts/stops (geofence, polling, or manual)
        NotificationCenter.default
            .publisher(for: .timerStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    // Refresh display data when timer state changes
                    await self?.fetchCurrentTimer()
                    await self?.fetchStats()
                    await self?.fetchTodayEntries()
                }
            }
            .store(in: &cancellables)
    }

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchCurrentTimer() }
            group.addTask { await self.fetchStats() }
            group.addTask { await self.fetchTodayEntries() }
            group.addTask { await self.fetchProjects() }
            group.addTask { await self.fetchGeofences() }
        }
    }

    func fetchGeofences() async {
        await GeofenceRepository.shared.loadGeofences()
    }

    func fetchCurrentTimer() async {
        do {
            runningTimer = try await harvestService.getRunningTimer()
            // Note: TimerManager handles Live Activity and Widget sync centrally
        } catch {
            runningTimer = nil
        }
    }

    func fetchStats() async {
        do {
            stats = try await harvestService.getStats()
            // Note: TimerManager handles Widget sync centrally
        } catch {
            // Silently fail - stats are not critical
        }
    }

    func fetchTodayEntries() async {
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }

            todayEntries = try await harvestService.getEntries(from: today, to: tomorrow)
        } catch {
            // Silently fail - entries list is not critical
        }
    }

    func fetchProjects() async {
        do {
            projects = try await harvestService.getProjects()
            if selectedProject == nil {
                // Prefer whatever was tracked last (manual or geofence);
                // fall back to the first project/task
                selectedProject = projects.first { $0.id == LastTrackedDefaults.projectId } ?? projects.first
                if let projectId = selectedProject?.id {
                    let tasks = try await harvestService.getTasks(forProjectId: projectId)
                    selectedTask = tasks.first { $0.id == LastTrackedDefaults.taskId } ?? tasks.first
                }
            }
        } catch let apiError as HarvestAPIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to load projects: \(error.localizedDescription)"
        }
    }

    func getTasks(forProjectId projectId: Int64) async -> [ProjectTask] {
        do {
            return try await harvestService.getTasks(forProjectId: projectId)
        } catch {
            return []
        }
    }

    func startTimer() async {
        guard let project = selectedProject, let task = selectedTask else {
            showError("Please select a project and task")
            return
        }

        // Prevent double-tap
        guard !isTogglingTimer else { return }
        isTogglingTimer = true

        // 1. OPTIMISTIC: Update UI immediately
        let previousState = TimerState(runningTimer: runningTimer, wasRunning: runningTimer != nil)
        let savedNotes = notes

        // Create optimistic timer
        let optimisticTimer = RunningTimer(
            id: -1,  // Temporary ID
            projectId: project.id,
            projectName: project.name,
            taskId: task.id,
            taskName: task.name,
            startedAt: Date(),
            hours: 0,
            notes: notes.isEmpty ? nil : notes
        )
        runningTimer = optimisticTimer
        notes = ""

        // Haptic feedback - timer started
        HapticFeedback.medium()

        // Get geofence info for the status pill
        let geofenceName = LocationService.shared.currentGeofence?.name
        let hasActiveGeofences = !LocationService.shared.monitoredGeofences.isEmpty
        let authStatus = LocationService.shared.authorizationStatus
        let needsLocationPermission = hasActiveGeofences && authStatus != .authorizedAlways

        // Start Live Activity immediately (optimistic)
        LiveActivityManager.shared.startActivity(
            clientName: "\(project.name) - \(task.name)",
            startedAt: optimisticTimer.startedAt,
            todayHoursBase: stats?.hoursToday ?? 0,
            weekHoursBase: stats?.hoursThisWeek ?? 0,
            geofenceName: geofenceName,
            needsLocationPermission: needsLocationPermission
        )

        // 2. SYNC: Call API in background
        isSyncing = true

        do {
            let input = StartTimerInput(
                projectId: project.id,
                taskId: task.id,
                notes: savedNotes.isEmpty ? nil : savedNotes
            )
            let actualTimer = try await harvestService.startTimer(input)

            // Success - update with real timer data
            runningTimer = actualTimer
            isSyncing = false

            // Haptic feedback for confirmed success
            HapticFeedback.success()

            // Update Live Activity with real data (geofence info already captured above)
            LiveActivityManager.shared.startActivity(
                clientName: "\(actualTimer.projectName) - \(actualTimer.taskName)",
                startedAt: actualTimer.startedAt,
                todayHoursBase: stats?.hoursToday ?? 0,
                weekHoursBase: stats?.hoursThisWeek ?? 0,
                geofenceName: geofenceName,
                needsLocationPermission: needsLocationPermission
            )

            // Notify TimerManager to sync Widget and other displays
            NotificationCenter.default.post(name: .timerStateChanged, object: nil)

            // Fetch stats in background
            await fetchStats()

        } catch {
            // 3. ROLLBACK: Restore previous state on failure
            runningTimer = previousState.runningTimer
            notes = savedNotes

            // End the optimistic Live Activity
            if !previousState.wasRunning {
                LiveActivityManager.shared.endActivity()
            }

            isSyncing = false
            showError("Couldn't start timer. Check your connection.")

            HapticFeedback.error()
        }

        isTogglingTimer = false
    }

    func stopTimer(notes: String?) async {
        guard let timer = runningTimer else { return }

        // Prevent double-tap
        guard !isTogglingTimer else { return }
        isTogglingTimer = true

        // 1. OPTIMISTIC: Update UI immediately
        let previousState = TimerState(runningTimer: timer, wasRunning: true)

        runningTimer = nil

        // Haptic feedback - timer stopped
        HapticFeedback.medium()

        // End Live Activity immediately (optimistic)
        LiveActivityManager.shared.endActivity()

        // 2. SYNC: Call API in background
        isSyncing = true

        do {
            _ = try await harvestService.stopTimer(entryId: timer.id, notes: notes)

            // Success confirmed
            isSyncing = false

            // Haptic feedback for confirmed success
            HapticFeedback.success()

            // Notify TimerManager to sync Widget and other displays
            NotificationCenter.default.post(name: .timerStateChanged, object: nil)

            // Fetch updated stats and entries in background
            await fetchStats()
            await fetchTodayEntries()

        } catch {
            // 3. ROLLBACK: Restore previous state on failure
            runningTimer = previousState.runningTimer

            // Restart the Live Activity
            if let restoredTimer = runningTimer {
                let currentTimerHours = restoredTimer.hours
                let todayBase = max(0, (stats?.hoursToday ?? 0) - currentTimerHours)
                let weekBase = max(0, (stats?.hoursThisWeek ?? 0) - currentTimerHours)

                // Get geofence info for the status pill
                let geofenceName = LocationService.shared.currentGeofence?.name
                let hasActiveGeofences = !LocationService.shared.monitoredGeofences.isEmpty
                let authStatus = LocationService.shared.authorizationStatus
                let needsLocationPermission = hasActiveGeofences && authStatus != .authorizedAlways

                LiveActivityManager.shared.startActivity(
                    clientName: "\(restoredTimer.projectName) - \(restoredTimer.taskName)",
                    startedAt: restoredTimer.startedAt,
                    todayHoursBase: todayBase,
                    weekHoursBase: weekBase,
                    geofenceName: geofenceName,
                    needsLocationPermission: needsLocationPermission
                )
            }

            isSyncing = false
            showError("Couldn't stop timer. Check your connection.")

            HapticFeedback.error()
        }

        isTogglingTimer = false
    }

    // Calculate elapsed time since timer started
    var elapsedSeconds: Int {
        guard let timer = runningTimer else { return 0 }
        return Int(Date().timeIntervalSince(timer.startedAt))
    }

    // MARK: - Error Toast

    private func showError(_ message: String) {
        errorToastMessage = message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showErrorToast = true
        }

        // Auto-dismiss after 4 seconds
        Task {
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run {
                if showErrorToast {
                    dismissError()
                }
            }
        }
    }

    func dismissError() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showErrorToast = false
        }

        // Clear message after animation
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                errorToastMessage = nil
            }
        }
    }
}

// MARK: - Haptic Feedback

enum HapticFeedback {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
