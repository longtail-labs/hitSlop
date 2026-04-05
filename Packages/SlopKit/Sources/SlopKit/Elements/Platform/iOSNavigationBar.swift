import SwiftUI

/// A realistic iOS navigation bar mock component.
///
/// Displays a back button, centered title with optional avatar, and action icons.
/// Automatically hides interactive-only elements (like the back button) in export mode.
///
/// ```swift
/// iOSNavigationBar(
///     title: $data.contactName,
///     avatar: $data.contactAvatar,
///     showBackButton: true,
///     accentColor: iosBlue
/// )
/// ```
public struct iOSNavigationBar: View {
    @Binding var title: String
    var avatar: Binding<TemplateImage>?
    var showBackButton: Bool = true
    var backButtonText: String = "Messages"
    var accentColor: Color = Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255)
    var backgroundColor: Color = Color(red: 0xF9/255, green: 0xF9/255, blue: 0xF9/255)
    var trailingIcons: [String] = ["phone.fill", "video.fill"]

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(
        title: Binding<String>,
        avatar: Binding<TemplateImage>? = nil,
        showBackButton: Bool = true,
        backButtonText: String = "Messages",
        accentColor: Color = Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255),
        backgroundColor: Color = Color(red: 0xF9/255, green: 0xF9/255, blue: 0xF9/255),
        trailingIcons: [String] = ["phone.fill", "video.fill"]
    ) {
        self._title = title
        self.avatar = avatar
        self.showBackButton = showBackButton
        self.backButtonText = backButtonText
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.trailingIcons = trailingIcons
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Back button - hidden in export
                if showBackButton {
                    SlopInteractiveOnly {
                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(backButtonText)
                                    .font(.system(size: 17))
                            }
                            .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Center title with avatar
                VStack(spacing: 2) {
                    if let avatarBinding = avatar, !avatarBinding.wrappedValue.path.isEmpty {
                        SlopImage(image: avatarBinding, placeholder: "")
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                    }

                    SlopTextField("Title", text: $title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Trailing icons - hidden in export
                SlopInteractiveOnly {
                    HStack(spacing: 20) {
                        ForEach(trailingIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 16))
                        }
                    }
                    .foregroundStyle(accentColor)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(backgroundColor)

            Divider()
                .background(Color.gray.opacity(0.2))
        }
    }
}
