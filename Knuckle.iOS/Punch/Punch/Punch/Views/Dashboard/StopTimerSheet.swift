//
//  StopTimerSheet.swift
//  Punch
//
//  Sheet for stopping the timer with notes
//

import SwiftUI

struct StopTimerSheet: View {
    let timer: RunningTimer?
    let onStop: (String?) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Timer info
                    if let timer = timer {
                        VStack(spacing: 8) {
                            Text(timer.projectName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)

                            Text(timer.taskName)
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)

                            let elapsed = Int(Date().timeIntervalSince(timer.startedAt))
                            Text(DateFormatters.formatTimer(elapsed))
                                .font(.system(size: 32, weight: .light, design: .monospaced))
                                .foregroundColor(.success)
                        }
                        .padding(.top, 8)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.textTertiary)

                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.bgTertiary)
                            .cornerRadius(8)
                            .scrollContentBackground(.hidden)
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        Button("Stop Timer") {
                            onStop(notes.isEmpty ? nil : notes)
                        }
                        .buttonStyle(DangerButtonStyle())

                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .background(Color.bgPrimary)
            .navigationTitle("Stop Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Pre-fill notes from timer if available
            if let timerNotes = timer?.notes {
                notes = timerNotes
            }
        }
    }
}

#Preview {
    StopTimerSheet(
        timer: RunningTimer(
            id: 123,
            projectId: 1,
            projectName: "Website Redesign",
            taskId: 1,
            taskName: "Development",
            startedAt: Date().addingTimeInterval(-3723),
            hours: 1.03,
            notes: nil
        ),
        onStop: { _ in }
    )
}
