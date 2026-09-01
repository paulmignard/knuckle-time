//
//  BackgroundTaskManager.swift
//  Punch
//
//  Manages background task execution for geofence operations.
//  Requests extra execution time from iOS for API calls.
//

import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    // Keyed by task ID: the same name can be active twice (rapid re-entry
    // of one region), and IDs are what end the task
    private var activeTasks: [UIBackgroundTaskIdentifier: String] = [:]
    private let queue = DispatchQueue(label: "com.knuckle.backgroundtask")

    private init() {}

    /// Start a background task with a unique identifier
    /// Returns task ID or .invalid if background execution not available
    @discardableResult
    func beginTask(named name: String, expirationHandler: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier {
        var taskID: UIBackgroundTaskIdentifier = .invalid

        taskID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            GeofenceLogger.shared.log("⚠️ Background task EXPIRED: \(name)", level: .warning)
            expirationHandler?()
            self?.endTask(taskID)
        }

        if taskID != .invalid {
            queue.sync {
                activeTasks[taskID] = name
            }
            GeofenceLogger.shared.logBackgroundTask("Started '\(name)' (ID: \(taskID.rawValue))")

            // Log remaining time
            let remaining = UIApplication.shared.backgroundTimeRemaining
            if remaining < Double.greatestFiniteMagnitude {
                GeofenceLogger.shared.logBackgroundTask("Remaining time: \(String(format: "%.1f", remaining))s")
            }
        } else {
            GeofenceLogger.shared.log("❌ Failed to start background task: \(name)", level: .error)
        }

        return taskID
    }

    /// End a background task by ID. Idempotent: the expiration handler and the
    /// normal completion path can both call this for the same ID.
    func endTask(_ taskID: UIBackgroundTaskIdentifier) {
        guard taskID != .invalid else { return }

        var wasActive = false
        queue.sync {
            wasActive = activeTasks.removeValue(forKey: taskID) != nil
        }
        guard wasActive else { return }

        UIApplication.shared.endBackgroundTask(taskID)
        GeofenceLogger.shared.logBackgroundTask("Ended task (ID: \(taskID.rawValue))")
    }

    /// End all active background tasks
    func endAllTasks() {
        var tasks: [UIBackgroundTaskIdentifier: String] = [:]
        queue.sync {
            tasks = activeTasks
            activeTasks.removeAll()
        }
        for (taskID, name) in tasks {
            UIApplication.shared.endBackgroundTask(taskID)
            GeofenceLogger.shared.logBackgroundTask("Ended '\(name)' (cleanup)")
        }
    }
}
