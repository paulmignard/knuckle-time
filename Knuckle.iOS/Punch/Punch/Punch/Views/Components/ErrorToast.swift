//
//  ErrorToast.swift
//  Punch
//
//  Non-blocking error banner that auto-dismisses
//

import SwiftUI

struct ErrorToast: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.danger.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()

        VStack {
            ErrorToast(
                message: "Couldn't start timer. Check your connection.",
                onDismiss: {}
            )
            Spacer()
        }
        .padding(.top, 60)
    }
}
