//
//  AuthViewModel.swift
//  Punch
//
//  Authentication view model for Harvest OAuth
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentUserName: String?
    @Published var currentUserEmail: String?

    // OAuth flow state
    @Published var showAccountPicker = false
    @Published var pendingAccounts: [HarvestAccount] = []
    @Published var pendingUserInfo: HarvestUserInfo?
    @Published var pendingAccessToken: String?
    @Published var pendingRefreshToken: String?
    @Published var pendingExpiresIn: Int = 0

    private let harvestService = HarvestService.shared

    init() {
        Task {
            await checkAuthStatus()
        }

        // A dead session (refresh token rejected) can surface at any time —
        // log out so the user sees the login screen instead of an app that
        // silently stops tracking
        NotificationCenter.default.addObserver(
            forName: .harvestSessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isAuthenticated else { return }
                await self.logout()
                self.error = "Your Harvest session expired. Please connect again."
            }
        }
    }

    func checkAuthStatus() async {
        isCheckingAuth = true
        defer { isCheckingAuth = false }

        // Detect app reinstall: UserDefaults is deleted with app, Keychain persists
        // If we have tokens but no "hasLaunchedBefore" flag, app was reinstalled
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        let hasTokens = await HarvestAPIClient.shared.hasTokens

        if hasTokens && !hasLaunchedBefore {
            // App was reinstalled - clear stale tokens and start fresh
            await harvestService.logout()
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            return
        }

        // Mark that we've launched (survives until app is deleted)
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")

        if hasTokens {
            // Validate tokens by making a simple request
            do {
                _ = try await harvestService.getRunningTimer()
                currentUserName = await harvestService.currentUserName
                currentUserEmail = await harvestService.currentUserEmail
                isAuthenticated = true
            } catch HarvestAPIError.unauthorized {
                isAuthenticated = false
            } catch {
                // Network error - assume authenticated if we have tokens
                currentUserName = await harvestService.currentUserName
                currentUserEmail = await harvestService.currentUserEmail
                isAuthenticated = true
            }
        }
    }

    // MARK: - Harvest OAuth

    func connectToHarvest() async {
        isLoading = true
        error = nil

        do {
            let (accessToken, refreshToken, expiresIn, accounts, userInfo) =
                try await HarvestAuthService.shared.startOAuthFlow()

            if accounts.count == 1 {
                // Single account - auto-select
                await selectAccount(accounts[0], accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn, userInfo: userInfo)
            } else if accounts.count > 1 {
                // Multiple accounts - show picker
                pendingAccounts = accounts
                pendingUserInfo = userInfo
                pendingAccessToken = accessToken
                pendingRefreshToken = refreshToken
                pendingExpiresIn = expiresIn
                showAccountPicker = true
            } else {
                error = "No Harvest accounts found"
            }
        } catch HarvestAuthError.userCancelled {
            // User cancelled - no error message needed
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func selectAccount(
        _ account: HarvestAccount,
        accessToken: String,
        refreshToken: String,
        expiresIn: Int,
        userInfo: HarvestUserInfo
    ) async {
        await HarvestAuthService.shared.selectAccount(
            account,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            userInfo: userInfo
        )

        currentUserName = userInfo.fullName
        currentUserEmail = userInfo.email
        isAuthenticated = true

        // Clear pending state
        pendingAccounts = []
        pendingUserInfo = nil
        pendingAccessToken = nil
        pendingRefreshToken = nil
        pendingExpiresIn = 0
        showAccountPicker = false
    }

    func logout() async {
        await harvestService.logout()
        LocationService.shared.stopMonitoring()
        // The app can no longer manage any running timer — clear the
        // Live Activity and widget rather than show stale tracking state
        LiveActivityManager.shared.endActivity()
        currentUserName = nil
        currentUserEmail = nil
        isAuthenticated = false
    }
}
