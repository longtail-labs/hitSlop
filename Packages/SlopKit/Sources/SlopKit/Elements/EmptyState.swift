import SwiftUI

/// A standardized empty state component with icon, title, and subtitle.
///
/// Displays when a list or collection has no items, providing visual feedback
/// and guidance to the user.
///
/// Example usage:
/// ```swift
/// if items.isEmpty {
///     EmptyState(
///         icon: "checklist",
///         title: "No items yet",
///         subtitle: "Add an item to get started"
///     )
/// }
/// ```
public struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String?

    @Environment(\.slopTheme) private var theme

    /// Creates an empty state view.
    /// - Parameters:
    ///   - icon: The SF Symbol name to display
    ///   - title: The main title text
    ///   - subtitle: Optional subtitle text for additional guidance
    public init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(theme.secondary.opacity(0.3))
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondary.opacity(0.5))
                .lineLimit(1...4)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(theme.secondary.opacity(0.3))
                    .lineLimit(1...4)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
