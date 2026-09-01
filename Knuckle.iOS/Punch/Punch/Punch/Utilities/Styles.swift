import SwiftUI

// MARK: - Text Field Styles

struct KnuckleTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.bgTertiary)
            .cornerRadius(8)
            .foregroundColor(.textPrimary)
    }
}

// For backward compatibility
typealias PunchTextFieldStyle = KnuckleTextFieldStyle

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(isEnabled ? Color.accent : Color.bgTertiary)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.bgTertiary)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.danger)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
