//
//  TodayEntriesView.swift
//  Punch
//
//  Display today's time entries from Harvest
//

import SwiftUI

struct TodayEntriesView: View {
    let entries: [TrackedTimeEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.textMuted)
                .tracking(0.5)

            ForEach(entries) { entry in
                TrackedEntryCard(entry: entry)
            }
        }
    }
}

// MARK: - Entry Card for Harvest entries

struct TrackedEntryCard: View {
    let entry: TrackedTimeEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.projectName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)

                Text(entry.notes ?? entry.taskName)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatHours(entry.hours))
                .font(.subheadline)
                .fontWeight(entry.isRunning ? .medium : .regular)
                .foregroundColor(entry.isRunning ? .success : .textSecondary)
        }
        .padding(16)
        .background(entry.isRunning ? Color.successSubtle : Color.bgSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(entry.isRunning ? Color.successBorder : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: entry.isRunning)
    }

    private func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60

        if h > 0 {
            return "\(h):\(String(format: "%02d", m))"
        }
        return "\(m)m"
    }
}

#Preview {
    NavigationStack {
        TodayEntriesView(entries: [
            TrackedTimeEntry(
                id: 123,
                projectId: 1,
                projectName: "Acme Development",
                taskId: 1,
                taskName: "Feature Development",
                spentDate: Date(),
                hours: 2.57,
                notes: "Console documentation updates",
                isRunning: true,
                isBilled: false,
                startedTime: Date().addingTimeInterval(-9257),
                endedTime: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            TrackedTimeEntry(
                id: 124,
                projectId: 2,
                projectName: "Website Redesign",
                taskId: 2,
                taskName: "Development",
                spentDate: Date(),
                hours: 1.5,
                notes: nil,
                isRunning: false,
                isBilled: false,
                startedTime: Date().addingTimeInterval(-3600 * 4),
                endedTime: Date().addingTimeInterval(-3600 * 2.5),
                createdAt: Date(),
                updatedAt: Date()
            )
        ])
        .padding()
        .background(Color.bgPrimary)
    }
}
