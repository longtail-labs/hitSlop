import SwiftUI

/// A themed divider that uses `theme.divider` color.
///
/// Replaces the common pattern `Divider().background(theme.divider)`.
///
/// ```swift
/// ThemeDivider()
/// ThemeDivider(opacity: 0.5)
/// ```
public struct ThemeDivider: View {
    private let opacity: Double

    @Environment(\.slopTheme) private var theme

    public init(opacity: Double = 1.0) {
        self.opacity = opacity
    }

    public var body: some View {
        Divider().background(theme.divider.opacity(opacity))
    }
}
