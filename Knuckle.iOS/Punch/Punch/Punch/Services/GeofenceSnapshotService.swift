import Foundation
import MapKit
import UIKit

/// Service for generating and caching satellite map snapshots of geofence locations
actor GeofenceSnapshotService {
    static let shared = GeofenceSnapshotService()

    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("GeofenceSnapshots", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }

    private func cacheURL(for geofenceId: UUID) -> URL {
        cacheDirectory.appendingPathComponent("\(geofenceId.uuidString).jpg")
    }

    /// Get the file URL for a geofence's snapshot (for sharing with widget)
    func snapshotURL(for geofenceId: UUID) -> URL? {
        let url = cacheURL(for: geofenceId)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// Generate and cache a map snapshot for a geofence location
    func generateSnapshot(
        geofenceId: UUID,
        latitude: Double,
        longitude: Double,
        radiusMeters: Int
    ) async {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // Calculate region to show - make it a bit larger than the geofence radius
        let regionRadius = Double(radiusMeters) * 2.5
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: regionRadius,
            longitudinalMeters: regionRadius
        )

        // Configure the snapshot
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 800, height: 600) // Good resolution for background
        options.mapType = .satellite // Satellite imagery looks best
        options.showsBuildings = true

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let image = snapshot.image

            // Convert to JPEG and save to cache
            if let data = image.jpegData(compressionQuality: 0.8) {
                let url = cacheURL(for: geofenceId)
                try data.write(to: url)
            }
        } catch {
            // Silently fail - snapshot is not critical
        }
    }

    /// Load a cached snapshot for a geofence
    func loadSnapshot(for geofenceId: UUID) -> UIImage? {
        let url = cacheURL(for: geofenceId)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    /// Check if a snapshot exists for a geofence
    func hasSnapshot(for geofenceId: UUID) -> Bool {
        let url = cacheURL(for: geofenceId)
        return fileManager.fileExists(atPath: url.path)
    }

    /// Delete a cached snapshot
    func deleteSnapshot(for geofenceId: UUID) {
        let url = cacheURL(for: geofenceId)
        try? fileManager.removeItem(at: url)
    }

    /// Generate snapshots for any geofences that don't have one yet
    func generateMissingSnapshots(for geofences: [Geofence]) async {
        for geofence in geofences {
            if !hasSnapshot(for: geofence.id) {
                await generateSnapshot(
                    geofenceId: geofence.id,
                    latitude: geofence.latitude,
                    longitude: geofence.longitude,
                    radiusMeters: geofence.radiusMeters
                )
            }
        }
    }
}
