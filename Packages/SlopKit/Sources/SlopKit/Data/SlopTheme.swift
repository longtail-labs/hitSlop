import SwiftUI

/// Shadow definition for themed shadow effects.
public struct SlopShadow: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(color: Color = .black, radius: CGFloat = 4, x: CGFloat = 0, y: CGFloat = 2) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

/// Theme colors and typography available to templates via the SwiftUI environment.
///
/// Templates access the current theme with:
/// ```swift
/// @Environment(\.slopTheme) private var theme
/// ```
public struct SlopTheme: Sendable {
    // MARK: - Core Colors
    public let background: Color
    public let foreground: Color
    public let secondary: Color
    public let accent: Color
    public let surface: Color
    public let divider: Color

    // MARK: - Semantic Colors
    public let success: Color
    public let warning: Color
    public let error: Color
    public let muted: Color
    public let border: Color

    // MARK: - Core Fonts
    public let titleFont: Font
    public let bodyFont: Font
    public let monoFont: Font

    // MARK: - Font Family Names (for custom size/weight)
    public let bodyFontFamily: String?
    public let titleFontFamily: String?
    public let monoFontFamily: String?

    // MARK: - Typography Scale
    public let headingFont: Font
    public let subheadingFont: Font
    public let captionFont: Font
    public let smallFont: Font

    // MARK: - Spacing Scale
    public let spacingXS: CGFloat
    public let spacingSM: CGFloat
    public let spacingMD: CGFloat
    public let spacingLG: CGFloat
    public let spacingXL: CGFloat

    // MARK: - Corner Radius
    public let cornerRadius: CGFloat

    // MARK: - Shadows
    public let shadowSM: SlopShadow
    public let shadowMD: SlopShadow
    public let shadowLG: SlopShadow

    public init(
        background: Color,
        foreground: Color,
        secondary: Color,
        accent: Color,
        surface: Color,
        divider: Color,
        // Semantic colors (optional — intelligent defaults)
        success: Color? = nil,
        warning: Color? = nil,
        error: Color? = nil,
        muted: Color? = nil,
        border: Color? = nil,
        // Core fonts
        titleFont: Font = .system(.title, weight: .bold),
        bodyFont: Font = .system(.body),
        monoFont: Font = .system(.body, design: .monospaced),
        // Font family names (for custom size/weight via convenience methods)
        bodyFontFamily: String? = nil,
        titleFontFamily: String? = nil,
        monoFontFamily: String? = nil,
        // Typography scale (optional — defaults derived from system)
        headingFont: Font? = nil,
        subheadingFont: Font? = nil,
        captionFont: Font? = nil,
        smallFont: Font? = nil,
        // Spacing scale (optional — sensible defaults)
        spacingXS: CGFloat = 4,
        spacingSM: CGFloat = 8,
        spacingMD: CGFloat = 12,
        spacingLG: CGFloat = 16,
        spacingXL: CGFloat = 24,
        // Corner radius
        cornerRadius: CGFloat = 12,
        // Shadows (optional — sensible defaults)
        shadowSM: SlopShadow? = nil,
        shadowMD: SlopShadow? = nil,
        shadowLG: SlopShadow? = nil
    ) {
        self.background = background
        self.foreground = foreground
        self.secondary = secondary
        self.accent = accent
        self.surface = surface
        self.divider = divider

        self.success = success ?? Color(red: 0.32, green: 0.81, blue: 0.40)   // #51cf66
        self.warning = warning ?? Color(red: 1.0, green: 0.65, blue: 0.0)     // #ffa500
        self.error = error ?? Color(red: 1.0, green: 0.42, blue: 0.42)        // #ff6b6b
        self.muted = muted ?? secondary.opacity(0.6)
        self.border = border ?? divider.opacity(0.6)

        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.monoFont = monoFont
        self.bodyFontFamily = bodyFontFamily
        self.titleFontFamily = titleFontFamily
        self.monoFontFamily = monoFontFamily

        self.headingFont = headingFont ?? .system(.headline).weight(.semibold)
        self.subheadingFont = subheadingFont ?? .system(.subheadline).weight(.medium)
        self.captionFont = captionFont ?? .system(.caption)
        self.smallFont = smallFont ?? .system(.caption2)

        self.spacingXS = spacingXS
        self.spacingSM = spacingSM
        self.spacingMD = spacingMD
        self.spacingLG = spacingLG
        self.spacingXL = spacingXL

        self.cornerRadius = cornerRadius

        self.shadowSM = shadowSM ?? SlopShadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        self.shadowMD = shadowMD ?? SlopShadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        self.shadowLG = shadowLG ?? SlopShadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Theme Variants

extension SlopTheme {
    /// Returns a copy of this theme with `.clear` background.
    /// Used when a skin image provides the visual background.
    public func withClearBackground() -> SlopTheme {
        SlopTheme(
            background: .clear,
            foreground: foreground,
            secondary: secondary,
            accent: accent,
            surface: surface,
            divider: divider,
            success: success,
            warning: warning,
            error: error,
            muted: muted,
            border: border,
            titleFont: titleFont,
            bodyFont: bodyFont,
            monoFont: monoFont,
            bodyFontFamily: bodyFontFamily,
            titleFontFamily: titleFontFamily,
            monoFontFamily: monoFontFamily,
            headingFont: headingFont,
            subheadingFont: subheadingFont,
            captionFont: captionFont,
            smallFont: smallFont,
            spacingXS: spacingXS,
            spacingSM: spacingSM,
            spacingMD: spacingMD,
            spacingLG: spacingLG,
            spacingXL: spacingXL,
            cornerRadius: cornerRadius,
            shadowSM: shadowSM,
            shadowMD: shadowMD,
            shadowLG: shadowLG
        )
    }
}

// MARK: - Font Convenience Methods

extension SlopTheme {
    /// Body-family font at a custom size and weight.
    public func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let family = bodyFontFamily {
            return .custom(family, size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    /// Title-family font at a custom size and weight.
    public func title(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if let family = titleFontFamily {
            return .custom(family, size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    /// Mono-family font at a custom size and weight.
    public func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let family = monoFontFamily {
            return .custom(family, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - View Modifier for Shadows

extension View {
    /// Apply a `SlopShadow` to the view.
    public func slopShadow(_ shadow: SlopShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Environment

private struct SlopThemeKey: EnvironmentKey {
    static let defaultValue = SlopTheme(
        background: Color(red: 0.1, green: 0.1, blue: 0.12),
        foreground: .white,
        secondary: Color(white: 0.5),
        accent: Color(red: 0.5, green: 0.4, blue: 1.0),
        surface: Color(white: 0.15),
        divider: Color(white: 0.2)
    )
}

extension EnvironmentValues {
    public var slopTheme: SlopTheme {
        get { self[SlopThemeKey.self] }
        set { self[SlopThemeKey.self] = newValue }
    }
}
