import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Background - must match LaunchScreen.storyboard
            Color.bgPrimary
                .ignoresSafeArea()

            // Logo - centered exactly like LaunchScreen.storyboard
            Text("Knuckle")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)

            // Spinner - positioned below the centered text
            ProgressView()
                .tint(.textSecondary)
                .offset(y: 60)
        }
    }
}

#Preview {
    LaunchScreenView()
}
