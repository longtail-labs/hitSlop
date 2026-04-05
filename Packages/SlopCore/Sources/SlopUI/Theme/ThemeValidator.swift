import Foundation

/// Validates a ThemeFile for readability and correctness.
public enum ThemeValidator {
    public struct Result: Sendable {
        public let isValid: Bool
        public let warnings: [String]
    }

    /// Validate a ThemeFile for readability.
    public static func validate(_ file: ThemeFile) -> Result {
        var warnings: [String] = []

        // Check all 6 core hex colors are present and parseable
        let coreColors: [(String?, String)] = [
            (file.background, "background"),
            (file.foreground, "foreground"),
            (file.secondary, "secondary"),
            (file.accent, "accent"),
            (file.surface, "surface"),
            (file.divider, "divider"),
        ]

        for (hex, name) in coreColors {
            guard let hex else {
                warnings.append("Missing required color: \(name)")
                continue
            }
            if !isValidHex(hex) {
                warnings.append("Invalid hex color for \(name): \(hex)")
            }
        }

        // If core colors are missing, can't do contrast checks
        guard let bg = file.background, let fg = file.foreground,
              let sec = file.secondary, let acc = file.accent,
              isValidHex(bg), isValidHex(fg), isValidHex(sec), isValidHex(acc)
        else {
            return Result(isValid: false, warnings: warnings)
        }

        // WCAG AA: foreground/background >= 4.5:1
        let fgBgRatio = contrastRatio(fg, bg)
        if fgBgRatio < 4.5 {
            warnings.append(
                "Low contrast: foreground/background ratio \(String(format: "%.1f", fgBgRatio)):1 (need 4.5:1 for WCAG AA)"
            )
        }

        // Secondary/background >= 3.0:1
        let secBgRatio = contrastRatio(sec, bg)
        if secBgRatio < 3.0 {
            warnings.append(
                "Low contrast: secondary/background ratio \(String(format: "%.1f", secBgRatio)):1 (need 3.0:1)"
            )
        }

        // Accent distinguishable from background >= 3.0:1
        let accBgRatio = contrastRatio(acc, bg)
        if accBgRatio < 3.0 {
            warnings.append(
                "Low contrast: accent/background ratio \(String(format: "%.1f", accBgRatio)):1 (need 3.0:1)"
            )
        }

        // Verify toSlopTheme() succeeds
        if file.toSlopTheme() == nil {
            warnings.append("Theme cannot be converted to SlopTheme (check color values)")
        }

        let isValid = warnings.isEmpty
        return Result(isValid: isValid, warnings: warnings)
    }

    private static func isValidHex(_ hex: String) -> Bool {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        return h.count == 6 && UInt64(h, radix: 16) != nil
    }
}
