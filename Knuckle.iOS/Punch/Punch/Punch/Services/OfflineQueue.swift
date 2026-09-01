//
//  OfflineQueue.swift
//  Punch
//
//  Persistent offline queue for geofence timer events.
//  Events are stamped with createdAt at enqueue time and replayed using
//  those timestamps, so sessions recovered after an outage record the
//  hours that were actually worked — not the time the replay happened.
//

import Foundation

actor OfflineQueue {
    static let shared = OfflineQueue()

    private var queue: [QueuedEvent] = []
    private let fileURL: URL
    private var isProcessing = false
    /// True when the queue file existed but couldn't be read (e.g., the app
    /// was relaunched in the background before first unlock after a reboot).
    /// While set, saves are suppressed so the unread events aren't destroyed.
    private var loadFailed = false

    /// A lone "start" fresher than this replays as a running timer as-is;
    /// older ones get the real arrival time appended to the notes.
    private static let freshEventThreshold: TimeInterval = 5 * 60
    /// Lone events older than this are unrecoverable and dropped.
    /// Start+stop pairs are exempt — they replay as completed entries at any age.
    private static let maxLoneEventAge: TimeInterval = 48 * 60 * 60
    private static let maxRetries = 10

    struct QueuedEvent: Codable, Identifiable {
        let id: UUID
        let createdAt: Date
        var retryCount: Int
        let harvestEvent: HarvestOfflineEvent?
    }

    struct HarvestOfflineEvent: Codable {
        let projectId: Int64
        let taskId: Int64
        let eventType: String  // "start" or "stop"
        let notes: String?
        // Set when the geofence's project couldn't be read at event time
        // (locked device); resolved from CoreData during replay.
        let geofenceId: UUID?
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("offline_queue.json")

        // Load queue from disk (must be done inline since self isn't fully initialized yet)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let data = try? Data(contentsOf: fileURL),
               let loaded = try? JSONDecoder().decode([QueuedEvent].self, from: data) {
                queue = loaded
            } else {
                loadFailed = true
            }
        }
    }

    var pendingCount: Int {
        queue.count
    }

    @discardableResult
    func enqueueHarvestEvent(
        projectId: Int64,
        taskId: Int64,
        eventType: String,
        notes: String?
    ) -> UUID {
        reloadIfNeeded()
        let event = QueuedEvent(
            id: UUID(),
            createdAt: Date(),
            retryCount: 0,
            harvestEvent: HarvestOfflineEvent(
                projectId: projectId,
                taskId: taskId,
                eventType: eventType,
                notes: notes,
                geofenceId: nil
            )
        )
        queue.append(event)
        saveQueue()
        return event.id
    }

    /// Queue an event by geofence ID alone, for when the geofence's Harvest
    /// project/task can't be read (CoreData unavailable before first unlock).
    /// Resolved against the repository at replay time.
    func enqueueGeofenceEvent(geofenceId: UUID, eventType: String) {
        reloadIfNeeded()
        let event = QueuedEvent(
            id: UUID(),
            createdAt: Date(),
            retryCount: 0,
            harvestEvent: HarvestOfflineEvent(
                projectId: 0,
                taskId: 0,
                eventType: eventType,
                notes: nil,
                geofenceId: geofenceId
            )
        )
        queue.append(event)
        saveQueue()
    }

    func remove(id: UUID) {
        queue.removeAll { $0.id == id }
        saveQueue()
    }

    func clearQueue() {
        queue.removeAll()
        loadFailed = false
        saveQueue()
    }

    // MARK: - Replay

    func processQueue() async {
        // Actors are reentrant: this is called from scene activation, geofence
        // handling, and settings — only one replay may run at a time
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        reloadIfNeeded()
        guard !queue.isEmpty else { return }

        var toRemove: [UUID] = []
        var eligible: [QueuedEvent] = []

        for event in queue {
            guard event.harvestEvent != nil else {
                toRemove.append(event.id)  // legacy/unknown event shape
                continue
            }
            if event.retryCount > Self.maxRetries {
                toRemove.append(event.id)
                continue
            }
            eligible.append(event)
        }

        // Pair each start with the next stop (FIFO) so recovered sessions
        // replay as completed entries spanning the actual worked interval
        enum ReplayAction {
            case session(start: QueuedEvent, stop: QueuedEvent)
            case loneStart(QueuedEvent)
            case loneStop(QueuedEvent)
        }
        var actions: [ReplayAction] = []
        var pendingStart: QueuedEvent?
        for event in eligible {
            if event.harvestEvent?.eventType == "start" {
                if let start = pendingStart {
                    actions.append(.loneStart(start))
                }
                pendingStart = event
            } else {
                if let start = pendingStart {
                    actions.append(.session(start: start, stop: event))
                    pendingStart = nil
                } else {
                    actions.append(.loneStop(event))
                }
            }
        }
        if let start = pendingStart {
            actions.append(.loneStart(start))
        }

        for action in actions {
            let events: [QueuedEvent]
            let handled: Bool
            switch action {
            case .session(let start, let stop):
                events = [start, stop]
                handled = await replaySession(start: start, stop: stop)
            case .loneStart(let event):
                events = [event]
                handled = isExpired(event) ? true : await replayStart(event)
            case .loneStop(let event):
                events = [event]
                handled = isExpired(event) ? true : await replayStop(event)
            }

            if handled {
                toRemove.append(contentsOf: events.map(\.id))
            } else {
                for event in events {
                    if let index = queue.firstIndex(where: { $0.id == event.id }) {
                        queue[index].retryCount += 1
                    }
                }
            }
        }

        queue.removeAll { toRemove.contains($0.id) }
        saveQueue()
    }

    private func isExpired(_ event: QueuedEvent) -> Bool {
        event.createdAt < Date().addingTimeInterval(-Self.maxLoneEventAge)
    }

    /// Replay a start+stop pair as a completed, backdated time entry
    private func replaySession(start: QueuedEvent, stop: QueuedEvent) async -> Bool {
        guard let resolved = await resolveHarvestEvent(start.harvestEvent) else {
            return true  // geofence no longer exists — drop
        }

        let hours = max(stop.createdAt.timeIntervalSince(start.createdAt) / 3600, 1.0 / 60.0)
        let input = CreateEntryInput(
            projectId: resolved.projectId,
            taskId: resolved.taskId,
            spentDate: start.createdAt,
            hours: (hours * 100).rounded() / 100,
            notes: resolved.notes
        )

        do {
            _ = try await HarvestService.shared.createEntry(input)
            GeofenceLogger.shared.logQueue("Recovered offline session: \(String(format: "%.2f", hours))h")
            return true
        } catch {
            return shouldDropAfter(error)
        }
    }

    private func replayStart(_ event: QueuedEvent) async -> Bool {
        guard let resolved = await resolveHarvestEvent(event.harvestEvent) else {
            return true
        }

        var notes = resolved.notes
        if Date().timeIntervalSince(event.createdAt) > Self.freshEventThreshold {
            // The timer starts now, late — record the real arrival so the
            // user can correct the entry in Harvest
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let arrival = formatter.string(from: event.createdAt)
            notes = [notes, "(actual arrival: \(arrival))"].compactMap { $0 }.joined(separator: " ")
        }

        do {
            let input = StartTimerInput(projectId: resolved.projectId, taskId: resolved.taskId, notes: notes)
            _ = try await HarvestService.shared.startTimer(input)
            return true
        } catch {
            return shouldDropAfter(error)
        }
    }

    private func replayStop(_ event: QueuedEvent) async -> Bool {
        do {
            guard let runningTimer = try await HarvestService.shared.getRunningTimer() else {
                return true  // nothing to stop
            }

            let resolved = await resolveHarvestEvent(event.harvestEvent)
            _ = try await HarvestService.shared.stopTimer(entryId: runningTimer.id, notes: resolved?.notes)

            // The exit happened in the past — correct the entry's duration
            let actualHours = event.createdAt.timeIntervalSince(runningTimer.startedAt) / 3600
            if Date().timeIntervalSince(event.createdAt) > Self.freshEventThreshold, actualHours > 0 {
                let update = UpdateEntryInput(
                    projectId: nil,
                    taskId: nil,
                    spentDate: nil,
                    hours: (actualHours * 100).rounded() / 100,
                    notes: nil
                )
                _ = try await HarvestService.shared.updateEntry(id: runningTimer.id, update)
            }
            return true
        } catch {
            return shouldDropAfter(error)
        }
    }

    /// Resolve geofence-keyed events (queued when CoreData was unreadable) to
    /// their Harvest project/task. Returns nil if the geofence no longer exists.
    private func resolveHarvestEvent(_ event: HarvestOfflineEvent?) async -> HarvestOfflineEvent? {
        guard let event = event else { return nil }
        guard event.projectId == 0, let geofenceId = event.geofenceId else { return event }

        if await GeofenceRepository.shared.geofences.isEmpty {
            await GeofenceRepository.shared.loadGeofences()
        }
        guard let geofence = await GeofenceRepository.shared.geofences.first(where: { $0.id == geofenceId }) else {
            return nil
        }

        let isStart = event.eventType == "start"
        return HarvestOfflineEvent(
            projectId: geofence.harvestProjectId,
            taskId: geofence.harvestTaskId,
            eventType: event.eventType,
            notes: isStart
                ? (geofence.defaultNote ?? "Auto-started at \(geofence.name)")
                : "Auto-stopped at \(geofence.name)",
            geofenceId: nil
        )
    }

    /// Whether a replay error means the event should be dropped (true) or
    /// kept for retry (false)
    private func shouldDropAfter(_ error: Error) -> Bool {
        switch error {
        case HarvestAPIError.unauthorized:
            return true  // session is dead; retrying can't succeed
        case HarvestAPIError.httpError(let code, _) where 400..<500 ~= code:
            return true  // client error won't fix itself
        default:
            return false
        }
    }

    // MARK: - Persistence

    /// Retry reading the queue file if the initial load failed (locked
    /// device). Merges disk events with any enqueued since.
    private func reloadIfNeeded() {
        guard loadFailed else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let loaded = try? JSONDecoder().decode([QueuedEvent].self, from: data) else { return }
        let knownIDs = Set(queue.map(\.id))
        queue.insert(contentsOf: loaded.filter { !knownIDs.contains($0.id) }, at: 0)
        loadFailed = false
        saveQueue()
    }

    private func saveQueue() {
        // Never overwrite a file we couldn't read — it still holds queued events
        guard !loadFailed else { return }
        guard let data = try? JSONEncoder().encode(queue) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
