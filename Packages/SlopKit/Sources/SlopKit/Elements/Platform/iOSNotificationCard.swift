import SwiftUI

/// A realistic iOS lock screen notification card component.
///
/// Displays a notification with app icon, name, time ago, and content
/// in the iOS lock screen style with material background.
///
/// ```swift
/// iOSNotificationCard(
///     appName: $notification.appName,
///     content: $notification.content,
///     appIcon: $notification.appIcon,
///     timeAgo: $notification.timeAgo
/// )
/// ```
public struct iOSNotificationCard: View {
    @Binding var appName: String
    @Binding var content: String
    var appIcon: Binding<TemplateImage>?
    @Binding var timeAgo: String

    public init(
        appName: Binding<String>,
        content: Binding<String>,
        appIcon: Binding<TemplateImage>? = nil,
        timeAgo: Binding<String>
    ) {
        self._appName = appName
        self._content = content
        self.appIcon = appIcon
        self._timeAgo = timeAgo
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // App icon
            if let appIconBinding = appIcon, !appIconBinding.wrappedValue.path.isEmpty {
                SlopImage(image: appIconBinding, placeholder: "")
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }

            // Notification content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    SlopTextField("App Name", text: $appName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    SlopTextField("now", text: $timeAgo)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                }

                SlopTextField("Notification content", text: $content)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
            }

            SlopInteractiveOnly {
                RemoveButton {
                    // Parent will handle removal
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}
