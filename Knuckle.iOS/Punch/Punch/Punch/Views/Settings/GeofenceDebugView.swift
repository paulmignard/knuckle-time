//
//  GeofenceDebugView.swift
//  Punch
//
//  Debug view for geofence logs and pending operations.
//  Accessible from Settings for debugging geofence issues.
//

import SwiftUI
import MessageUI

struct GeofenceDebugView: View {
    @State private var logs: [String] = []
    @State private var pendingCount: Int = 0
    @State private var isProcessing = false
    @State private var showMailComposer = false
    @State private var mailError: String?
    @State private var showMailError = false

    var body: some View {
        List {
            // Status Section
            Section {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.accent)
                        .frame(width: 24)
                    Text("Pending Operations")
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("\(pendingCount)")
                        .foregroundColor(pendingCount > 0 ? .warning : .textSecondary)
                        .fontWeight(pendingCount > 0 ? .semibold : .regular)
                }

                if pendingCount > 0 {
                    Button(action: retryNow) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isProcessing ? "Processing..." : "Retry Now")
                                .foregroundColor(.accent)
                            Spacer()
                        }
                    }
                    .disabled(isProcessing)
                }
            } header: {
                Text("Queue Status")
            }
            .listRowBackground(Color.bgSecondary)

            // Actions Section
            Section {
                Button(action: emailLogs) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.accent)
                            .frame(width: 24)
                        Text("Email Logs to Developer")
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                }

                Button(action: copyLogs) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.accent)
                            .frame(width: 24)
                        Text("Copy Logs to Clipboard")
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                }

                Button(role: .destructive, action: clearLogs) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.danger)
                            .frame(width: 24)
                        Text("Clear Logs")
                            .foregroundColor(.danger)
                        Spacer()
                    }
                }
            } header: {
                Text("Actions")
            }
            .listRowBackground(Color.bgSecondary)

            // Logs Section
            Section {
                if logs.isEmpty {
                    Text("No logs available")
                        .foregroundColor(.textSecondary)
                        .italic()
                } else {
                    ForEach(Array(logs.enumerated().reversed()), id: \.offset) { _, log in
                        Text(log)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(logColor(for: log))
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                }
            } header: {
                HStack {
                    Text("Recent Logs")
                    Spacer()
                    Text("\(logs.count) entries")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            .listRowBackground(Color.bgSecondary)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .navigationTitle("Geofence Logs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: loadData) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            loadData()
        }
        .refreshable {
            loadData()
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                toRecipients: ["paul@knuckletime.com"],
                subject: "Knuckle Geofence Logs",
                body: buildEmailBody(),
                attachmentData: GeofenceLogger.shared.getLogs().data(using: .utf8),
                attachmentMimeType: "text/plain",
                attachmentFileName: "geofence_log.txt"
            )
        }
        .alert("Cannot Send Email", isPresented: $showMailError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mailError ?? "Mail is not configured on this device. Please copy the logs and email them manually.")
        }
    }

    private func loadData() {
        logs = GeofenceLogger.shared.getLogEntries().suffix(200).reversed()

        Task {
            pendingCount = await OfflineQueue.shared.pendingCount
        }
    }

    private func retryNow() {
        isProcessing = true
        GeofenceLogger.shared.log("📋 Manual retry triggered from debug view")

        Task {
            await OfflineQueue.shared.processQueue()
            try? await Task.sleep(for: .seconds(1))

            await MainActor.run {
                loadData()
                isProcessing = false
            }
        }
    }

    private func emailLogs() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            mailError = "Mail is not configured on this device. Please copy the logs and email them manually to paul@knuckletime.com"
            showMailError = true
        }
    }

    private func copyLogs() {
        let logs = GeofenceLogger.shared.getLogs()
        // Set clipboard with 5-minute expiration to avoid lingering sensitive data
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: logs]],
            options: [.expirationDate: Date().addingTimeInterval(5 * 60)]
        )
    }

    private func clearLogs() {
        GeofenceLogger.shared.clearLogs()
        loadData()
    }

    private func buildEmailBody() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current.model
        let ios = UIDevice.current.systemVersion

        return """
        Hi Paul,

        I'm experiencing an issue with geofence tracking. Here are my logs:

        ---
        App Version: \(version) (\(build))
        Device: \(device)
        iOS: \(ios)
        ---

        [Describe what happened here]

        """
    }

    private func logColor(for log: String) -> Color {
        if log.contains("[ERROR]") || log.contains("❌") {
            return .red
        } else if log.contains("[WARN]") || log.contains("⚠️") {
            return .orange
        } else if log.contains("✅") {
            return .green
        } else {
            return .primary
        }
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let toRecipients: [String]
    let subject: String
    let body: String
    let attachmentData: Data?
    let attachmentMimeType: String
    let attachmentFileName: String

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(toRecipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)

        if let data = attachmentData {
            vc.addAttachmentData(data, mimeType: attachmentMimeType, fileName: attachmentFileName)
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        GeofenceDebugView()
    }
}
