import Foundation

struct RunningTimerResponse: Decodable {
    let id: UUID
    let clientId: UUID
    let clientName: String
    let startedAt: Date
    let runningHours: Double
    let notes: String?
    let source: String?  // "manual" or "geofence" - optional for backwards compatibility
}

struct StartTimerRequest: Encodable {
    let clientId: UUID
    let geofenceId: UUID?
    let notes: String?
}

struct StopTimerRequest: Encodable {
    let notes: String?
    let udf1: String?
    let udf2: String?
}

struct GeofenceEventRequest: Encodable {
    let geofenceId: UUID
    let eventType: String  // "enter" or "exit"
    let timestamp: Date
}
