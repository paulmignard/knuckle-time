//
//  GeofenceRepository.swift
//  Punch
//
//  Local geofence CRUD operations using CoreData
//

import Foundation
import CoreData
import Combine

/// Domain model for a local geofence with Harvest project/task
struct LocalGeofence: Identifiable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Int32
    var isActive: Bool
    var harvestProjectId: Int64
    var harvestProjectName: String
    var harvestTaskId: Int64
    var harvestTaskName: String
    var defaultNote: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Int32 = 100,
        isActive: Bool = true,
        harvestProjectId: Int64,
        harvestProjectName: String,
        harvestTaskId: Int64,
        harvestTaskName: String,
        defaultNote: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.isActive = isActive
        self.harvestProjectId = harvestProjectId
        self.harvestProjectName = harvestProjectName
        self.harvestTaskId = harvestTaskId
        self.harvestTaskName = harvestTaskName
        self.defaultNote = defaultNote
        self.createdAt = createdAt
    }
}

@MainActor
final class GeofenceRepository: ObservableObject {
    static let shared = GeofenceRepository()

    private let coreData = CoreDataStack.shared

    @Published private(set) var geofences: [LocalGeofence] = []

    private init() {
        // Load geofences on init
        Task {
            await loadGeofences()
        }
    }

    // MARK: - Fetch

    func loadGeofences() async {
        let context = coreData.viewContext
        let request = NSFetchRequest<CDGeofence>(entityName: "CDGeofence")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDGeofence.createdAt, ascending: false)]

        do {
            let results = try context.fetch(request)
            geofences = results.map { mapToLocalGeofence($0) }
        } catch {
            geofences = []
        }

        // Sync monitoring with LocationService (single source of truth)
        let clGeofences = geofences.map { geofence in
            Geofence(
                id: geofence.id,
                clientId: UUID(),
                clientName: geofence.harvestProjectName,
                name: geofence.name,
                latitude: geofence.latitude,
                longitude: geofence.longitude,
                radiusMeters: Int(geofence.radiusMeters),
                isActive: geofence.isActive,
                createdAt: geofence.createdAt
            )
        }
        LocationService.shared.startMonitoring(geofences: clGeofences)
    }

    func getGeofence(id: UUID) -> LocalGeofence? {
        geofences.first { $0.id == id }
    }

    func getActiveGeofences() -> [LocalGeofence] {
        geofences.filter { $0.isActive }
    }

    // MARK: - Create

    func createGeofence(_ geofence: LocalGeofence) async throws -> LocalGeofence {
        let context = coreData.viewContext

        let cdGeofence = CDGeofence(context: context)
        cdGeofence.id = geofence.id
        cdGeofence.name = geofence.name
        cdGeofence.latitude = geofence.latitude
        cdGeofence.longitude = geofence.longitude
        cdGeofence.radiusMeters = geofence.radiusMeters
        cdGeofence.isActive = geofence.isActive
        cdGeofence.harvestProjectId = geofence.harvestProjectId
        cdGeofence.harvestProjectName = geofence.harvestProjectName
        cdGeofence.harvestTaskId = geofence.harvestTaskId
        cdGeofence.harvestTaskName = geofence.harvestTaskName
        cdGeofence.defaultNote = geofence.defaultNote
        cdGeofence.createdAt = geofence.createdAt

        try coreData.save(context)

        let savedGeofence = mapToLocalGeofence(cdGeofence)
        geofences.insert(savedGeofence, at: 0)

        return savedGeofence
    }

    // MARK: - Update

    func updateGeofence(_ geofence: LocalGeofence) async throws {
        let context = coreData.viewContext

        let request = NSFetchRequest<CDGeofence>(entityName: "CDGeofence")
        request.predicate = NSPredicate(format: "id == %@", geofence.id as CVarArg)

        guard let cdGeofence = try context.fetch(request).first else {
            throw GeofenceRepositoryError.notFound
        }

        cdGeofence.name = geofence.name
        cdGeofence.latitude = geofence.latitude
        cdGeofence.longitude = geofence.longitude
        cdGeofence.radiusMeters = geofence.radiusMeters
        cdGeofence.isActive = geofence.isActive
        cdGeofence.harvestProjectId = geofence.harvestProjectId
        cdGeofence.harvestProjectName = geofence.harvestProjectName
        cdGeofence.harvestTaskId = geofence.harvestTaskId
        cdGeofence.harvestTaskName = geofence.harvestTaskName
        cdGeofence.defaultNote = geofence.defaultNote

        try coreData.save(context)

        // Update local cache
        if let index = geofences.firstIndex(where: { $0.id == geofence.id }) {
            geofences[index] = geofence
        }
    }

    func toggleGeofence(_ id: UUID) async throws {
        guard var geofence = getGeofence(id: id) else {
            throw GeofenceRepositoryError.notFound
        }

        geofence.isActive.toggle()
        try await updateGeofence(geofence)
    }

    // MARK: - Delete

    func deleteGeofence(_ id: UUID) async throws {
        let context = coreData.viewContext

        let request = NSFetchRequest<CDGeofence>(entityName: "CDGeofence")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let cdGeofence = try context.fetch(request).first else {
            throw GeofenceRepositoryError.notFound
        }

        context.delete(cdGeofence)
        try coreData.save(context)

        // Update local cache
        geofences.removeAll { $0.id == id }
    }

    func deleteAllGeofences() async throws {
        let context = coreData.viewContext

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CDGeofence")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        try context.execute(deleteRequest)
        try coreData.save(context)

        geofences.removeAll()
    }

    // MARK: - Helpers

    private func mapToLocalGeofence(_ cdGeofence: CDGeofence) -> LocalGeofence {
        LocalGeofence(
            id: cdGeofence.id ?? UUID(),
            name: cdGeofence.name ?? "",
            latitude: cdGeofence.latitude,
            longitude: cdGeofence.longitude,
            radiusMeters: cdGeofence.radiusMeters,
            isActive: cdGeofence.isActive,
            harvestProjectId: cdGeofence.harvestProjectId,
            harvestProjectName: cdGeofence.harvestProjectName ?? "",
            harvestTaskId: cdGeofence.harvestTaskId,
            harvestTaskName: cdGeofence.harvestTaskName ?? "",
            defaultNote: cdGeofence.defaultNote,
            createdAt: cdGeofence.createdAt ?? Date()
        )
    }
}

// MARK: - Errors

enum GeofenceRepositoryError: LocalizedError {
    case notFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Geofence not found"
        case .saveFailed:
            return "Failed to save geofence"
        }
    }
}
