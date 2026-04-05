import SwiftUI

/// A standardized checklist row combining a checkmark, text field, and remove button.
///
/// Handles interactive vs export modes automatically:
/// - Interactive: toggleable checkmark, editable text, remove button
/// - Export: static checkmark, plain text, no remove button
///
/// ```swift
/// ForEach($data.tasks) { $task in
///     ChecklistItem(
///         title: $task.title,
///         isChecked: $task.isDone,
///         onRemove: { data.tasks.removeAll { $0.id == task.id } }
///     )
/// }
/// ```
public struct ChecklistItem: View {
    private let title: Binding<String>
    private let isChecked: Binding<Bool>
    private let placeholder: String
    private let onRemove: (() -> Void)?
    private let checkedFont: Font.Weight
    private let uncheckedFont: Font.Weight

    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    public init(
        title: Binding<String>,
        isChecked: Binding<Bool>,
        placeholder: String = "Task",
        checkedFont: Font.Weight = .regular,
        uncheckedFont: Font.Weight = .medium,
        onRemove: (() -> Void)? = nil
    ) {
        self.title = title
        self.isChecked = isChecked
        self.placeholder = placeholder
        self.checkedFont = checkedFont
        self.uncheckedFont = uncheckedFont
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: 12) {
            CheckmarkIndicator(isChecked: isChecked)

            SlopTextField(placeholder, text: title)
                .foregroundStyle(isChecked.wrappedValue ? theme.secondary : theme.foreground)
                .strikethrough(isChecked.wrappedValue, color: theme.secondary)

            if renderTarget != .interactive {
                Spacer()
            }

            if let onRemove {
                RemoveButton(action: onRemove)
            }
        }
        .font(.system(size: 14, weight: isChecked.wrappedValue ? checkedFont : uncheckedFont))
    }
}
