import SwiftUI

/// A donut chart (ring chart) with colored segments and optional center label.
///
/// Displays data as circular segments with smooth animations. Commonly used for
/// budget breakdowns, category distributions, and completion ratios.
///
/// Example usage:
/// ```swift
/// DonutChart(
///     segments: [
///         DonutSegment(color: .red, fraction: 0.4, label: "Housing"),
///         DonutSegment(color: .blue, fraction: 0.3, label: "Food"),
///         DonutSegment(color: .green, fraction: 0.3, label: "Transport")
///     ],
///     centerLabel: "$1,200 left",
///     size: 100,
///     lineWidth: 16
/// )
/// ```
public struct DonutChart: View {
    let segments: [DonutSegment]
    let centerLabel: String?
    let size: CGFloat
    let lineWidth: CGFloat
    let backgroundColor: Color

    /// Creates a donut chart.
    /// - Parameters:
    ///   - segments: Array of segments to display
    ///   - centerLabel: Optional text to display in the center
    ///   - size: The diameter of the chart (default: 100)
    ///   - lineWidth: The width of the ring (default: 16)
    ///   - backgroundColor: The background ring color (default: theme surface)
    public init(
        segments: [DonutSegment],
        centerLabel: String? = nil,
        size: CGFloat = 100,
        lineWidth: CGFloat = 16,
        backgroundColor: Color
    ) {
        self.segments = segments
        self.centerLabel = centerLabel
        self.size = size
        self.lineWidth = lineWidth
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Colored segments
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                let startAngle = segmentStart(index: index)
                let endAngle = startAngle + segment.fraction
                Circle()
                    .trim(from: startAngle, to: endAngle)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: segment.fraction)
            }

            // Center label
            if let centerLabel {
                Text(centerLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2...)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, lineWidth)
            }
        }
    }

    private func segmentStart(index: Int) -> Double {
        segments.prefix(index).reduce(0.0) { $0 + $1.fraction }
    }
}

/// Represents a single segment in a donut chart.
public struct DonutSegment: Identifiable {
    public let id = UUID()
    public let color: Color
    public let fraction: Double
    public let label: String

    /// Creates a donut chart segment.
    /// - Parameters:
    ///   - color: The color of the segment
    ///   - fraction: The fraction of the circle (0.0 to 1.0)
    ///   - label: A descriptive label for the segment
    public init(color: Color, fraction: Double, label: String) {
        self.color = color
        self.fraction = max(0, min(1, fraction))
        self.label = label
    }
}
