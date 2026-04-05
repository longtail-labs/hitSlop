import SwiftUI
import SlopKit

/// Read-only proxy exposing theme colors to Lua scripts as hex strings.
/// Passed to Lua `template.layout(data, theme)` as the second argument.
struct ThemeProxy {
    // Core colors
    let foreground: String
    let background: String
    let secondary: String
    let accent: String
    let surface: String
    let divider: String

    // Semantic colors
    let success: String
    let warning: String
    let error: String
    let muted: String
    let border: String

    init(theme: SlopTheme) {
        self.foreground = theme.foreground.hexString
        self.background = theme.background.hexString
        self.secondary = theme.secondary.hexString
        self.accent = theme.accent.hexString
        self.surface = theme.surface.hexString
        self.divider = theme.divider.hexString
        self.success = theme.success.hexString
        self.warning = theme.warning.hexString
        self.error = theme.error.hexString
        self.muted = theme.muted.hexString
        self.border = theme.border.hexString
    }
}

// MARK: - Color → Hex

extension Color {
    /// Best-effort hex string extraction from a SwiftUI Color.
    var hexString: String {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else {
            return "#808080"
        }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
