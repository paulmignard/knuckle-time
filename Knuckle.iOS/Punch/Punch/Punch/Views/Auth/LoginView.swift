//
//  LoginView.swift
//  Punch
//
//  Login screen with Harvest OAuth connection
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("👊")
                        .font(.system(size: 40))
                    Text("Knuckle")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.textPrimary)
                }

                Text("Time tracking made simple")
                    .font(.subheadline)
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            // Harvest Integration Info
            VStack(spacing: 16) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("Connect to Harvest")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                Text("Knuckle uses Harvest to track your time.\nConnect your account to get started.")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Connect Button
            VStack(spacing: 16) {
                if let error = authViewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.danger)
                        .multilineTextAlignment(.center)
                }

                Button(action: connectToHarvest) {
                    HStack(spacing: 12) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "link")
                            Text("Connect to Harvest")
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(authViewModel.isLoading)
            }
            .padding(.horizontal, 24)

            Spacer()

        }
        .background(Color.bgPrimary)
        .sheet(isPresented: $authViewModel.showAccountPicker) {
            if let userInfo = authViewModel.pendingUserInfo,
               let accessToken = authViewModel.pendingAccessToken,
               let refreshToken = authViewModel.pendingRefreshToken {
                HarvestAccountPickerView(
                    accounts: authViewModel.pendingAccounts,
                    userInfo: userInfo,
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiresIn: authViewModel.pendingExpiresIn,
                    onSelect: { account in
                        Task {
                            await authViewModel.selectAccount(
                                account,
                                accessToken: accessToken,
                                refreshToken: refreshToken,
                                expiresIn: authViewModel.pendingExpiresIn,
                                userInfo: userInfo
                            )
                        }
                    }
                )
            }
        }
    }

    private func connectToHarvest() {
        Task {
            await authViewModel.connectToHarvest()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
