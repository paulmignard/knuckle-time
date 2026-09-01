//
//  HarvestAccountPickerView.swift
//  Punch
//
//  Account selection view for users with multiple Harvest accounts
//

import SwiftUI

struct HarvestAccountPickerView: View {
    let accounts: [HarvestAccount]
    let userInfo: HarvestUserInfo
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let onSelect: (HarvestAccount) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accent)

                    Text("Welcome, \(userInfo.firstName)!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)

                    Text("Select a Harvest account")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 24)

                // Account list
                VStack(spacing: 12) {
                    ForEach(accounts) { account in
                        AccountRow(account: account) {
                            onSelect(account)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Cancel button
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.textMuted)
                .padding(.bottom, 24)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Select Account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: HarvestAccount
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accent.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "building.2")
                        .font(.system(size: 20))
                        .foregroundColor(.accent)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Text(account.product.capitalized)
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textMuted)
            }
            .padding()
            .background(Color.bgSecondary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HarvestAccountPickerView(
        accounts: [
            HarvestAccount(id: 1, name: "Acme Corp", product: "harvest"),
            HarvestAccount(id: 2, name: "Personal Projects", product: "harvest")
        ],
        userInfo: HarvestUserInfo(id: 1, firstName: "Paul", lastName: "Mignard", email: "paul@example.com"),
        accessToken: "test",
        refreshToken: "test",
        expiresIn: 3600,
        onSelect: { _ in }
    )
}
