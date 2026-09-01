//
//  GeofenceFormViewModel.swift
//  Punch
//
//  View model for creating/editing geofences with Harvest project/task
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
class GeofenceFormViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var radiusMeters: Int = 100
    @Published var isActive: Bool = true
    @Published var defaultNote: String = ""

    // Harvest project/task selection
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var tasks: [ProjectTask] = []
    @Published var selectedTask: ProjectTask?

    @Published var isLoading = false
    @Published var error: String?

    let geofenceId: UUID?
    let isEditing: Bool

    private let harvestService = HarvestService.shared
    private let geofenceRepository = GeofenceRepository.shared

    init(geofence: LocalGeofence? = nil) {
        self.geofenceId = geofence?.id
        self.isEditing = geofence != nil

        if let geofence = geofence {
            self.name = geofence.name
            self.latitude = geofence.latitude
            self.longitude = geofence.longitude
            self.radiusMeters = Int(geofence.radiusMeters)
            self.isActive = geofence.isActive
            self.defaultNote = geofence.defaultNote ?? ""
            // Project/task will be loaded in loadData()
        } else {
            // Default to current location if available
            if let location = LocationService.shared.currentLocation {
                self.latitude = location.coordinate.latitude
                self.longitude = location.coordinate.longitude
            }
        }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedProject != nil &&
        selectedTask != nil &&
        latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180 &&
        radiusMeters >= 1 && radiusMeters <= 100_000
    }

    /// Check if this geofence would overlap with any existing geofences
    func checkForOverlaps() -> LocalGeofence? {
        let existingGeofences = geofenceRepository.geofences.filter { $0.id != geofenceId }

        for existing in existingGeofences {
            let distance = calculateDistance(
                lat1: latitude, lon1: longitude,
                lat2: existing.latitude, lon2: existing.longitude
            )
            let combinedRadius = Double(radiusMeters) + Double(existing.radiusMeters)

            if distance < combinedRadius {
                return existing // Found an overlap
            }
        }
        return nil // No overlaps
    }

    /// Calculate distance between two coordinates in meters using Haversine formula
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371000.0 // meters

        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    func loadData() async {
        isLoading = true

        do {
            // Load projects from Harvest
            projects = try await harvestService.getProjects()

            // If editing, find and select the existing project/task
            if isEditing, let id = geofenceId, let geofence = geofenceRepository.getGeofence(id: id) {
                selectedProject = projects.first { $0.id == geofence.harvestProjectId }

                if let project = selectedProject {
                    tasks = try await harvestService.getTasks(forProjectId: project.id)
                    selectedTask = tasks.first { $0.id == geofence.harvestTaskId }
                }
            } else if let firstProject = projects.first {
                // Auto-select first project
                selectedProject = firstProject
                tasks = try await harvestService.getTasks(forProjectId: firstProject.id)
                selectedTask = tasks.first
            }
        } catch {
            self.error = "Failed to load projects"
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
        // Enforce geofence limit for new geofences (defense in depth — UI should prevent this)
        if !isEditing && geofenceRepository.geofences.count >= LocationService.maxGeofences {
            error = "iOS allows a maximum of \(LocationService.maxGeofences) geofences."
            return false
        }

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Name is required"
            return false
        }

        guard let project = selectedProject else {
            error = "Please select a project"
            return false
        }

        guard let task = selectedTask else {
            error = "Please select a task"
            return false
        }

        guard latitude >= -90 && latitude <= 90 else {
            error = "Latitude must be between -90 and 90"
            return false
        }

        guard longitude >= -180 && longitude <= 180 else {
            error = "Longitude must be between -180 and 180"
            return false
        }

        guard radiusMeters >= 1 && radiusMeters <= 100_000 else {
            error = "Radius must be between 1 and 100,000 meters"
            return false
        }

        // Check for overlapping geofences
        if let overlappingGeofence = checkForOverlaps() {
            error = "This geofence would overlap with \"\(overlappingGeofence.name)\". Overlapping geofences can cause timer conflicts."
            return false
        }

        isLoading = true
        error = nil

        do {
            let geofence = LocalGeofence(
                id: geofenceId ?? UUID(),
                name: name.trimmingCharacters(in: .whitespaces),
                latitude: latitude,
                longitude: longitude,
                radiusMeters: Int32(radiusMeters),
                isActive: isActive,
                harvestProjectId: project.id,
                harvestProjectName: project.name,
                harvestTaskId: task.id,
                harvestTaskName: task.name,
                defaultNote: defaultNote.trimmingCharacters(in: .whitespaces).isEmpty ? nil : defaultNote.trimmingCharacters(in: .whitespaces)
            )

            if isEditing {
                try await geofenceRepository.updateGeofence(geofence)
            } else {
                _ = try await geofenceRepository.createGeofence(geofence)
            }

            // Generate map snapshot for the geofence background
            await GeofenceSnapshotService.shared.generateSnapshot(
                geofenceId: geofence.id,
                latitude: geofence.latitude,
                longitude: geofence.longitude,
                radiusMeters: Int(geofence.radiusMeters)
            )

            isLoading = false
            return true
        } catch {
            self.error = "Failed to save geofence"
        }

        isLoading = false
        return false
    }

    func delete() async -> Bool {
        guard let id = geofenceId else { return false }

        isLoading = true
        error = nil

        do {
            try await geofenceRepository.deleteGeofence(id)
            // Clean up the cached snapshot
            await GeofenceSnapshotService.shared.deleteSnapshot(for: id)
            isLoading = false
            return true
        } catch {
            self.error = "Failed to delete geofence"
        }

        isLoading = false
        return false
    }
}
