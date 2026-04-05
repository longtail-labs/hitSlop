import SwiftUI

/// A horizontal capsule-shaped progress bar with animated fill.
///
/// Displays progress as a fraction from 0.0 to 1.0 with smooth spring animation.
///
/// Example usage:
/// ```swift
/// ProgressBar(
///     progress: Double(completedCount) / Double(totalCount),
///     fillColor: theme.accent,
///     backgroundColor: theme.surface,
///     height: 10
/// )
/// ```
public struct ProgressBar: View {
    let progress: Double
    let fillColor: Color
    let backgroundColor: Color
    let height: CGFloat

    /// Creates a progress bar.
    /// - Parameters:
    ///   - progress: Progress value from 0.0 to 1.0
    ///   - fillColor: The fill color for completed portion
    ///   - backgroundColor: The background color for unfilled portion
    ///   - height: The height of the progress bar (default: 10)
    public init(
        progress: Double,
        fillColor: Color,
        backgroundColor: Color,
        height: CGFloat = 10
    ) {
        self.progress = max(0, min(1, progress))
        self.fillColor = fillColor
        self.backgroundColor = backgroundColor
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(backgroundColor)
                    .frame(height: height)
                Capsule()
                    .fill(fillColor)
                    .frame(width: proxy.size.width * progress, height: height)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
            }
        }
        .frame(height: height)
    }
}
