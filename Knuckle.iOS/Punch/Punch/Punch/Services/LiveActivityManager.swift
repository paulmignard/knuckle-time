//
//  LiveActivityManager.swift
//  Punch
//
//  Created by Paul Mignard on 1/31/26.
//

import Foundation
import ActivityKit

// KnuckleTimerActivityAttributes is defined in Shared/KnuckleTimerActivityAttributes.swift
// That file must have Target Membership in BOTH the main app and widget extension

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    @available(iOS 16.1, *)
    private var currentActivity: Activity<KnuckleTimerActivityAttributes>?

    private init() {}

    /// Start a Live Activity for the running timer
    /// - Parameters:
    ///   - clientName: Display name (project - task)
    ///   - startedAt: When the timer started
    ///   - todayHoursBase: Hours tracked today BEFORE the current timer started
    ///   - weekHoursBase: Hours tracked this week BEFORE the current timer started
    ///   - geofenceName: Current geofence name (nil = manual tracking)
    ///   - needsLocationPermission: Whether location permission is needed
    /// Track current geofence name to detect changes
    private var currentGeofenceName: String?

    func startActivity(
        clientName: String,
        startedAt: Date,
        todayHoursBase: Double? = nil,
        weekHoursBase: Double? = nil,
        geofenceName: String? = nil,
        needsLocationPermission: Bool = false
    ) {
        // Callers without fresh stats (background geofence events) pass nil —
        // carry over the last known widget bases instead of zeroing them
        let existingState = TimerWidgetState.load()
        let todayHoursBase = todayHoursBase ?? existingState.todayHoursBase
        let weekHoursBase = weekHoursBase ?? existingState.weekHoursBase

        // Sync home screen widget first — it should reflect tracking state
        // even if Live Activities are disabled or unavailable
        TimerWidgetState(
            isTracking: true,
            clientName: clientName,
            geofenceName: geofenceName,
            startedAt: startedAt,
            todayHoursBase: todayHoursBase,
            weekHoursBase: weekHoursBase,
            needsLocationPermission: needsLocationPermission
        ).save()

        guard #available(iOS 16.2, *) else { return }

        // Check if user has disabled Live Activities in settings (default is true/enabled)
        let isEnabled = UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
        guard isEnabled else { return }

        // If we already have an activity running, check if geofence state changed
        if currentActivity != nil {
            // If geofence state changed, we need to recreate the activity
            // (geofenceName is in attributes which can't be updated)
            if currentGeofenceName != geofenceName {
                // End ALL activities to prevent orphans, then create new one
                endAllActivitiesAndCreate(
                    clientName: clientName,
                    startedAt: startedAt,
                    todayHoursBase: todayHoursBase,
                    weekHoursBase: weekHoursBase,
                    geofenceName: geofenceName,
                    needsLocationPermission: needsLocationPermission
                )
                return
            } else {
                // Same geofence state, just update hours
                updateActivity(todayHoursBase: todayHoursBase, weekHoursBase: weekHoursBase)
                return
            }
        }

        // No existing activity, create new one
        createActivity(
            clientName: clientName,
            startedAt: startedAt,
            todayHoursBase: todayHoursBase,
            weekHoursBase: weekHoursBase,
            geofenceName: geofenceName,
            needsLocationPermission: needsLocationPermission
        )
    }

    /// End all activities then create a new one (prevents orphans)
    private func endAllActivitiesAndCreate(
        clientName: String,
        startedAt: Date,
        todayHoursBase: Double,
        weekHoursBase: Double,
        geofenceName: String?,
        needsLocationPermission: Bool
    ) {
        guard #available(iOS 16.2, *) else { return }

        // Clear our reference immediately
        currentActivity = nil
        currentGeofenceName = nil

        Task {
            // End ALL activities for this app
            for activity in Activity<KnuckleTimerActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            // Now create the new activity on main actor
            await MainActor.run {
                createActivity(
                    clientName: clientName,
                    startedAt: startedAt,
                    todayHoursBase: todayHoursBase,
                    weekHoursBase: weekHoursBase,
                    geofenceName: geofenceName,
                    needsLocationPermission: needsLocationPermission
                )
            }
        }
    }

    /// Create a new activity (internal helper)
    private func createActivity(
        clientName: String,
        startedAt: Date,
        todayHoursBase: Double,
        weekHoursBase: Double,
        geofenceName: String?,
        needsLocationPermission: Bool
    ) {
        guard #available(iOS 16.2, *) else { return }

        // Check if Live Activities are enabled at the system level
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // After an app relaunch, the system may still be showing the activity
        // from the previous process — adopt it instead of creating a duplicate
        let existingActivities = Activity<KnuckleTimerActivityAttributes>.activities
        if let match = existingActivities.first(where: {
            $0.attributes.clientName == clientName && $0.attributes.geofenceName == geofenceName
        }) {
            currentActivity = match
            currentGeofenceName = geofenceName
            updateActivity(todayHoursBase: todayHoursBase, weekHoursBase: weekHoursBase)

            // End any strays beyond the adopted one
            let strays = existingActivities.filter { $0.id != match.id }
            if !strays.isEmpty {
                Task {
                    for activity in strays {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                }
            }
            return
        }

        // Stale activities from a previous launch with different attributes —
        // end them before creating the new one
        for activity in existingActivities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        // Track current geofence name
        currentGeofenceName = geofenceName

        let attributes = KnuckleTimerActivityAttributes(
            clientName: clientName,
            startedAt: startedAt,
            geofenceName: geofenceName,
            needsLocationPermission: needsLocationPermission
        )
        let state = KnuckleTimerActivityAttributes.ContentState(
            placeholder: false,
            todayHoursBase: todayHoursBase,
            weekHoursBase: weekHoursBase
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            // Failed to start Live Activity
        }
    }

    /// Update the Live Activity with new hours data
    func updateActivity(todayHoursBase: Double, weekHoursBase: Double) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity else { return }

        let state = KnuckleTimerActivityAttributes.ContentState(
            placeholder: false,
            todayHoursBase: todayHoursBase,
            weekHoursBase: weekHoursBase
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// End all Live Activities for this app
    func endActivity() {
        // Sync home screen widget: fold the finished timer's elapsed time
        // into the hour bases so the idle widget shows correct totals.
        // Skip if already idle — endActivity runs on every idle refresh.
        var widgetState = TimerWidgetState.load()
        if widgetState.isTracking {
            if let startedAt = widgetState.startedAt {
                let elapsedHours = Date().timeIntervalSince(startedAt) / 3600
                widgetState.todayHoursBase += elapsedHours
                widgetState.weekHoursBase += elapsedHours
            }
            widgetState.isTracking = false
            widgetState.clientName = nil
            widgetState.geofenceName = nil
            widgetState.startedAt = nil
            widgetState.updatedAt = Date()
            widgetState.save()
        }

        guard #available(iOS 16.2, *) else { return }

        // Clear our reference immediately
        currentActivity = nil
        currentGeofenceName = nil

        // End ALL activities (prevents orphans)
        Task {
            for activity in Activity<KnuckleTimerActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Check if there's a running activity and sync with timer state
    /// - Parameters:
    ///   - timer: The running timer (or nil if not running)
    ///   - todayHoursBase: Hours tracked today BEFORE the current timer started
    ///   - weekHoursBase: Hours tracked this week BEFORE the current timer started
    ///   - geofenceName: Current geofence name (nil = manual tracking)
    ///   - needsLocationPermission: Whether location permission is needed
    func syncWithTimer(
        _ timer: RunningTimer?,
        todayHoursBase: Double = 0,
        weekHoursBase: Double = 0,
        geofenceName: String? = nil,
        needsLocationPermission: Bool = false
    ) {
        if let timer = timer {
            // Timer is running, ensure activity is active
            startActivity(
                clientName: "\(timer.projectName) - \(timer.taskName)",
                startedAt: timer.startedAt,
                todayHoursBase: todayHoursBase,
                weekHoursBase: weekHoursBase,
                geofenceName: geofenceName,
                needsLocationPermission: needsLocationPermission
            )
        } else {
            // No timer running, end any activity
            endActivity()
        }
    }
}
