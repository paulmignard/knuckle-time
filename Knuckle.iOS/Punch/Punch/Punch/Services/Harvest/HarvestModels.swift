//
//  HarvestModels.swift
//  Punch
//
//  Harvest API response and request models
//

import Foundation

// MARK: - OAuth Models

/// Response from Harvest API directly (snake_case)
struct HarvestOAuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

/// Response from auth proxy (camelCase)
struct AuthProxyTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
}

/// Request to auth proxy for token exchange
struct AuthProxyTokenRequest: Codable {
    let code: String
    let redirectUri: String
}

/// Request to auth proxy for token refresh
struct AuthProxyRefreshRequest: Codable {
    let refreshToken: String
}

struct HarvestAccount: Identifiable, Codable {
    let id: Int64
    let name: String
    let product: String

    enum CodingKeys: String, CodingKey {
        case id, name, product
    }
}

struct HarvestAccountsResponse: Codable {
    let user: HarvestUserInfo
    let accounts: [HarvestAccount]
}

struct HarvestUserInfo: Codable {
    let id: Int64
    let firstName: String
    let lastName: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

// MARK: - Project Models

struct HarvestProjectAssignment: Codable {
    let id: Int64
    let isActive: Bool
    let project: HarvestProject
    let client: HarvestClient?
    let taskAssignments: [HarvestTaskAssignment]

    enum CodingKeys: String, CodingKey {
        case id
        case isActive = "is_active"
        case project
        case client
        case taskAssignments = "task_assignments"
    }
}

struct HarvestProject: Codable {
    let id: Int64
    let name: String
    let code: String?
    let isActive: Bool?  // Not always present in nested responses
    let isBillable: Bool?  // Not always present in nested responses

    enum CodingKeys: String, CodingKey {
        case id, name, code
        case isActive = "is_active"
        case isBillable = "is_billable"
    }
}

struct HarvestClient: Codable {
    let id: Int64
    let name: String
}

struct HarvestTaskAssignment: Codable {
    let id: Int64
    let isActive: Bool
    let isBillable: Bool
    let task: HarvestTask

    enum CodingKeys: String, CodingKey {
        case id
        case isActive = "is_active"
        case isBillable = "billable"  // API uses "billable" not "is_billable"
        case task
    }
}

struct HarvestTask: Codable {
    let id: Int64
    let name: String
}

struct HarvestProjectAssignmentsResponse: Codable {
    let projectAssignments: [HarvestProjectAssignment]
    let perPage: Int
    let totalPages: Int
    let totalEntries: Int
    let page: Int

    enum CodingKeys: String, CodingKey {
        case projectAssignments = "project_assignments"
        case perPage = "per_page"
        case totalPages = "total_pages"
        case totalEntries = "total_entries"
        case page
    }
}

// MARK: - Time Entry Models

struct HarvestTimeEntry: Codable {
    let id: Int64
    let spentDate: String  // "YYYY-MM-DD" format
    let hours: Double
    let hoursWithoutTimer: Double?
    let roundedHours: Double?
    let notes: String?
    let isRunning: Bool
    let isBilled: Bool
    let isLocked: Bool
    let timerStartedAt: Date?
    let startedTime: String?  // "HH:mm" format
    let endedTime: String?    // "HH:mm" format
    let createdAt: Date
    let updatedAt: Date
    let project: HarvestProject
    let task: HarvestTask
    let client: HarvestClient?
    let user: HarvestUserReference?

    enum CodingKeys: String, CodingKey {
        case id
        case spentDate = "spent_date"
        case hours
        case hoursWithoutTimer = "hours_without_timer"
        case roundedHours = "rounded_hours"
        case notes
        case isRunning = "is_running"
        case isBilled = "is_billed"
        case isLocked = "is_locked"
        case timerStartedAt = "timer_started_at"
        case startedTime = "started_time"
        case endedTime = "ended_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case project, task, client, user
    }
}

struct HarvestUserReference: Codable {
    let id: Int64
    let name: String
}

struct HarvestTimeEntriesResponse: Codable {
    let timeEntries: [HarvestTimeEntry]
    let perPage: Int
    let totalPages: Int
    let totalEntries: Int
    let page: Int

    enum CodingKeys: String, CodingKey {
        case timeEntries = "time_entries"
        case perPage = "per_page"
        case totalPages = "total_pages"
        case totalEntries = "total_entries"
        case page
    }
}

// MARK: - Request Models

struct HarvestStartTimerRequest: Encodable {
    let projectId: Int64
    let taskId: Int64
    let spentDate: String  // "YYYY-MM-DD" format
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case taskId = "task_id"
        case spentDate = "spent_date"
        case notes
    }
}

struct HarvestCreateEntryRequest: Encodable {
    let projectId: Int64
    let taskId: Int64
    let spentDate: String  // "YYYY-MM-DD" format
    let hours: Double
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case taskId = "task_id"
        case spentDate = "spent_date"
        case hours
        case notes
    }
}

struct HarvestUpdateEntryRequest: Encodable {
    let projectId: Int64?
    let taskId: Int64?
    let spentDate: String?
    let hours: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case taskId = "task_id"
        case spentDate = "spent_date"
        case hours
        case notes
    }
}

struct HarvestStopTimerRequest: Encodable {
    // Harvest stop endpoint only needs the entry ID in the URL
    // This struct is here for consistency and future extensibility
}

// MARK: - User Models

struct HarvestMe: Codable {
    let id: Int64
    let firstName: String
    let lastName: String
    let email: String
    let timezone: String
    let weeklyCapacity: Int?
    let hasAccessToAllFutureProjects: Bool
    let isContractor: Bool
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email, timezone
        case weeklyCapacity = "weekly_capacity"
        case hasAccessToAllFutureProjects = "has_access_to_all_future_projects"
        case isContractor = "is_contractor"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
