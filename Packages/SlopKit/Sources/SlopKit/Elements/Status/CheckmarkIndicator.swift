import SwiftUI

/// A checkmark circle that toggles in interactive mode and shows static state in export.
///
/// ```swift
/// CheckmarkIndicator(isChecked: $task.isDone, tint: theme.accent)
/// ```
public struct CheckmarkIndicator: View {
    private let isChecked: Binding<Bool>
    private let tint: Color?
    private let size: CGFloat

    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    /// Creates a checkmark indicator.
    /// - Parameters:
    ///   - isChecked: Binding to the checked state.
    ///   - tint: The color when checked. Defaults to `theme.accent`.
    ///   - size: The circle diameter. Default is 18.
    public init(isChecked: Binding<Bool>, tint: Color? = nil, size: CGFloat = 18) {
        self.isChecked = isChecked
        self.tint = tint
        self.size = size
    }

    public var body: some View {
        if renderTarget == .interactive {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isChecked.wrappedValue.toggle()
                }
            } label: {
                indicator
            }
            .buttonStyle(.plain)
        } else {
            indicator
        }
    }

    private var indicator: some View {
        let resolvedTint = tint ?? theme.accent
        return Image(systemName: isChecked.wrappedValue ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isChecked.wrappedValue ? resolvedTint : theme.secondary)
            .font(.system(size: size * 0.85))
            .frame(width: size, height: size)
            .scaleEffect(isChecked.wrappedValue ? 1.0 : 0.9)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isChecked.wrappedValue)
    }
}
