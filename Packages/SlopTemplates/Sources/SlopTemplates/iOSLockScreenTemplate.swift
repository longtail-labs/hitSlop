import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct LockScreenNotification: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("App Name") var appName: String = ""
    @Field("App Icon") var appIcon: TemplateImage = TemplateImage("")
    @Field("Time Ago") var timeAgo: String = "now"
    @Field("Content") var content: String = ""
}

@SlopData
public struct iOSLockScreenData {
    @SlopKit.Section("Screen")
    @Field("Background") var background: TemplateImage = TemplateImage("")
    @Field("Time") var time: String = "09:41"
    @Field("Date") var date: String = "Monday, September 12"

    @SlopKit.Section("Status Bar")
    @Field("Show Status Bar") var showStatusBar: Bool = true

    @SlopKit.Section("Notifications")
    @Field("Notifications") var notifications: [LockScreenNotification] = iOSLockScreenData.defaultNotifications
}

extension iOSLockScreenData {
    static var defaultNotifications: [LockScreenNotification] {
        func notification(_ appName: String, _ timeAgo: String, _ content: String) -> LockScreenNotification {
            var n = LockScreenNotification()
            n.appName = appName
            n.timeAgo = timeAgo
            n.content = content
            return n
        }

        return [
            notification("Messages", "now", "Alex: See you at 10!"),
            notification("Mail", "2m ago", "Your order has shipped"),
            notification("Calendar", "8m ago", "Meeting in 30 minutes")
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.ios-lockscreen",
    name: "iOS Lock Screen",
    description: "Realistic iPhone lock screen mockup with notifications.",
    version: "1.0.0",
    width: 393, height: 852,
    minWidth: 320, minHeight: 500,
    shape: .roundedRect(radius: 47),
    alwaysOnTop: true,
    categories: ["media"]
)
struct iOSLockScreenView: View {
    @TemplateData var data: iOSLockScreenData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        ZStack {
            // Background layer
            backgroundLayer

            // Content overlay
            VStack(spacing: 0) {
                // Status bar
                if data.showStatusBar {
                    statusBar
                        .padding(.top, 12)
                }

                Spacer(minLength: 40)

                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                Text("iPhone")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .padding(.top, 4)

                Spacer(minLength: 30)

                // Date
                SlopTextField("Date", text: $data.date)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                // Time
                SlopTextField("Time", text: $data.time)
                    .font(.system(size: 88, weight: .ultraLight))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .padding(.top, 8)

                Spacer(minLength: 40)

                // Notifications
                VStack(spacing: 12) {
                    ForEach($data.notifications) { $notification in
                        iOSNotificationCard(
                            appName: $notification.appName,
                            content: $notification.content,
                            appIcon: $notification.appIcon,
                            timeAgo: $notification.timeAgo
                        )
                    }

                    SlopInteractiveOnly {
                        AddItemButton("Add Notification") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.notifications.append(LockScreenNotification())
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 40)

                // Bottom controls
                HStack(spacing: 40) {
                    BottomButton(icon: "flashlight.off.fill")
                    Spacer()
                    BottomButton(icon: "camera.fill")
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            .slopExportableFrame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .slopExportableFrame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var backgroundLayer: some View {
        ZStack {
            if !data.background.path.isEmpty {
                SlopImage(image: $data.background, placeholder: "Drop wallpaper")
                    .slopExportableFrame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                // Default gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0x1A/255, green: 0x1A/255, blue: 0x2E/255),
                        Color(red: 0x0F/255, green: 0x0F/255, blue: 0x1E/255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Dark overlay for readability
            Color.black.opacity(0.25)
        }
    }

    private var statusBar: some View {
        iOSStatusBar(time: "9:41", style: .light)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}



// MARK: - Bottom Button

struct BottomButton: View {
    let icon: String

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 50, height: 50)

            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.white)
        }
    }
}

