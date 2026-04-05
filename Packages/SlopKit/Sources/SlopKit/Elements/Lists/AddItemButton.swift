import SwiftUI

/// A standardized button for adding new items to a list.
///
/// Provides consistent styling and animation across all templates.
/// Only visible in interactive mode (hidden during export).
///
/// Example usage:
/// ```swift
/// AddItemButton("Add Task") {
///     withAnimation { data.tasks.append(Task()) }
/// }
/// ```
public struct AddItemButton: View {
    let label: String
    let action: () -> Void

    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    /// Creates an add item button.
    /// - Parameters:
    ///   - label: The button label (e.g., "Add Task", "Add Category")
    ///   - action: The action to perform when tapped
    public init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        if renderTarget == .interactive {
            Button(action: action) {
                Label(label, systemImage: "plus")
                    .font(.caption)
                    .foregroundStyle(theme.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }
}
