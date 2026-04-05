import Foundation
import SwiftUI
import SlopKit

/// JSON-decodable theme definition file.
/// Stored as `.theme` files in `~/.hitslop/themes/`.
public struct ThemeFile: Codable, Sendable {
    public var displayName: String?
    public var group: String?
    public var background: String?
    public var foreground: String?
    public var secondary: String?
    public var accent: String?
    public var surface: String?
    public var divider: String?
    public var titleFontFamily: String?
    public var bodyFontFamily: String?
    public var monoFontFamily: String?
    public var titleWeight: String?
    public var bodyWeight: String?
    public var cornerRadius: CGFloat?

    // Semantic colors
    public var success: String?
    public var warning: String?
    public var error: String?
    public var muted: String?
    public var border: String?

    // Typography scale
    public var headingFontFamily: String?
    public var headingWeight: String?
    public var subheadingFontFamily: String?
    public var subheadingWeight: String?
    public var captionFontFamily: String?
    public var captionWeight: String?

    // Spacing scale multiplier (1.0 = default)
    public var spacingScale: CGFloat?

    // Shadow overrides
    public var shadowColor: String?
    public var shadowOpacity: CGFloat?

    public init(
        displayName: String? = nil,
        group: String? = nil,
        background: String? = nil,
        foreground: String? = nil,
        secondary: String? = nil,
        accent: String? = nil,
        surface: String? = nil,
        divider: String? = nil,
        titleFontFamily: String? = nil,
        bodyFontFamily: String? = nil,
        monoFontFamily: String? = nil,
        titleWeight: String? = nil,
        bodyWeight: String? = nil,
        cornerRadius: CGFloat? = nil,
        success: String? = nil,
        warning: String? = nil,
        error: String? = nil,
        muted: String? = nil,
        border: String? = nil,
        headingFontFamily: String? = nil,
        headingWeight: String? = nil,
        subheadingFontFamily: String? = nil,
        subheadingWeight: String? = nil,
        captionFontFamily: String? = nil,
        captionWeight: String? = nil,
        spacingScale: CGFloat? = nil,
        shadowColor: String? = nil,
        shadowOpacity: CGFloat? = nil
    ) {
        self.displayName = displayName
        self.group = group
        self.background = background
        self.foreground = foreground
        self.secondary = secondary
        self.accent = accent
        self.surface = surface
        self.divider = divider
        self.titleFontFamily = titleFontFamily
        self.bodyFontFamily = bodyFontFamily
        self.monoFontFamily = monoFontFamily
        self.titleWeight = titleWeight
        self.bodyWeight = bodyWeight
        self.cornerRadius = cornerRadius
        self.success = success
        self.warning = warning
        self.error = error
        self.muted = muted
        self.border = border
        self.headingFontFamily = headingFontFamily
        self.headingWeight = headingWeight
        self.subheadingFontFamily = subheadingFontFamily
        self.subheadingWeight = subheadingWeight
        self.captionFontFamily = captionFontFamily
        self.captionWeight = captionWeight
        self.spacingScale = spacingScale
        self.shadowColor = shadowColor
        self.shadowOpacity = shadowOpacity
    }

    func isSupported(for source: ThemeCatalog.Source) -> Bool {
        guard source != .bundled else { return true }
        return displayName != nil && group != nil
    }

    public func toSlopTheme() -> SlopTheme? {
        guard let background = background.flatMap(Color.init(hex:)),
              let foreground = foreground.flatMap(Color.init(hex:)),
              let secondary = secondary.flatMap(Color.init(hex:)),
              let accent = accent.flatMap(Color.init(hex:)),
              let surface = surface.flatMap(Color.init(hex:)),
              let divider = divider.flatMap(Color.init(hex:))
        else {
            return nil
        }

        let scale = spacingScale ?? 1.0

        return SlopTheme(
            background: background,
            foreground: foreground,
            secondary: secondary,
            accent: accent,
            surface: surface,
            divider: divider,
            success: success.flatMap(Color.init(hex:)),
            warning: warning.flatMap(Color.init(hex:)),
            error: error.flatMap(Color.init(hex:)),
            muted: muted.flatMap(Color.init(hex:)),
            border: border.flatMap(Color.init(hex:)),
            titleFont: makeFont(
                family: titleFontFamily,
                size: 24,
                textStyle: .title,
                weight: fontWeight(from: titleWeight, fallback: .bold)
            ),
            bodyFont: makeFont(
                family: bodyFontFamily,
                size: 14,
                textStyle: .body,
                weight: fontWeight(from: bodyWeight, fallback: .regular)
            ),
            monoFont: makeFont(
                family: monoFontFamily ?? "Menlo",
                size: 12,
                textStyle: .body,
                weight: .medium
            ),
            bodyFontFamily: bodyFontFamily,
            titleFontFamily: titleFontFamily,
            monoFontFamily: monoFontFamily ?? "Menlo",
            headingFont: makeFont(
                family: headingFontFamily ?? titleFontFamily,
                size: 17,
                textStyle: .headline,
                weight: fontWeight(from: headingWeight ?? titleWeight, fallback: .semibold)
            ),
            subheadingFont: makeFont(
                family: subheadingFontFamily ?? bodyFontFamily,
                size: 15,
                textStyle: .subheadline,
                weight: fontWeight(from: subheadingWeight ?? bodyWeight, fallback: .medium)
            ),
            captionFont: makeFont(
                family: captionFontFamily ?? bodyFontFamily,
                size: 12,
                textStyle: .caption,
                weight: fontWeight(from: captionWeight, fallback: .regular)
            ),
            spacingXS: 4 * scale,
            spacingSM: 8 * scale,
            spacingMD: 12 * scale,
            spacingLG: 16 * scale,
            spacingXL: 24 * scale,
            cornerRadius: cornerRadius ?? 16,
            shadowSM: shadowDef(opacity: 0.1, radius: 2, y: 1),
            shadowMD: shadowDef(opacity: 0.15, radius: 4, y: 2),
            shadowLG: shadowDef(opacity: 0.2, radius: 8, y: 4)
        )
    }

    private func shadowDef(opacity: CGFloat, radius: CGFloat, y: CGFloat) -> SlopShadow {
        let baseColor = shadowColor.flatMap(Color.init(hex:)) ?? .black
        let op = shadowOpacity ?? opacity
        return SlopShadow(color: baseColor.opacity(op), radius: radius, x: 0, y: y)
    }

    private func makeFont(
        family: String?,
        size: CGFloat,
        textStyle: Font.TextStyle,
        weight: Font.Weight
    ) -> Font {
        if let family, !family.isEmpty {
            return .custom(family, size: size).weight(weight)
        }
        return .system(textStyle, weight: weight)
    }

    private func fontWeight(from rawValue: String?, fallback: Font.Weight) -> Font.Weight {
        switch rawValue?.lowercased() {
        case "ultralight":
            return .ultraLight
        case "thin":
            return .thin
        case "light":
            return .light
        case "medium":
            return .medium
        case "semibold":
            return .semibold
        case "bold":
            return .bold
        case "heavy":
            return .heavy
        case "black":
            return .black
        default:
            return fallback
        }
    }
}
