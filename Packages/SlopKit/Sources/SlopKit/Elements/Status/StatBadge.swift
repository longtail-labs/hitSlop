import SwiftUI

/// A count + label badge, e.g., "5 done" or "3 left".
///
/// ```swift
/// StatBadge(count: 5, label: "done", tint: theme.accent)
/// StatBadge(count: data.remaining, label: "left", tint: theme.secondary)
/// ```
public struct StatBadge: View {
    private let count: Int
    private let label: String
    private let tint: Color

    @Environment(\.slopTheme) private var theme

    public init(count: Int, label: String, tint: Color) {
        self.count = count
        self.label = label
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .truncationMode(.tail)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}
