import SwiftUI

enum PickerBranding {
    /// Flat purple accent for icons and text.
    static let accent = Color(red: 0.61, green: 0.42, blue: 0.92)

    /// Lighter variant for hover/glow effects.
    static let accentLight = Color(red: 0.72, green: 0.56, blue: 0.98)

    /// Full 4-stop gradient matching the app icon (cyan → blue → purple → magenta).
    static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.30, green: 0.85, blue: 0.95),
            Color(red: 0.38, green: 0.50, blue: 0.95),
            Color(red: 0.61, green: 0.42, blue: 0.92),
            Color(red: 0.85, green: 0.35, blue: 0.78),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 2-stop blue → purple gradient for selection borders.
    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.38, green: 0.50, blue: 0.95),
            Color(red: 0.61, green: 0.42, blue: 0.92),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
