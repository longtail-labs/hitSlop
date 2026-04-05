import SwiftUI

/// A standardized section header with uppercase monospaced styling.
///
/// Provides consistent typography for section labels across templates.
///
/// Example usage:
/// ```swift
/// SectionHeader("Tasks")
/// SectionHeader("Budget Categories")
/// ```
public struct SectionHeader: View {
    let text: String

    @Environment(\.slopTheme) private var theme

    /// Creates a section header.
    /// - Parameter text: The header text
    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(theme.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
            .truncationMode(.tail)
    }
}
