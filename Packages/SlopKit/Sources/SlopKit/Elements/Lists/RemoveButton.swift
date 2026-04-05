import SwiftUI

/// A standardized button for removing items from a list.
///
/// Displays a small minus icon with consistent styling.
/// Only visible in interactive mode (hidden during export).
///
/// Example usage:
/// ```swift
/// RemoveButton {
///     withAnimation { data.items.removeAll { $0.id == item.id } }
/// }
/// ```
public struct RemoveButton: View {
    let action: () -> Void

    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    /// Creates a remove button.
    /// - Parameter action: The action to perform when tapped
    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        if renderTarget == .interactive {
            Button(action: action) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
    }
}
