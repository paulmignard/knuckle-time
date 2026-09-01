//
//  SyncingIndicator.swift
//  Punch
//
//  Subtle pill that appears when API calls are in progress
//

import SwiftUI

struct SyncingIndicator: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.textSecondary)

                Text("Syncing...")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()

        VStack {
            SyncingIndicator(isVisible: true)
            Spacer()
        }
        .padding(.top, 60)
    }
}
