import SwiftUI

/// A capsule-shaped badge displaying a metric with a tinted background.
///
/// Commonly used for status indicators, counts, and other small numeric displays.
///
/// Example usage:
/// ```swift
/// MetricPill("5 done", tint: theme.accent)
/// MetricPill("3 left", tint: theme.secondary)
/// ```
public struct MetricPill: View {
    let text: String
    let tint: Color

    @Environment(\.slopTheme) private var theme

    /// Creates a metric pill with custom text and tint color.
    /// - Parameters:
    ///   - text: The text to display in the pill
    ///   - tint: The tint color
    public init(_ text: String, tint: Color) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
    }
}
