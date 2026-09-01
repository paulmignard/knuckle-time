//
//  SettingsViewModel.swift
//  Punch
//
//  Settings view model for Harvest account and app preferences
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var pendingEvents = 0
    @Published var lastHarvestUpdate: Date?
    @Published var isLoading = false
    @Published var isRefreshingHarvest = false
    @Published var error: String?

    private let harvestService = HarvestService.shared

    // Key for persisting last update time
    private let lastUpdateKey = "lastHarvestUpdate"

    var lastHarvestUpdateDate: Date? {
        get {
            if let date = lastHarvestUpdate {
                return date
            }
            // Try to load from UserDefaults
            return UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
        }
        set {
            lastHarvestUpdate = newValue
            UserDefaults.standard.set(newValue, forKey: lastUpdateKey)
        }
    }

    func refresh() async {
        await checkPendingEvents()
    }

    func checkPendingEvents() async {
        pendingEvents = await OfflineQueue.shared.pendingCount
    }

    /// Retry pending offline events
    func retryPendingEvents() async {
        isLoading = true
        await OfflineQueue.shared.processQueue()
        await checkPendingEvents()
        isLoading = false
    }

    /// Force refresh all Harvest data (projects, tasks, entries)
    func refreshHarvestData() async {
        isRefreshingHarvest = true
        error = nil

        do {
            // Fetch projects to verify connection and refresh cache
            _ = try await harvestService.getProjects()

            // Fetch today's entries
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }
            _ = try await harvestService.getEntries(from: today, to: tomorrow)

            // Fetch stats
            _ = try await harvestService.getStats()

            // Update last refresh time
            lastHarvestUpdateDate = Date()

            // Notify other views to refresh
            NotificationCenter.default.post(name: .harvestDataRefreshed, object: nil)

        } catch {
            self.error = "Failed to refresh: \(error.localizedDescription)"
        }

        isRefreshingHarvest = false
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let harvestDataRefreshed = Notification.Name("harvestDataRefreshed")
}
