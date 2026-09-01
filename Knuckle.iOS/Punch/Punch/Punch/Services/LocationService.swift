//
//  LocationService.swift
//  Punch
//
//  Location and geofence monitoring service
//

import CoreLocation
import Foundation
import Combine
import UserNotifications
import SwiftUI
import UIKit

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    /// iOS allows at most 20 monitored regions per app
    static let maxGeofences = 20

    private let manager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let harvestService = HarvestService.shared
    private let logger = GeofenceLogger.shared

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentGeofence: Geofence? = nil
    @Published var monitoredGeofences: [Geofence] = []
    @Published var isAppActive: Bool = true

    /// Set once a region event has been handled this launch; the background
    /// wake reconcile stands down when CoreLocation delivered the event itself
    private var handledRegionEventThisLaunch = false
    private var lastReconcileAt = Date.distantPast

    var currentLocation: CLLocation? {
        manager.location
    }

    /// Update current geofence and notify observers
    private func setCurrentGeofence(_ geofence: Geofence?) {
        let changed = currentGeofence?.id != geofence?.id
        currentGeofence = geofence
        if changed {
            NotificationCenter.default.post(name: .geofenceStateChanged, object: nil)
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        // Re-arm the significant-change safety net on every launch — iOS
        // expects apps to restart it after a relaunch to keep getting wake-ups
        if !manager.monitoredRegions.isEmpty {
            manager.startMonitoringSignificantLocationChanges()
        }
        let accuracy = manager.accuracyAuthorization == .fullAccuracy ? "precise" : "REDUCED"
        logger.logAppState("LocationService initialized (auth: \(Self.authDescription(authorizationStatus)), accuracy: \(accuracy), regions: \(manager.monitoredRegions.count))")
    }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private var oneTimeLocationCompletion: ((CLLocation?) -> Void)?

    /// Request a single location update with a completion handler
    func requestOneTimeLocation(completion: @escaping (CLLocation?) -> Void) {
        // If we already have a recent location, use it
        if let location = manager.location,
           Date().timeIntervalSince(location.timestamp) < 30 {
            completion(location)
            return
        }

        // Store completion and request fresh location
        oneTimeLocationCompletion = completion
        manager.requestLocation()
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        notificationCenter.add(request)
    }

    /// Send a notification unless the app UI is visible. Asks UIKit directly:
    /// scenePhase-driven state never updates on a headless background
    /// relaunch (no scene is created), so a stored flag can't be trusted here.
    private func notifyInBackground(title: String, body: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        logger.log("📱 Notifying: \(title)")
        sendNotification(title: title, body: body)
    }

    /// Called by the background-task expiration handler when iOS suspends the
    /// app before a geofence event finished processing.
    func notifyEventInterrupted(eventType: String) {
        notifyInBackground(
            title: "⚠️ Tracking Interrupted",
            body: "iOS cut Knuckle off while \(eventType == "enter" ? "starting" : "stopping") your timer. The event is saved — open the app to finish it."
        )
    }

    func startMonitoring(geofences: [Geofence]) {
        // Stop all existing monitoring
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }

        // Filter to active only, limit to the iOS region monitoring cap
        let activeGeofences = geofences.filter { $0.isActive }.prefix(Self.maxGeofences)

        logger.log("📍 Starting monitoring for \(activeGeofences.count) geofences")

        for fence in activeGeofences {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(
                    latitude: fence.latitude,
                    longitude: fence.longitude
                ),
                radius: CLLocationDistance(fence.radiusMeters),
                identifier: fence.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
            logger.log("📍 Monitoring: \(fence.name) (r=\(fence.radiusMeters)m)")
        }

        // Significant-change monitoring wakes the app (even from terminated)
        // on large moves, backstopping region events iOS fails to deliver
        if activeGeofences.isEmpty {
            manager.stopMonitoringSignificantLocationChanges()
        } else {
            manager.startMonitoringSignificantLocationChanges()
        }

        monitoredGeofences = Array(activeGeofences)

        // Immediately check if we're inside any geofence using current location
        checkCurrentGeofenceState()

        // Also request a fresh location update
        manager.requestLocation()
    }

    /// Check if current location is inside any monitored geofence
    func checkCurrentGeofenceState() {
        guard let location = manager.location else { return }

        let geofence = monitoredGeofences.first { fence in
            let fenceLocation = CLLocation(
                latitude: fence.latitude,
                longitude: fence.longitude
            )
            return location.distance(from: fenceLocation) <= Double(fence.radiusMeters)
        }
        setCurrentGeofence(geofence)
    }

    func stopMonitoring() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        manager.stopMonitoringSignificantLocationChanges()
        monitoredGeofences = []
        setCurrentGeofence(nil)
    }

    // MARK: - Missed-Event Reconciliation

    /// Called when iOS relaunched the app in the background for a location
    /// event. A real region crossing arrives via didEnter/didExitRegion within
    /// moments of launch; when none does, this was a significant-change wake —
    /// use it to check whether a geofence event was missed while terminated.
    func scheduleBackgroundWakeReconcile() {
        let taskID = BackgroundTaskManager.shared.beginTask(named: "WakeReconcile")
        Task { @MainActor in
            // Give a pending region event time to arrive and win
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if self.handledRegionEventThisLaunch {
                BackgroundTaskManager.shared.endTask(taskID)
                return
            }
            self.requestOneTimeLocation { location in
                Task { @MainActor in
                    if let location {
                        self.lastReconcileAt = Date()
                        await self.reconcile(at: location)
                    } else {
                        self.logger.log("🩹 Wake reconcile skipped: no location fix", level: .warning)
                    }
                    BackgroundTaskManager.shared.endTask(taskID)
                }
            }
        }
    }

    /// Throttled reconcile for unsolicited background location updates
    /// (significant-change service) while the app is already running.
    private func maybeReconcile(at location: CLLocation) async {
        guard UIApplication.shared.applicationState != .active else { return }
        guard Date().timeIntervalSince(lastReconcileAt) > 10 * 60 else { return }
        lastReconcileAt = Date()
        await reconcile(at: location)
    }

    /// Compare where we are against what the last known tracking state says
    /// should be happening, and replay the missed geofence event if they
    /// disagree. Runs the normal event flow, so it is idempotent (a start is
    /// skipped when a timer already runs) and sends the usual notifications.
    private func reconcile(at location: CLLocation) async {
        if GeofenceRepository.shared.geofences.isEmpty {
            await GeofenceRepository.shared.loadGeofences()
        }
        let fences = GeofenceRepository.shared.geofences.filter { $0.isActive }
        guard !fences.isEmpty else { return }

        let inside = fences.first { fence in
            let fenceLocation = CLLocation(latitude: fence.latitude, longitude: fence.longitude)
            return location.distance(from: fenceLocation) <= Double(fence.radiusMeters)
        }

        // Cheap local screen before any API call: the widget snapshot is the
        // last state this app wrote, so agreement means nothing was missed
        let lastKnown = TimerWidgetState.load()
        let suspectMissedEnter = inside != nil && !lastKnown.isTracking
        let suspectMissedExit = inside == nil && lastKnown.isTracking && lastKnown.geofenceName != nil
        guard suspectMissedEnter || suspectMissedExit else { return }

        let taskID = BackgroundTaskManager.shared.beginTask(named: "GeofenceReconcile")
        defer { BackgroundTaskManager.shared.endTask(taskID) }

        do {
            let running = try await harvestService.getRunningTimer()

            if suspectMissedEnter, running == nil, let fence = inside {
                logger.log("🩹 Reconcile: inside \(fence.name) with no timer — recovering missed ENTER", level: .warning)
                await handleGeofenceEvent(geofenceId: fence.id, eventType: "enter")
            } else if suspectMissedExit, let running, isAutoStarted(running, fences: fences) {
                if let fence = fences.first(where: { $0.harvestProjectId == running.projectId }) {
                    logger.log("🩹 Reconcile: away from all fences with auto timer running — recovering missed EXIT", level: .warning)
                    await handleGeofenceEvent(geofenceId: fence.id, eventType: "exit")
                } else {
                    notifyInBackground(
                        title: "⚠️ Timer Still Running",
                        body: "You left your tracked location but a timer is still running. Open Knuckle to stop it."
                    )
                }
            }
        } catch {
            logger.logAPIError("reconcile getRunningTimer", error: error)
        }
    }

    /// Whether a running timer looks like one this app started from a
    /// geofence — never auto-stop a timer the user started by hand.
    private func isAutoStarted(_ timer: RunningTimer, fences: [LocalGeofence]) -> Bool {
        guard let notes = timer.notes else { return false }
        if notes.hasPrefix("Auto-started at") { return true }
        return fences.contains { $0.harvestProjectId == timer.projectId && $0.defaultNote == notes }
    }

    private static func authDescription(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "DENIED"
        case .authorizedAlways: return "always"
        case .authorizedWhenInUse: return "whileUsing"
        @unknown default: return "unknown"
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            let previous = self.authorizationStatus
            self.authorizationStatus = status
            self.logger.logAppState("Location authorization: \(Self.authDescription(status))")

            // A live downgrade from Always kills background geofencing — iOS
            // does this silently (e.g., provisional Always expiring, or the
            // periodic background-usage prompt). Tell the user immediately.
            if previous == .authorizedAlways, status != .authorizedAlways,
               !self.manager.monitoredRegions.isEmpty {
                self.logger.log("❌ Always authorization lost — background geofencing disabled", level: .error)
                self.sendNotification(
                    title: "⚠️ Background Tracking Off",
                    body: "Knuckle no longer has \"Always\" location access, so automatic tracking has stopped. Open Settings to re-enable it."
                )
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let geofenceId = UUID(uuidString: region.identifier) else { return }

        // Start background task IMMEDIATELY before any async work. If iOS
        // expires it mid-flight the API call dies with it — surface that
        // instead of failing silently (the event stays queued for replay).
        let taskID = BackgroundTaskManager.shared.beginTask(named: "GeofenceEnter-\(region.identifier)") {
            Task { @MainActor in
                LocationService.shared.notifyEventInterrupted(eventType: "enter")
            }
        }

        Task {
            await handleGeofenceEvent(geofenceId: geofenceId, eventType: "enter", backgroundTaskID: taskID)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let geofenceId = UUID(uuidString: region.identifier) else { return }

        // Start background task IMMEDIATELY before any async work
        let taskID = BackgroundTaskManager.shared.beginTask(named: "GeofenceExit-\(region.identifier)") {
            Task { @MainActor in
                LocationService.shared.notifyEventInterrupted(eventType: "exit")
            }
        }

        Task {
            await handleGeofenceEvent(geofenceId: geofenceId, eventType: "exit", backgroundTaskID: taskID)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            // Call one-time location completion if pending
            var wasExplicitRequest = false
            if let completion = self.oneTimeLocationCompletion {
                self.oneTimeLocationCompletion = nil
                wasExplicitRequest = true
                completion(location)
            }

            // Determine which geofence we're in (if any)
            let geofence = self.monitoredGeofences.first { fence in
                let fenceLocation = CLLocation(
                    latitude: fence.latitude,
                    longitude: fence.longitude
                )
                return location.distance(from: fenceLocation) <= Double(fence.radiusMeters)
            }
            self.setCurrentGeofence(geofence)

            // Unsolicited updates in the background come from the
            // significant-change service — a chance to catch missed events
            if !wasExplicitRequest {
                await self.maybeReconcile(at: location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        GeofenceLogger.shared.log("📍 Location error: \(error.localizedDescription)", level: .warning)
        // Location errors are expected when GPS signal is weak
        Task { @MainActor in
            // Call one-time location completion with nil on error
            if let completion = self.oneTimeLocationCompletion {
                self.oneTimeLocationCompletion = nil
                completion(nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        let regionName = region?.identifier ?? "unknown"
        GeofenceLogger.shared.log("❌ Monitoring failed for \(regionName): \(error.localizedDescription)", level: .error)
    }

    private func handleGeofenceEvent(geofenceId: UUID, eventType: String, backgroundTaskID: UIBackgroundTaskIdentifier = .invalid) async {
        handledRegionEventThisLaunch = true

        // Log the event
        if eventType == "enter" {
            logger.logEnter(geofenceId.uuidString)
        } else {
            logger.logExit(geofenceId.uuidString)
        }

        // Try to find geofence in monitored list
        var geofence = monitoredGeofences.first { $0.id == geofenceId }

        // If not found (app launched in background), fetch from CoreData
        if geofence == nil {
            logger.log("📍 Geofence not in memory, loading from CoreData...")
            await GeofenceRepository.shared.loadGeofences()
            let localGeofences = GeofenceRepository.shared.geofences

            if let localGeofence = localGeofences.first(where: { $0.id == geofenceId }) {
                // Convert to Geofence for compatibility
                geofence = Geofence(
                    id: localGeofence.id,
                    clientId: UUID(),
                    clientName: localGeofence.harvestProjectName,
                    name: localGeofence.name,
                    latitude: localGeofence.latitude,
                    longitude: localGeofence.longitude,
                    radiusMeters: Int(localGeofence.radiusMeters),
                    isActive: localGeofence.isActive,
                    createdAt: localGeofence.createdAt
                )
                logger.log("📍 Found geofence: \(localGeofence.name)")
            } else {
                logger.log("❌ Geofence not found in CoreData: \(geofenceId)", level: .error)
            }
        }

        // Get geofence name for notification
        let geofenceName = geofence?.name ?? "Location"

        // Update current geofence state IMMEDIATELY (before API call)
        if eventType == "enter" {
            setCurrentGeofence(geofence)
            logger.log("📍 Set currentGeofence = \(geofenceName)")
        } else {
            if self.currentGeofence?.id == geofenceId {
                setCurrentGeofence(nil)
                logger.log("📍 Cleared currentGeofence")
            }
        }

        // Notifications are sent from handleHarvestTimerEvent once the
        // outcome is known — a "Timer Started" banner before the API call
        // would lie whenever the call fails.

        // Notify dashboard to refresh
        NotificationCenter.default.post(name: .timerStateChanged, object: nil)

        // Process any previously queued offline events before the new one
        await OfflineQueue.shared.processQueue()

        // Now make the Harvest API call
        await handleHarvestTimerEvent(geofenceId: geofenceId, eventType: eventType, backgroundTaskID: backgroundTaskID)
    }

    private func handleHarvestTimerEvent(geofenceId: UUID, eventType: String, backgroundTaskID: UIBackgroundTaskIdentifier = .invalid) async {
        let queueEventType = eventType == "enter" ? "start" : "stop"

        // Get the local geofence with Harvest project/task info
        guard let localGeofence = GeofenceRepository.shared.geofences.first(where: { $0.id == geofenceId }) else {
            // Geofence data unreadable (e.g., relaunched before first unlock
            // after a reboot) — queue by geofence ID; resolved at replay time
            logger.log("❌ No local geofence found — queueing event for replay", level: .error)
            await OfflineQueue.shared.enqueueGeofenceEvent(geofenceId: geofenceId, eventType: queueEventType)
            notifyInBackground(
                title: "⚠️ Timer Not \(eventType == "enter" ? "Started" : "Stopped")",
                body: "Knuckle couldn't read its geofence data. The event was saved — open the app to finish it or track manually."
            )
            BackgroundTaskManager.shared.endTask(backgroundTaskID)
            return
        }

        // Queue the event BEFORE the API call so it survives background-task
        // expiration with its real timestamp; removed below once handled
        let note = eventType == "enter"
            ? (localGeofence.defaultNote ?? "Auto-started at \(localGeofence.name)")
            : "Auto-stopped at \(localGeofence.name)"
        let queuedEventID = await OfflineQueue.shared.enqueueHarvestEvent(
            projectId: localGeofence.harvestProjectId,
            taskId: localGeofence.harvestTaskId,
            eventType: queueEventType,
            notes: note
        )

        do {
            if eventType == "enter" {
                logger.logAPIStart("getRunningTimer (check existing)")

                // Check if timer is already running
                if try await harvestService.getRunningTimer() != nil {
                    logger.log("⚠️ Timer already running, skipping start", level: .warning)
                    notifyInBackground(
                        title: "👊 Already Tracking",
                        body: "Arrived at \(localGeofence.name) — a timer was already running."
                    )
                } else {
                    logger.logAPIStart("startTimer for \(localGeofence.name)")

                    let input = StartTimerInput(
                        projectId: localGeofence.harvestProjectId,
                        taskId: localGeofence.harvestTaskId,
                        notes: note
                    )
                    let timer = try await harvestService.startTimer(input)

                    logger.logAPISuccess("startTimer", details: "Entry ID: \(timer.id)")

                    // Sync widget state and try to start a Live Activity. On a
                    // headless background relaunch iOS refuses Activity.request
                    // (foreground-only) — only the home screen widget updates.
                    LiveActivityManager.shared.startActivity(
                        clientName: "\(timer.projectName) - \(timer.taskName)",
                        startedAt: timer.startedAt,
                        geofenceName: localGeofence.name
                    )

                    notifyInBackground(
                        title: "👊 Timer Started",
                        body: "Tracking \(localGeofence.harvestProjectName) at \(localGeofence.name)"
                    )
                }
            } else {
                logger.logAPIStart("getRunningTimer (for stop)")

                if let runningTimer = try await harvestService.getRunningTimer() {
                    logger.logAPIStart("stopTimer for entry \(runningTimer.id)")

                    let stoppedEntry = try await harvestService.stopTimer(
                        entryId: runningTimer.id,
                        notes: note
                    )

                    logger.logAPISuccess("stopTimer", details: "Duration: \(stoppedEntry.hours)h")

                    LiveActivityManager.shared.endActivity()

                    notifyInBackground(
                        title: "👊 Timer Stopped",
                        body: "Stopped \(localGeofence.harvestProjectName) • Left \(localGeofence.name)"
                    )
                } else {
                    logger.log("⚠️ No running timer to stop", level: .warning)
                    notifyInBackground(
                        title: "⚠️ Nothing to Stop",
                        body: "Left \(localGeofence.name) but no timer was running. If you worked there, add the entry manually."
                    )
                }
            }

            // Handled — remove from the queue
            await OfflineQueue.shared.remove(id: queuedEventID)
        } catch {
            logger.logAPIError(eventType == "enter" ? "startTimer" : "stopTimer", error: error)
            logger.logQueue("\(eventType) event remains queued for retry")

            let action = eventType == "enter"
                ? "start your timer at \(localGeofence.name)"
                : "stop your timer after leaving \(localGeofence.name)"
            notifyInBackground(
                title: "⚠️ Timer Not \(eventType == "enter" ? "Started" : "Stopped")",
                body: "Knuckle couldn't \(action) — Harvest was unreachable. The event is saved for retry; open the app to track manually."
            )
        }

        BackgroundTaskManager.shared.endTask(backgroundTaskID)
    }
}

// MARK: - Helper Types

struct GeofenceTimerEvent: Codable {
    let geofenceId: UUID
    let projectId: Int64
    let taskId: Int64
    let eventType: String
    let timestamp: Date
}

extension Notification.Name {
    static let timerStateChanged = Notification.Name("timerStateChanged")
    static let geofenceStateChanged = Notification.Name("geofenceStateChanged")
}
