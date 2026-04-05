import SwiftUI

/// A themed status badge that displays a label in a capsule.
///
/// Automatically detects appropriate style from common status strings,
/// or accepts a manual style override.
///
/// ```swift
/// StatusBadge("Paid")           // → success (green)
/// StatusBadge("Draft")          // → muted
/// StatusBadge("Active", style: .accent)
/// StatusBadge("Custom", color: .purple)
/// ```
public struct StatusBadge: View {
    public enum Style {
        case success, warning, error, muted, accent
    }

    private let label: String
    private let style: Style?
    private let customColor: Color?

    @Environment(\.slopTheme) private var theme

    /// Creates a status badge with automatic style detection.
    public init(_ label: String) {
        self.label = label
        self.style = nil
        self.customColor = nil
    }

    /// Creates a status badge with an explicit style.
    public init(_ label: String, style: Style) {
        self.label = label
        self.style = style
        self.customColor = nil
    }

    /// Creates a status badge with a custom color.
    public init(_ label: String, color: Color) {
        self.label = label
        self.style = nil
        self.customColor = color
    }

    public var body: some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(badgeForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(badgeBackground))
    }

    // MARK: - Resolved Colors

    private var resolvedStyle: Style {
        if let style { return style }
        return Self.detectStyle(from: label)
    }

    private var badgeForeground: Color {
        if let customColor { return customColor }
        switch resolvedStyle {
        case .success: return theme.success
        case .warning: return theme.warning
        case .error: return theme.error
        case .muted: return theme.secondary
        case .accent: return theme.accent
        }
    }

    private var badgeBackground: Color {
        if let customColor { return customColor.opacity(0.18) }
        switch resolvedStyle {
        case .success: return theme.success.opacity(0.18)
        case .warning: return theme.warning.opacity(0.18)
        case .error: return theme.error.opacity(0.18)
        case .muted: return theme.surface
        case .accent: return theme.accent.opacity(0.18)
        }
    }

    // MARK: - Auto-Detection

    static func detectStyle(from text: String) -> Style {
        switch text.lowercased() {
        case "paid", "finished", "done", "completed", "active", "approved", "success":
            return .success
        case "outstanding", "pending", "in progress", "reading", "review", "waiting":
            return .warning
        case "overdue", "failed", "error", "cancelled", "rejected", "expired":
            return .error
        case "draft", "inactive", "archived", "closed", "paused", "n/a":
            return .muted
        default:
            return .accent
        }
    }
}
