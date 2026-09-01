//
//  KnuckleTimerActivityAttributes.swift
//  Punch
//
//  Shared between main app and widget extension.
//  In Xcode, ensure this file's Target Membership includes BOTH targets.
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct KnuckleTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var placeholder: Bool = false
        // Hours tracked today BEFORE the current timer started (so we can add elapsed time)
        public var todayHoursBase: Double = 0
        // Hours tracked this week BEFORE the current timer started
        public var weekHoursBase: Double = 0

        public init(placeholder: Bool = false, todayHoursBase: Double = 0, weekHoursBase: Double = 0) {
            self.placeholder = placeholder
            self.todayHoursBase = todayHoursBase
            self.weekHoursBase = weekHoursBase
        }
    }

    // Display name (combines project and task for Harvest)
    // Format: "Project - Task" or just project name
    public var clientName: String  // Kept as clientName for API compatibility
    public var startedAt: Date
    public var geofenceName: String?  // Current geofence name (nil = manual start)
    public var needsLocationPermission: Bool  // Has geofences but wrong permissions

    // Convenience property to extract project name
    public var projectName: String {
        let parts = clientName.split(separator: "-", maxSplits: 1)
        return String(parts.first ?? "").trimmingCharacters(in: .whitespaces)
    }

    // Convenience property to extract task name
    public var taskName: String? {
        let parts = clientName.split(separator: "-", maxSplits: 1)
        guard parts.count > 1 else { return nil }
        return String(parts.last ?? "").trimmingCharacters(in: .whitespaces)
    }

    public init(clientName: String, startedAt: Date, geofenceName: String? = nil, needsLocationPermission: Bool = false) {
        self.clientName = clientName
        self.startedAt = startedAt
        self.geofenceName = geofenceName
        self.needsLocationPermission = needsLocationPermission
    }

    // Convenience initializer for project + task
    public init(projectName: String, taskName: String?, startedAt: Date, geofenceName: String? = nil, needsLocationPermission: Bool = false) {
        if let task = taskName {
            self.clientName = "\(projectName) - \(task)"
        } else {
            self.clientName = projectName
        }
        self.startedAt = startedAt
        self.geofenceName = geofenceName
        self.needsLocationPermission = needsLocationPermission
    }

    // MARK: - Pill State

    public enum PillState {
        case manual      // Gray - timer running but not in a geofence
        case geofence    // Green - inside a geofence
        case needsPermission  // Red - has geofences but needs location permission
    }

    public var pillState: PillState {
        if needsLocationPermission {
            return .needsPermission
        }
        return geofenceName != nil ? .geofence : .manual
    }

    public var pillText: String {
        switch pillState {
        case .manual:
            return "Manual"
        case .geofence:
            return geofenceName ?? "Geofence"
        case .needsPermission:
            return "Needs Permission"
        }
    }
}
