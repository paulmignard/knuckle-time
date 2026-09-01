//
//  EntriesViewModel.swift
//  Punch
//
//  Entries view model using HarvestService
//

import Foundation
import SwiftUI
import Combine

@MainActor
class EntriesViewModel: ObservableObject {
    @Published var entries: [TrackedTimeEntry] = []
    @Published var projects: [Project] = []
    @Published var selectedProjectId: Int64?
    @Published var dateFilter: DateFilter = .thisWeek
    @Published var isLoading = false
    @Published var error: String?

    private let harvestService = HarvestService.shared
    private var offset = 0
    private let limit = 50
    private var hasMore = true

    enum DateFilter: String, CaseIterable {
        case thisWeek = "This Week"
        case lastWeek = "Last Week"
        case thisMonth = "This Month"
        case allTime = "All Time"

        var dateRange: (from: Date?, to: Date?) {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                return (startOfWeek, nil)
            case .lastWeek:
                let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let startOfLastWeek = calendar.date(byAdding: .day, value: -7, to: startOfThisWeek) ?? now
                return (startOfLastWeek, startOfThisWeek)
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                return (startOfMonth, nil)
            case .allTime:
                // Last 90 days for "all time" to avoid huge API responses
                let startDate = calendar.date(byAdding: .day, value: -90, to: now) ?? now
                return (startDate, nil)
            }
        }
    }

    func refresh() async {
        offset = 0
        hasMore = true
        entries = []
        await fetchEntries()
        await fetchProjects()
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        await fetchEntries()
    }

    private func fetchEntries() async {
        isLoading = true
        error = nil

        do {
            let range = dateFilter.dateRange
            let from = range.from ?? Date().addingTimeInterval(-90 * 24 * 60 * 60)
            let to = range.to ?? Date().addingTimeInterval(24 * 60 * 60)  // Include today

            var allEntries = try await harvestService.getEntries(from: from, to: to)

            // Filter out invoiced/billed entries - we only show uninvoiced time
            allEntries = allEntries.filter { !$0.isBilled }

            // Filter by project if selected
            if let projectId = selectedProjectId {
                allEntries = allEntries.filter { $0.projectId == projectId }
            }

            // Sort by date descending
            allEntries.sort { $0.spentDate > $1.spentDate }

            entries = allEntries
            hasMore = false  // Harvest API returns all entries in range
        } catch let apiError as HarvestAPIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to load entries"
        }

        isLoading = false
    }

    private func fetchProjects() async {
        do {
            projects = try await harvestService.getProjects()
        } catch {
            projects = []
        }
    }

    func deleteEntry(_ entry: TrackedTimeEntry) async {
        do {
            try await harvestService.deleteEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }
        } catch let apiError as HarvestAPIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to delete entry"
        }
    }

    // Group entries by day for section headers
    var groupedEntries: [(date: Date, entries: [TrackedTimeEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.spentDate)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, entries: $0.value.sorted { $0.spentDate > $1.spentDate }) }
    }
}
