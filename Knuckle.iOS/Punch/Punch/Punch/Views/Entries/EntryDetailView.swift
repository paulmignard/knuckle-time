//
//  EntryDetailView.swift
//  Punch
//
//  Entry detail view for Harvest time entries
//

import SwiftUI

struct EntryDetailView: View {
    let entry: TrackedTimeEntry
    @State private var showEditSheet = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(durationText)
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.textPrimary)

                    Text(DateFormatters.fullDate.string(from: entry.spentDate))
                        .font(.subheadline)
                        .foregroundColor(.textTertiary)
                }
                .padding(.top, 20)

                // Details
                GroupBox {
                    VStack(spacing: 0) {
                        DetailRow(label: "Project", value: entry.projectName)
                        Divider().background(Color.separator)
                        DetailRow(label: "Task", value: entry.taskName)
                        Divider().background(Color.separator)
                        if let startTime = entry.startedTime {
                            DetailRow(label: "Start", value: DateFormatters.formatTime(startTime))
                            Divider().background(Color.separator)
                        }
                        if let endTime = entry.endedTime {
                            DetailRow(label: "End", value: DateFormatters.formatTime(endTime))
                        } else if entry.isRunning {
                            DetailRow(label: "Status", value: "Running")
                        }
                    }
                }
                .backgroundStyle(Color.bgSecondary)

                // Notes
                if let notes = entry.notes, !notes.isEmpty {
                    GroupBox("Notes") {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .backgroundStyle(Color.bgSecondary)
                }
            }
            .padding()
        }
        .background(Color.bgPrimary)
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EntryFormView(entry: entry)
        }
    }

    private var durationText: String {
        return DateFormatters.formatDuration(entry.hours)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.textPrimary)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        EntryDetailView(entry: TrackedTimeEntry(
            id: 123,
            projectId: 1,
            projectName: "Website Redesign",
            taskId: 1,
            taskName: "Development",
            spentDate: Date(),
            hours: 4.5,
            notes: "Worked on implementing the new API endpoints and testing with the iOS client.",
            isRunning: false,
            isBilled: false,
            startedTime: Date().addingTimeInterval(-3600 * 4.5),
            endedTime: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
