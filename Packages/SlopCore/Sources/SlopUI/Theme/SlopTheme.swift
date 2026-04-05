import SwiftUI
import SlopKit

extension SlopTheme {
    /// Resolve a theme by name using the canonical theme catalog.
    public static func from(_ name: String?) -> SlopTheme {
        ThemeCatalog.resolveTheme(name)
    }
}

// MARK: - Hex Color

extension Color {
    public init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let rgb = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
