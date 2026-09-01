//
//  HarvestAPIClient.swift
//  Punch
//
//  HTTP client for Harvest API with Bearer token + Account-Id headers
//

import Foundation

actor HarvestAPIClient {
    static let shared = HarvestAPIClient()

    // MARK: - Configuration

    private static let baseURL = "https://api.harvestapp.com/v2"
    private static let authProxyBaseURL = "https://auth.knuckletime.com"
    static let userAgent = "Knuckle/1.0 iOS"

    // MARK: - Token Storage Keys

    private static let accessTokenKey = "harvest_access_token"
    private static let refreshTokenKey = "harvest_refresh_token"
    private static let accountIdKey = "harvest_account_id"
    private static let userNameKey = "harvest_user_name"
    private static let userEmailKey = "harvest_user_email"
    private static let tokenExpiresAtKey = "harvest_token_expires_at"

    // App Groups for widget sharing
    private static let appGroupID = "group.com.paulmignard.Knuckle2"
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - State

    private var accessToken: String?
    private var refreshToken: String?
    private var accountId: Int64?
    private var userName: String?
    private var userEmail: String?
    private var tokenExpiresAt: Date?
    private var tokensLoaded = false
    private var refreshTask: Task<Bool, Error>?

    init() {}

    // MARK: - Token Management

    private func loadTokensIfNeeded() {
        guard !tokensLoaded else { return }
        tokensLoaded = true

        accessToken = KeychainService.get(Self.accessTokenKey)
        refreshToken = KeychainService.get(Self.refreshTokenKey)

        if let accountIdStr = KeychainService.get(Self.accountIdKey) {
            accountId = Int64(accountIdStr)
        }

        userName = KeychainService.get(Self.userNameKey)
        userEmail = KeychainService.get(Self.userEmailKey)

        // Migrate from UserDefaults to Keychain if needed
        if userName == nil, let legacyName = Self.sharedDefaults?.string(forKey: Self.userNameKey) {
            userName = legacyName
            KeychainService.set(Self.userNameKey, value: legacyName)
            Self.sharedDefaults?.removeObject(forKey: Self.userNameKey)
        }
        if userEmail == nil, let legacyEmail = Self.sharedDefaults?.string(forKey: Self.userEmailKey) {
            userEmail = legacyEmail
            KeychainService.set(Self.userEmailKey, value: legacyEmail)
            Self.sharedDefaults?.removeObject(forKey: Self.userEmailKey)
        }

        if let expiresAtInterval = Self.sharedDefaults?.double(forKey: Self.tokenExpiresAtKey), expiresAtInterval > 0 {
            tokenExpiresAt = Date(timeIntervalSince1970: expiresAtInterval)
        }
    }

    var hasTokens: Bool {
        loadTokensIfNeeded()
        return accessToken != nil && accountId != nil
    }

    var currentAccountId: Int64? {
        loadTokensIfNeeded()
        return accountId
    }

    var currentUserName: String? {
        loadTokensIfNeeded()
        return userName
    }

    var currentUserEmail: String? {
        loadTokensIfNeeded()
        return userEmail
    }

    func setTokens(
        accessToken: String,
        refreshToken: String,
        accountId: Int64,
        userName: String,
        userEmail: String,
        expiresIn: Int
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accountId = accountId
        self.userName = userName
        self.userEmail = userEmail
        self.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        self.tokensLoaded = true

        // Save to Keychain
        KeychainService.set(Self.accessTokenKey, value: accessToken)
        KeychainService.set(Self.refreshTokenKey, value: refreshToken)
        KeychainService.set(Self.accountIdKey, value: String(accountId))

        // Save user info to Keychain
        KeychainService.set(Self.userNameKey, value: userName)
        KeychainService.set(Self.userEmailKey, value: userEmail)
        Self.sharedDefaults?.set(tokenExpiresAt?.timeIntervalSince1970 ?? 0, forKey: Self.tokenExpiresAtKey)
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        accountId = nil
        userName = nil
        userEmail = nil
        tokenExpiresAt = nil
        tokensLoaded = true

        KeychainService.delete(Self.accessTokenKey)
        KeychainService.delete(Self.refreshTokenKey)
        KeychainService.delete(Self.accountIdKey)

        KeychainService.delete(Self.userNameKey)
        KeychainService.delete(Self.userEmailKey)
        Self.sharedDefaults?.removeObject(forKey: Self.tokenExpiresAtKey)
    }

    // MARK: - Token Refresh

    private func shouldRefreshToken() -> Bool {
        guard let expiresAt = tokenExpiresAt else { return false }
        // Refresh if token expires within 5 minutes
        return Date().addingTimeInterval(5 * 60) >= expiresAt
    }

    /// Refresh the access token. Returns false when the session is
    /// definitively dead (refresh token rejected); throws on transient
    /// failures (network, proxy 5xx) so callers don't treat a blip as logout.
    /// Concurrent callers (e.g., two requests hitting 401 at once) share a
    /// single refresh — refresh tokens rotate, so a duplicate refresh with
    /// the stale token would kill the session.
    func refreshAccessToken() async throws -> Bool {
        loadTokensIfNeeded()

        if let existing = refreshTask {
            return try await existing.value
        }

        let task = Task { try await performTokenRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performTokenRefresh() async throws -> Bool {
        guard let refreshToken = refreshToken else { return false }

        guard let url = URL(string: "\(Self.authProxyBaseURL)/auth/refresh") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let refreshRequest = AuthProxyRefreshRequest(refreshToken: refreshToken)
        request.httpBody = try JSONEncoder().encode(refreshRequest)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HarvestAPIError.httpError(0, "Invalid refresh response")
        }

        guard httpResponse.statusCode == 200 else {
            if 400..<500 ~= httpResponse.statusCode {
                return false  // refresh token rejected — session is dead
            }
            throw HarvestAPIError.httpError(httpResponse.statusCode, "Token refresh failed")
        }

        let tokenResponse = try JSONDecoder().decode(AuthProxyTokenResponse.self, from: data)

        // Keep existing accountId, userName, and userEmail
        guard let accountId = self.accountId, let userName = self.userName else {
            return false  // can't persist tokens without account context
        }

        setTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            accountId: accountId,
            userName: userName,
            userEmail: self.userEmail ?? "",
            expiresIn: tokenResponse.expiresIn
        )

        return true
    }

    // MARK: - API Requests

    func request<T: Decodable>(
        method: String,
        path: String,
        body: (any Encodable)? = nil,
        queryParams: [String: String]? = nil,
        isRetry: Bool = false
    ) async throws -> T {
        loadTokensIfNeeded()

        // Check if token needs refresh
        if shouldRefreshToken() {
            _ = try? await refreshAccessToken()
        }

        guard let accessToken = accessToken, let accountId = accountId else {
            throw HarvestAPIError.unauthorized
        }

        // Build URL with query parameters
        guard var components = URLComponents(string: "\(Self.baseURL)/\(path)") else {
            throw HarvestAPIError.httpError(0, "Invalid URL: \(path)")
        }
        if let queryParams = queryParams, !queryParams.isEmpty {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw HarvestAPIError.httpError(0, "Invalid URL: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(String(accountId), forHTTPHeaderField: "Harvest-Account-Id")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HarvestAPIError.httpError(0, "Invalid response")
        }

        // Handle 401 - refresh and retry once
        if httpResponse.statusCode == 401 {
            if !isRetry {
                do {
                    if try await refreshAccessToken() {
                        return try await self.request(method: method, path: path, body: body, queryParams: queryParams, isRetry: true)
                    }
                    // Refresh definitively rejected — the session is dead
                    NotificationCenter.default.post(name: .harvestSessionExpired, object: nil)
                } catch {
                    // Transient refresh failure (network/proxy) — fail this
                    // request without declaring the session dead
                }
            } else {
                // Fresh token still rejected — the session is dead
                NotificationCenter.default.post(name: .harvestSessionExpired, object: nil)
            }
            throw HarvestAPIError.unauthorized
        }

        // Handle other errors
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw HarvestAPIError.httpError(httpResponse.statusCode, message)
        }

        // Handle 204 No Content
        if httpResponse.statusCode == 204 {
            if let empty = HarvestEmptyResponse() as? T {
                return empty
            }
            throw HarvestAPIError.httpError(204, "No content")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Convenience Methods

    func get<T: Decodable>(_ path: String, queryParams: [String: String]? = nil) async throws -> T {
        try await request(method: "GET", path: path, queryParams: queryParams)
    }

    func post<T: Decodable>(_ path: String, body: any Encodable) async throws -> T {
        try await request(method: "POST", path: path, body: body)
    }

    func patch<T: Decodable>(_ path: String, body: (any Encodable)? = nil) async throws -> T {
        try await request(method: "PATCH", path: path, body: body)
    }

    func delete(_ path: String) async throws {
        let _: HarvestEmptyResponse = try await request(method: "DELETE", path: path)
    }
}

// MARK: - Error Types

enum HarvestAPIError: LocalizedError {
    case unauthorized
    case httpError(Int, String)
    case networkError(Error)
    case rateLimited
    case notFound

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please connect to Harvest again."
        case .httpError(let code, let message):
            if code == 429 {
                return "Rate limited. Please wait a moment and try again."
            }
            return "Error \(code): \(message)"
        case .networkError(let error):
            return error.localizedDescription
        case .rateLimited:
            return "Rate limited. Please wait a moment and try again."
        case .notFound:
            return "Resource not found. It may have been deleted."
        }
    }
}

struct HarvestEmptyResponse: Decodable, Sendable {
    nonisolated init() {}
}

extension Notification.Name {
    /// Posted when the Harvest session is definitively dead (refresh token
    /// rejected). AuthViewModel observes this to surface the login screen.
    static let harvestSessionExpired = Notification.Name("harvestSessionExpired")
}
