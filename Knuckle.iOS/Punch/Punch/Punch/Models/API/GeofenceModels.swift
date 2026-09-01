import Foundation

struct Geofence: Identifiable, Codable {
    let id: UUID
    let clientId: UUID
    let clientName: String
    let name: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Int
    let isActive: Bool
    let createdAt: Date
}

struct UpdateGeofenceRequest: Encodable {
    let clientId: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Int
    let isActive: Bool
}

struct CreateGeofenceRequest: Encodable {
    let clientId: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Int
    let isActive: Bool
}
