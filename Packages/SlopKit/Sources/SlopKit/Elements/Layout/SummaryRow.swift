import SwiftUI

/// A standardized row for displaying label-value pairs (totals, summaries).
///
/// Commonly used for summary sections showing totals, balances, or key metrics.
///
/// Example usage:
/// ```swift
/// SummaryRow(
///     label: "Total Expenses",
///     value: "$2,500",
///     valueColor: .red,
///     isBold: false
/// )
///
/// SummaryRow(
///     label: "Remaining",
///     value: "$1,200",
///     valueColor: theme.accent,
///     isBold: true
/// )
/// ```
public struct SummaryRow: View {
    let label: String
    let value: String
    let valueColor: Color
    let isBold: Bool

    @Environment(\.slopTheme) private var theme

    /// Creates a summary row.
    /// - Parameters:
    ///   - label: The label text (left side)
    ///   - value: The value text (right side)
    ///   - valueColor: The color for the value text (default: foreground)
    ///   - isBold: Whether to apply bold weight (default: false)
    public init(
        label: String,
        value: String,
        valueColor: Color? = nil,
        isBold: Bool = false
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor ?? .primary
        self.isBold = isBold
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(isBold ? theme.foreground : theme.secondary)
                .fontWeight(isBold ? .bold : .regular)
                .lineLimit(1...2)
                .truncationMode(.tail)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(valueColor)
                .fontWeight(isBold ? .bold : .semibold)
                .contentTransition(.numericText())
                .lineLimit(1...2)
                .truncationMode(.tail)
        }
    }
}
