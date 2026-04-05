import SwiftUI

/// A streak badge component showing a count with an icon.
///
/// Displays a styled badge with a count and flame/star icon, commonly used
/// in habit tracking and gamification interfaces.
///
/// ```swift
/// StreakBadge(count: 7, icon: "flame.fill")
/// StreakBadge(count: 15, icon: "star.fill", color: .yellow)
/// ```
public struct StreakBadge: View {
    var count: Int
    var icon: String = "flame.fill"
    var color: Color = .orange
    var size: BadgeSize = .medium

    public enum BadgeSize {
        case small
        case medium
        case large

        var fontSize: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 13
            case .large: return 15
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
    }

    public init(count: Int, icon: String = "flame.fill", color: Color = .orange, size: BadgeSize = .medium) {
        self.count = count
        self.icon = icon
        self.color = color
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
            Text("\(count)")
                .font(.system(size: size.fontSize, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, size.padding)
        .padding(.vertical, size.padding - 2)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}
