import SwiftUI

/// A profile avatar component with customizable size and icon overlay.
///
/// Displays a circular avatar with an optional icon overlay, commonly used
/// in social media mockups, contact cards, and user profile displays.
///
/// ```swift
/// ProfileAvatar(
///     image: $data.avatar,
///     size: 48,
///     fallbackIcon: "person.fill"
/// )
/// ```
public struct ProfileAvatar: View {
    var image: Binding<TemplateImage>?
    var size: CGFloat = 40
    var fallbackIcon: String = "person.fill"
    var fallbackColor: Color = .gray.opacity(0.3)

    public init(
        image: Binding<TemplateImage>? = nil,
        size: CGFloat = 40,
        fallbackIcon: String = "person.fill",
        fallbackColor: Color = .gray.opacity(0.3)
    ) {
        self.image = image
        self.size = size
        self.fallbackIcon = fallbackIcon
        self.fallbackColor = fallbackColor
    }

    public var body: some View {
        Group {
            if let imageBinding = image, !imageBinding.wrappedValue.path.isEmpty {
                SlopImage(image: imageBinding, placeholder: "")
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(fallbackColor)
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: fallbackIcon)
                            .font(.system(size: size * 0.45))
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }
        }
    }
}
