//
//  TimerWidgetState.swift
//  Punch
//
//  Snapshot of timer state shared with the home screen widget via App Group.
//  Shared between main app and widget extension.
//  In Xcode, ensure this file's Target Membership includes BOTH targets.
//

import Foundation
import WidgetKit

public struct TimerWidgetState: Codable {
    public var isTracking: Bool
    // Display name ("Project - Task"), nil when idle
    public var clientName: String?
    // Current geofence name (nil = manual tracking)
    public var geofenceName: String?
    public var startedAt: Date?
    // Hours tracked today/this week BEFORE the current timer started
    public var todayHoursBase: Double
    public var weekHoursBase: Double
    public var needsLocationPermission: Bool
    public var updatedAt: Date

    public init(
        isTracking: Bool,
        clientName: String? = nil,
        geofenceName: String? = nil,
        startedAt: Date? = nil,
        todayHoursBase: Double = 0,
        weekHoursBase: Double = 0,
        needsLocationPermission: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.isTracking = isTracking
        self.clientName = clientName
        self.geofenceName = geofenceName
        self.startedAt = startedAt
        self.todayHoursBase = todayHoursBase
        self.weekHoursBase = weekHoursBase
        self.needsLocationPermission = needsLocationPermission
        self.updatedAt = updatedAt
    }

    // MARK: - Pill State (mirrors KnuckleTimerActivityAttributes)

    public enum PillState {
        case idle             // Gray - no timer running
        case manual           // Gray - timer running but not in a geofence
        case geofence         // Green - inside a geofence
        case needsPermission  // Red - has geofences but needs location permission
    }

    public var pillState: PillState {
        if needsLocationPermission {
            return .needsPermission
        }
        guard isTracking else { return .idle }
        return geofenceName != nil ? .geofence : .manual
    }

    public var pillText: String {
        switch pillState {
        case .idle:
            return "Idle"
        case .manual:
            return "Manual"
        case .geofence:
            return geofenceName ?? "Geofence"
        case .needsPermission:
            return "Needs Permission"
        }
    }

    // MARK: - App Group Persistence

    private static let appGroupID = "group.com.paulmignard.Knuckle2"
    private static let storageKey = "timerWidgetState"

    public static func load() -> TimerWidgetState {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(TimerWidgetState.self, from: data) else {
            return TimerWidgetState(isTracking: false)
        }
        return state
    }

    /// Persist to the App Group and refresh the home screen widget
    public func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
