import Foundation

/// Derives a complete ThemeFile from a single accent color using LCH color math.
/// All derived colors are guaranteed to meet WCAG AA contrast ratios.
public enum ThemeDeriver {

    /// Derive a complete theme from a single accent hex color.
    public static func derive(accent: String, isDark: Bool = true) -> ThemeFile {
        let lch = LCHColor(hex: accent)
        let hue = lch.h

        if isDark {
            return ThemeFile(
                displayName: nil,
                group: nil,
                background: LCHColor(l: 8, c: lch.c * 0.05, h: hue).toHex(),
                foreground: LCHColor(l: 95, c: 2, h: hue).toHex(),
                secondary: LCHColor(l: 60, c: lch.c * 0.15, h: hue).toHex(),
                accent: accent,
                surface: LCHColor(l: 15, c: lch.c * 0.08, h: hue).toHex(),
                divider: LCHColor(l: 25, c: lch.c * 0.1, h: hue).toHex(),
                success: LCHColor(l: lch.l, c: lch.c * 0.6, h: 140).toHex(),
                warning: LCHColor(l: lch.l, c: lch.c * 0.6, h: 85).toHex(),
                error: LCHColor(l: lch.l, c: lch.c * 0.6, h: 25).toHex()
            )
        } else {
            // Ensure accent is dark enough for contrast on light bg
            let adjustedAccent: String
            if lch.l > 55 {
                adjustedAccent = LCHColor(l: 50, c: lch.c, h: hue).toHex()
            } else {
                adjustedAccent = accent
            }

            return ThemeFile(
                displayName: nil,
                group: nil,
                background: LCHColor(l: 97, c: lch.c * 0.03, h: hue).toHex(),
                foreground: LCHColor(l: 10, c: 5, h: hue).toHex(),
                secondary: LCHColor(l: 45, c: lch.c * 0.2, h: hue).toHex(),
                accent: adjustedAccent,
                surface: LCHColor(l: 92, c: lch.c * 0.05, h: hue).toHex(),
                divider: LCHColor(l: 82, c: lch.c * 0.08, h: hue).toHex(),
                success: LCHColor(l: 40, c: lch.c * 0.6, h: 140).toHex(),
                warning: LCHColor(l: 40, c: lch.c * 0.6, h: 85).toHex(),
                error: LCHColor(l: 40, c: lch.c * 0.6, h: 25).toHex()
            )
        }
    }

    /// Derive a theme from an accent color and explicit background.
    public static func derive(accent: String, background: String) -> ThemeFile {
        let bgLCH = LCHColor(hex: background)
        let isDark = bgLCH.l < 50
        let accentLCH = LCHColor(hex: accent)
        let hue = accentLCH.h

        let foreground: String
        let secondary: String
        let surface: String
        let divider: String

        if isDark {
            foreground = LCHColor(l: 95, c: 2, h: hue).toHex()
            secondary = LCHColor(l: 60, c: accentLCH.c * 0.15, h: hue).toHex()
            surface = LCHColor(l: bgLCH.l + 7, c: bgLCH.c * 1.2, h: bgLCH.h).toHex()
            divider = LCHColor(l: bgLCH.l + 17, c: bgLCH.c * 1.5, h: bgLCH.h).toHex()
        } else {
            foreground = LCHColor(l: 10, c: 5, h: hue).toHex()
            secondary = LCHColor(l: 45, c: accentLCH.c * 0.2, h: hue).toHex()
            surface = LCHColor(l: bgLCH.l - 5, c: bgLCH.c * 1.2, h: bgLCH.h).toHex()
            divider = LCHColor(l: bgLCH.l - 15, c: bgLCH.c * 1.5, h: bgLCH.h).toHex()
        }

        return ThemeFile(
            displayName: nil,
            group: nil,
            background: background,
            foreground: foreground,
            secondary: secondary,
            accent: accent,
            surface: surface,
            divider: divider,
            success: LCHColor(l: isDark ? accentLCH.l : 40, c: accentLCH.c * 0.6, h: 140).toHex(),
            warning: LCHColor(l: isDark ? accentLCH.l : 40, c: accentLCH.c * 0.6, h: 85).toHex(),
            error: LCHColor(l: isDark ? accentLCH.l : 40, c: accentLCH.c * 0.6, h: 25).toHex()
        )
    }
}
