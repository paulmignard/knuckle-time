import SwiftUI
import UIKit

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Create a color that adapts to light/dark mode
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Background Colors

extension Color {
    static let bgPrimary = Color(
        light: .white,
        dark: Color(hex: "000000")
    )

    static let bgSecondary = Color(
        light: Color(hex: "f2f2f7"),
        dark: Color(hex: "1c1c1e")
    )

    static let bgTertiary = Color(
        light: Color(hex: "e5e5ea"),
        dark: Color(hex: "2c2c2e")
    )

    static let bgElevated = Color(
        light: Color(hex: "f5f5f5"),
        dark: Color(hex: "2c2c2e")
    )

    static let bgCard = Color(
        light: .white,
        dark: Color(hex: "1c1c1e")
    )

    /// Overlay for satellite background - more opaque in light mode for readability
    static let bgSatelliteOverlay = Color(
        light: Color.white.opacity(0.85),
        dark: Color.black.opacity(0.70)
    )

    /// Idle state gradient (when not in a geofence)
    static let bgIdleGradientStart = Color(
        light: Color(hex: "f5f5f5"),
        dark: Color(hex: "1c1c1e")
    )

    static let bgIdleGradientEnd = Color(
        light: Color(hex: "e5e5ea"),
        dark: Color(hex: "0a0a0a")
    )
}

// MARK: - Text Colors

extension Color {
    static let textPrimary = Color(
        light: Color(hex: "1a1a1a"),
        dark: Color(hex: "f5f5f5")
    )

    static let textSecondary = Color(
        light: Color(hex: "666666"),
        dark: Color(hex: "a0a0a0")
    )

    static let textTertiary = Color(
        light: Color(hex: "888888"),
        dark: Color(hex: "6e6e6e")
    )

    static let textMuted = Color(
        light: Color(hex: "999999"),
        dark: Color(hex: "666666")
    )
}

// MARK: - Accent Colors (Green)

extension Color {
    /// Primary green - slightly darker in light mode for contrast
    static let success = Color(
        light: Color(hex: "23a147"),
        dark: Color(hex: "30d158")
    )

    /// Alias for success
    static let greenPrimary = success

    static let successSubtle = Color(
        light: Color(hex: "30d158").opacity(0.12),
        dark: Color(hex: "30d158").opacity(0.15)
    )

    static let greenSubtle = successSubtle

    static let successBorder = Color(
        light: Color(hex: "30d158").opacity(0.40),
        dark: Color(hex: "30d158").opacity(0.30)
    )

    static let greenBorder = successBorder

    /// Glow effect - reduced in light mode
    static let successGlow = Color(
        light: Color(hex: "30d158").opacity(0.30),
        dark: Color(hex: "30d158").opacity(0.50)
    )

    static let successDim = Color(hex: "30d158").opacity(0.15)
}

// MARK: - Accent Colors (Red)

extension Color {
    /// Primary red - slightly darker in light mode for contrast
    static let danger = Color(
        light: Color(hex: "d63030"),
        dark: Color(hex: "ff453a")
    )

    static let redPrimary = danger

    static let dangerSubtle = Color(
        light: Color(hex: "ff453a").opacity(0.12),
        dark: Color(hex: "ff453a").opacity(0.20)
    )

    static let redSubtle = dangerSubtle

    static let dangerBorder = Color(
        light: Color(hex: "ff453a").opacity(0.35),
        dark: Color(hex: "ff453a").opacity(0.30)
    )

    static let redBorder = dangerBorder
}

// MARK: - Other Accent Colors

extension Color {
    static let accent = Color(hex: "0a84ff")

    static let warning = Color(hex: "ffd60a")
}

// MARK: - Borders & Shadows

extension Color {
    static let border = Color(
        light: Color(hex: "e5e5e5"),
        dark: Color(hex: "2a2a2a")
    )

    static let borderSubtle = Color(
        light: Color(hex: "f0f0f0"),
        dark: Color(hex: "1f1f1f")
    )

    static let separator = Color(
        light: Color(hex: "3c3c43").opacity(0.2),
        dark: Color(hex: "545458").opacity(0.6)
    )

    /// Card shadow - only visible in light mode
    static let shadowCard = Color.black.opacity(0.08)
}

// MARK: - Theme Management

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}
