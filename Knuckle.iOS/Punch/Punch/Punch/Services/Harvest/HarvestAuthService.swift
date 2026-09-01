//
//  HarvestAuthService.swift
//  Punch
//
//  OAuth flow for Harvest using ASWebAuthenticationSession
//

import Foundation
import AuthenticationServices
import UIKit
import Combine

@MainActor
class HarvestAuthService: NSObject, ObservableObject {
    static let shared = HarvestAuthService()

    // MARK: - OAuth Configuration
    // Register your app at https://id.getharvest.com/developers

    static let clientId = "WhK-ehjoNy6gROmJVIGb8rde"
    static let redirectUri = "https://auth.knuckletime.com/oauth/callback"
    static let scope = "all"

    // Auth proxy handles the client_secret securely on the server
    private static let authProxyBaseURL = "https://auth.knuckletime.com"
    private static let oauthBaseURL = "https://id.getharvest.com"

    // MARK: - State

    @Published var isAuthenticating = false
    @Published var availableAccounts: [HarvestAccount] = []
    @Published var error: String?

    private var authSession: ASWebAuthenticationSession?
    private var authContinuation: CheckedContinuation<(String, String, Int, [HarvestAccount], HarvestUserInfo), Error>?

    private override init() {
        super.init()
    }

    // MARK: - OAuth Flow

    /// Start the OAuth flow
    /// Returns: (accessToken, refreshToken, expiresIn, accounts, userInfo)
    func startOAuthFlow() async throws -> (String, String, Int, [HarvestAccount], HarvestUserInfo) {
        isAuthenticating = true
        error = nil
        defer { isAuthenticating = false }

        return try await withCheckedThrowingContinuation { continuation in
            self.authContinuation = continuation

            let authURL: URL
            do {
                authURL = try buildAuthorizationURL()
            } catch {
                continuation.resume(throwing: error)
                self.authContinuation = nil
                return
            }

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "knuckle"  // Matches knuckle://callback
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    if let error = error {
                        if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            self?.authContinuation?.resume(throwing: HarvestAuthError.userCancelled)
                        } else {
                            self?.authContinuation?.resume(throwing: HarvestAuthError.authFailed(error.localizedDescription))
                        }
                        self?.authContinuation = nil
                        return
                    }

                    guard let callbackURL = callbackURL else {
                        self?.authContinuation?.resume(throwing: HarvestAuthError.authFailed("No callback URL"))
                        self?.authContinuation = nil
                        return
                    }

                    await self?.handleCallback(callbackURL)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            self.authSession = session

            if !session.start() {
                continuation.resume(throwing: HarvestAuthError.authFailed("Failed to start auth session"))
                self.authContinuation = nil
            }
        }
    }

    private func buildAuthorizationURL() throws -> URL {
        guard var components = URLComponents(string: "\(Self.oauthBaseURL)/oauth2/authorize") else {
            throw HarvestAuthError.authFailed("Invalid OAuth base URL")
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope)
        ]
        guard let url = components.url else {
            throw HarvestAuthError.authFailed("Failed to build authorization URL")
        }
        return url
    }

    private func handleCallback(_ url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            authContinuation?.resume(throwing: HarvestAuthError.authFailed("No authorization code in callback"))
            authContinuation = nil
            return
        }

        do {
            // Exchange code for token
            let tokenResponse = try await exchangeCodeForToken(code)

            // Fetch available accounts
            let accountsResponse = try await fetchAccounts(accessToken: tokenResponse.accessToken)

            authContinuation?.resume(returning: (
                tokenResponse.accessToken,
                tokenResponse.refreshToken,
                tokenResponse.expiresIn,
                accountsResponse.accounts,
                accountsResponse.user
            ))
        } catch {
            authContinuation?.resume(throwing: error)
        }
        authContinuation = nil
    }

    private func exchangeCodeForToken(_ code: String) async throws -> AuthProxyTokenResponse {
        guard let url = URL(string: "\(Self.authProxyBaseURL)/auth/token") else {
            throw HarvestAuthError.authFailed("Invalid token URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(HarvestAPIClient.userAgent, forHTTPHeaderField: "User-Agent")

        let tokenRequest = AuthProxyTokenRequest(code: code, redirectUri: Self.redirectUri)
        request.httpBody = try JSONEncoder().encode(tokenRequest)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HarvestAuthError.authFailed("Invalid response from auth server")
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw HarvestAuthError.authFailed("Token exchange failed: \(message)")
        }

        return try JSONDecoder().decode(AuthProxyTokenResponse.self, from: data)
    }

    private func fetchAccounts(accessToken: String) async throws -> HarvestAccountsResponse {
        guard let url = URL(string: "\(Self.oauthBaseURL)/api/v2/accounts") else {
            throw HarvestAuthError.authFailed("Invalid accounts URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(HarvestAPIClient.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HarvestAuthError.authFailed("Invalid response from accounts server")
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw HarvestAuthError.authFailed("Failed to fetch accounts: \(message)")
        }

        return try JSONDecoder().decode(HarvestAccountsResponse.self, from: data)
    }

    /// Complete authentication by selecting an account
    func selectAccount(
        _ account: HarvestAccount,
        accessToken: String,
        refreshToken: String,
        expiresIn: Int,
        userInfo: HarvestUserInfo
    ) async {
        await HarvestAPIClient.shared.setTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accountId: account.id,
            userName: userInfo.fullName,
            userEmail: userInfo.email,
            expiresIn: expiresIn
        )
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension HarvestAuthService: ASWebAuthenticationPresentationContextProviding {
    @MainActor func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the first window scene's key window
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Error Types

enum HarvestAuthError: LocalizedError {
    case userCancelled
    case authFailed(String)
    case noAccountSelected

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Authentication was cancelled"
        case .authFailed(let message):
            return "Authentication failed: \(message)"
        case .noAccountSelected:
            return "Please select a Harvest account"
        }
    }
}
