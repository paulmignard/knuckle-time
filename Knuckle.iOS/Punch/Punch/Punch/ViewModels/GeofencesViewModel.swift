//
//  GeofencesViewModel.swift
//  Punch
//
//  Geofences view model extracted from SettingsViewModel
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
class GeofencesViewModel: ObservableObject {
    @Published var geofences: [LocalGeofence] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var locationStatus: CLAuthorizationStatus = LocationService.shared.authorizationStatus

    private let geofenceRepository = GeofenceRepository.shared

    init() {
        LocationService.shared.$authorizationStatus
            .receive(on: RunLoop.main)
            .assign(to: &$locationStatus)
    }

    var activeGeofenceCount: Int {
        geofences.filter { $0.isActive }.count
    }

    func refresh() async {
        await fetchGeofences()
    }

    func fetchGeofences() async {
        isLoading = true

        await geofenceRepository.loadGeofences()
        geofences = geofenceRepository.geofences

        isLoading = false

        // Generate map snapshots in the background — don't block the UI
        let snapshotGeofences = geofences
        Task.detached {
            for geofence in snapshotGeofences {
                if await !GeofenceSnapshotService.shared.hasSnapshot(for: geofence.id) {
                    await GeofenceSnapshotService.shared.generateSnapshot(
                        geofenceId: geofence.id,
                        latitude: geofence.latitude,
                        longitude: geofence.longitude,
                        radiusMeters: Int(geofence.radiusMeters)
                    )
                }
            }
        }
    }

    func toggleGeofence(_ geofence: LocalGeofence) async {
        do {
            try await geofenceRepository.toggleGeofence(geofence.id)
            await fetchGeofences()
        } catch {
            self.error = "Failed to update geofence"
        }
    }

    func deleteGeofence(_ id: UUID) async -> Bool {
        isLoading = true
        error = nil

        do {
            try await geofenceRepository.deleteGeofence(id)
            // Clean up the cached snapshot
            await GeofenceSnapshotService.shared.deleteSnapshot(for: id)
            await fetchGeofences()
            isLoading = false
            return true
        } catch {
            self.error = "Failed to delete geofence"
        }

        isLoading = false
        return false
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
