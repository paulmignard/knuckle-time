import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var isHighlighted: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(isHighlighted ? .success : .textPrimary)

            Text(title)
                .font(.caption2)
                .foregroundColor(.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Default state
        HStack {
            StatCard(title: "Today", value: "4.5h")
            StatCard(title: "Week", value: "32.5h")
            StatCard(title: "Month", value: "128h")
        }
        .padding(.horizontal, 8)

        // With "Today" highlighted (when timer is running)
        HStack {
            StatCard(title: "Today", value: "4.5h", isHighlighted: true)
            StatCard(title: "Week", value: "32.5h")
            StatCard(title: "Month", value: "128h")
        }
        .padding(.horizontal, 8)
    }
    .padding()
    .background(Color.bgPrimary)
}
