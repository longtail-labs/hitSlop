import SwiftUI

/// A horizontal bar chart for comparing category values.
///
/// Displays categories with proportional bars and optional labels.
/// Commonly used for budget categories, time tracking, and comparisons.
///
/// Example usage:
/// ```swift
/// ColumnBarChart(
///     items: [
///         BarChartItem(name: "Housing", value: 1500, color: .red),
///         BarChartItem(name: "Food", value: 600, color: .orange),
///         BarChartItem(name: "Transport", value: 300, color: .blue)
///     ]
/// )
/// ```
public struct ColumnBarChart: View {
    let items: [BarChartItem]
    let showValues: Bool
    let barHeight: CGFloat

    @Environment(\.slopTheme) private var theme

    /// Creates a column bar chart.
    /// - Parameters:
    ///   - items: Array of items to display as bars
    ///   - showValues: Whether to display numeric values (default: true)
    ///   - barHeight: Height of each bar (default: 8)
    public init(
        items: [BarChartItem],
        showValues: Bool = true,
        barHeight: CGFloat = 8
    ) {
        self.items = items
        self.showValues = showValues
        self.barHeight = barHeight
    }

    public var body: some View {
        let total = items.reduce(0.0) { $0 + $1.value }

        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)

                    Text(item.name)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 70, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                        .truncationMode(.tail)

                    GeometryReader { geo in
                        let fraction = total > 0 ? item.value / total : 0
                        Capsule()
                            .fill(item.color)
                            .frame(width: geo.size.width * min(fraction, 1.0), height: barHeight)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: fraction)
                    }
                    .frame(height: barHeight)

                    if showValues {
                        Text(item.formattedValue ?? String(format: "%.0f", item.value))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.secondary.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .allowsTightening(true)
                            .truncationMode(.tail)
                    }
                }
            }
        }
    }
}

/// Represents a single bar in a column bar chart.
public struct BarChartItem: Identifiable {
    public let id = UUID()
    public let name: String
    public let value: Double
    public let color: Color
    public let formattedValue: String?

    /// Creates a bar chart item.
    /// - Parameters:
    ///   - name: The category/item name
    ///   - value: The numeric value
    ///   - color: The bar color
    ///   - formattedValue: Optional custom formatted value (e.g., "$1,500")
    public init(name: String, value: Double, color: Color, formattedValue: String? = nil) {
        self.name = name
        self.value = value
        self.color = color
        self.formattedValue = formattedValue
    }
}
