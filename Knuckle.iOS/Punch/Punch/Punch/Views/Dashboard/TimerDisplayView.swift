//
//  TimerDisplayView.swift
//  Punch
//
//  Timer display showing running timer or project/task selection
//

import SwiftUI
import Combine

struct TimerDisplayView: View {
    let runningTimer: RunningTimer?
    let selectedProject: Project?
    let selectedTask: ProjectTask?
    @Binding var notes: String
    let isTogglingTimer: Bool  // Shows spinner on button
    let onStart: () -> Void
    let onStop: () -> Void
    let onSelectProjectTask: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var elapsedSeconds: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isRunning: Bool {
        runningTimer != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            // Project/Task name (centered, top of card)
            if let timer = runningTimer {
                VStack(spacing: 4) {
                    Text(timer.projectName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)

                    Text(timer.taskName)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
            } else if let project = selectedProject {
                // Show selected project when idle
                Button(action: onSelectProjectTask) {
                    VStack(spacing: 4) {
                        Text(project.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.textPrimary)

                        if let task = selectedTask {
                            Text(task.name)
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                // No project selected
                Button(action: onSelectProjectTask) {
                    Text("Select Project & Task")
                        .font(.body)
                        .foregroundColor(.textMuted)
                }
                .buttonStyle(.plain)
            }

            // Timer display container with state-based styling
            VStack(spacing: 8) {
                // Timer digits
                Text(DateFormatters.formatTimer(elapsedSeconds))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.success)
                    .shadow(
                        color: Color.successGlow,
                        radius: isRunning ? 15 : 8
                    )

                // Subtitle text
                if let timer = runningTimer {
                    Text("Started at \(DateFormatters.formatTime(timer.startedAt))")
                        .font(.caption)
                        .foregroundColor(Color.success.opacity(0.7))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text("Ready to track")
                        .font(.caption)
                        .foregroundColor(.textMuted)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(isRunning ? Color.successSubtle : Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isRunning ? Color.successBorder : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.3), value: isRunning)

            // Notes field
            if !isRunning {
                // Collapsed placeholder when not running
                Button(action: {}) {
                    HStack {
                        TextField("+ Add note", text: $notes)
                            .font(.subheadline)
                            .foregroundColor(notes.isEmpty ? .textMuted : .textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else if let timerNotes = runningTimer?.notes, !timerNotes.isEmpty {
                // Show notes when running with content
                Text(timerNotes)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Action button
            if isRunning {
                Button(action: onStop) {
                    ZStack {
                        // Title (hidden when loading)
                        Text("Stop Timer")
                            .opacity(isTogglingTimer ? 0 : 1)

                        // Spinner (shown when loading)
                        if isTogglingTimer {
                            ProgressView()
                                .tint(.danger)
                        }
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .background(Color.dangerSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.dangerBorder, lineWidth: 1)
                )
                .disabled(isTogglingTimer)
            } else {
                Button(action: onStart) {
                    ZStack {
                        // Title (hidden when loading)
                        Text("Start Timer")
                            .opacity(isTogglingTimer ? 0 : 1)

                        // Spinner (shown when loading)
                        if isTogglingTimer {
                            ProgressView()
                                .tint(colorScheme == .dark ? .black : .white)
                        }
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .background(selectedProject != nil && selectedTask != nil ? Color.success : Color.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(selectedProject == nil || selectedTask == nil || isTogglingTimer)
            }
        }
        .padding(20)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.shadowCard, radius: 12, y: 4)
        .overlay(
            // Border when running, or subtle border in light mode
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isRunning ? Color.successBorder : (colorScheme == .light ? Color.borderSubtle : Color.clear),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isRunning)
        .onReceive(timer) { _ in
            updateElapsed()
        }
        .onAppear {
            updateElapsed()
        }
    }

    private func updateElapsed() {
        if let timer = runningTimer {
            elapsedSeconds = Int(Date().timeIntervalSince(timer.startedAt))
        } else {
            elapsedSeconds = 0
        }
    }
}

// MARK: - Button Styles

struct StartButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? Color.success : Color.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.dangerSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.dangerBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            TimerDisplayView(
                runningTimer: nil,
                selectedProject: nil,
                selectedTask: nil,
                notes: .constant(""),
                isTogglingTimer: false,
                onStart: {},
                onStop: {},
                onSelectProjectTask: {}
            )

            TimerDisplayView(
                runningTimer: nil,
                selectedProject: Project(
                    id: 1,
                    name: "Acme Development",
                    code: nil,
                    clientId: nil,
                    clientName: nil,
                    isActive: true,
                    isBillable: true
                ),
                selectedTask: ProjectTask(
                    id: 1,
                    name: "Feature Development",
                    isBillable: true,
                    isActive: true
                ),
                notes: .constant(""),
                isTogglingTimer: false,
                onStart: {},
                onStop: {},
                onSelectProjectTask: {}
            )

            TimerDisplayView(
                runningTimer: RunningTimer(
                    id: 123,
                    projectId: 1,
                    projectName: "Acme Development",
                    taskId: 1,
                    taskName: "Feature Development",
                    startedAt: Date().addingTimeInterval(-9257),
                    hours: 2.57,
                    notes: "Console documentation updates"
                ),
                selectedProject: nil,
                selectedTask: nil,
                notes: .constant(""),
                isTogglingTimer: false,
                onStart: {},
                onStop: {},
                onSelectProjectTask: {}
            )
        }
        .padding()
    }
    .background(Color.bgPrimary)
}
