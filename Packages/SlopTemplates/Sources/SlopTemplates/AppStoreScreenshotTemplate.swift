import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct AppStoreScreenshotData {
    @SlopKit.Section("Content")
    @Field("Title") var title: String = "Feature Title"
    @Field("Subtitle") var subtitle: String = "A brief description"
    @Field("Screenshot") var screenshot: TemplateImage = TemplateImage("")

    @SlopKit.Section("Layout")
    @Field("Text Position", options: ["top", "bottom", "gradient", "sideBySide", "fullBleed", "glitch", "neonFrame"]) var textPosition: String = "top"
    @Field("Device Frame", options: ["iphone-6.9", "iphone-6.5", "iphone-6.1", "ipad-13", "ipad-11", "iphone", "ipad", "none"]) var deviceFrame: String = "iphone-6.9"
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.appstore-screenshot",
    name: "App Store Screenshot",
    description: "Compose polished App Store marketing screenshots with a title, subtitle, and hero artwork.",
    version: "1.0.0",
    width: 440, height: 860,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["marketing"]
)
struct AppStoreScreenshotView: View {
    @TemplateData var data: AppStoreScreenshotData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        ZStack {
            theme.background

            switch data.textPosition {
            case "bottom":
                VStack(spacing: 0) {
                    screenshotArea
                    Spacer(minLength: 12)
                    textArea
                    Spacer(minLength: 24)
                }
            case "gradient":
                gradientLayout
            case "sideBySide":
                sideBySideLayout
            case "fullBleed":
                fullBleedLayout
            case "glitch":
                glitchLayout
            case "neonFrame":
                neonFrameLayout
            default:
                VStack(spacing: 0) {
                    Spacer(minLength: 32)
                    textAreaLarge
                    Spacer(minLength: 24)
                    screenshotArea
                }
            }
        }
    }

    // MARK: - New Layouts

    private var gradientLayout: some View {
        ZStack {
            LinearGradient(
                colors: [theme.accent.opacity(0.8), theme.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                Spacer(minLength: 24)
                VStack(spacing: 6) {
                    SlopTextField("Feature Title", text: $data.title)
                        .font(theme.titleFont)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        .multilineTextAlignment(.center)
                    SlopTextField("Brief description", text: $data.subtitle)
                        .font(theme.bodyFont)
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                screenshotArea
                Spacer(minLength: 12)
            }
        }
    }

    private var sideBySideLayout: some View {
        HStack(spacing: 0) {
            screenshotContent
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                .padding(24)
                .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Spacer()
                SlopTextField("Feature Title", text: $data.title)
                    .font(theme.titleFont)
                    .foregroundStyle(theme.foreground)
                SlopTextField("Brief description", text: $data.subtitle)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private var fullBleedLayout: some View {
        ZStack(alignment: .bottom) {
            screenshotContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)

            VStack(spacing: 6) {
                SlopTextField("Feature Title", text: $data.title)
                    .font(theme.titleFont)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                SlopTextField("Brief description", text: $data.subtitle)
                    .font(theme.bodyFont)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var glitchLayout: some View {
        ZStack {
            Color(red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x11 / 255.0)

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                ZStack {
                    // Cyan layer (left offset)
                    SlopTextField("Feature Title", text: $data.title)
                        .font(theme.titleFont)
                        .foregroundStyle(.cyan)
                        .multilineTextAlignment(.center)
                        .offset(x: -2, y: 0)

                    // Magenta layer (right offset)
                    SlopTextField("Feature Title", text: $data.title)
                        .font(theme.titleFont)
                        .foregroundStyle(Color(red: 1.0, green: 0.0, blue: 1.0))
                        .multilineTextAlignment(.center)
                        .offset(x: 2, y: 0)

                    // White layer (center)
                    SlopTextField("Feature Title", text: $data.title)
                        .font(theme.titleFont)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 16)

                screenshotArea
                Spacer(minLength: 24)
            }
        }
    }

    private var neonFrameLayout: some View {
        ZStack {
            LinearGradient(
                colors: [theme.accent, theme.accent.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                screenshotContent
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(theme.accent, lineWidth: 2)
                            .shadow(color: theme.accent, radius: 8, x: 0, y: 0)
                            .shadow(color: theme.accent.opacity(0.5), radius: 16, x: 0, y: 0)
                    )
                    .padding(.horizontal, 32)

                Spacer(minLength: 16)

                VStack(spacing: 6) {
                    SlopTextField("Feature Title", text: $data.title)
                        .font(theme.titleFont)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    SlopTextField("Brief description", text: $data.subtitle)
                        .font(theme.bodyFont)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 24)
            }
        }
    }

    // MARK: - Text Area

    private var textAreaLarge: some View {
        VStack(spacing: 6) {
            SlopTextField("Feature Title", text: $data.title)
                .font(theme.title(size: 36))
                .foregroundStyle(theme.foreground)
                .multilineTextAlignment(.center)
            SlopTextField("Brief description", text: $data.subtitle)
                .font(theme.font(size: 18))
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private var textArea: some View {
        VStack(spacing: 6) {
            SlopTextField("Feature Title", text: $data.title)
                .font(theme.titleFont)
                .foregroundStyle(theme.foreground)
                .multilineTextAlignment(.center)
            SlopTextField("Brief description", text: $data.subtitle)
                .font(theme.bodyFont)
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Screenshot Area

    private var screenshotArea: some View {
        Group {
            if isIPhoneFrame {
                iphoneFrame
            } else if isIPadFrame {
                ipadFrame
            } else {
                bareScreenshot
            }
        }
        .padding(.horizontal, 32)
    }

    private var isIPhoneFrame: Bool {
        data.deviceFrame.hasPrefix("iphone")
    }

    private var isIPadFrame: Bool {
        data.deviceFrame.hasPrefix("ipad")
    }

    private var deviceAspectRatio: CGFloat {
        switch data.deviceFrame {
        case "iphone-6.9": return 1320.0 / 2868.0  // iPhone 16 Pro Max
        case "iphone-6.5": return 1290.0 / 2796.0  // iPhone 15 Plus / 14 Pro Max
        case "iphone-6.1": return 1179.0 / 2556.0  // iPhone 15 / 14 Pro
        case "ipad-13":    return 2064.0 / 2752.0   // iPad Pro 13"
        case "ipad-11":    return 1668.0 / 2388.0   // iPad Pro 11"
        case "iphone":     return 1320.0 / 2868.0   // Default to 6.9"
        case "ipad":       return 2064.0 / 2752.0   // Default to 13"
        default:           return 9.0 / 16.0
        }
    }

    private var iphoneFrame: some View {
        screenshotContent
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(theme.foreground.opacity(0.15), lineWidth: 3)
            )
            .padding(4)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(theme.foreground.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    private var ipadFrame: some View {
        screenshotContent
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.foreground.opacity(0.15), lineWidth: 3)
            )
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(theme.foreground.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    private var bareScreenshot: some View {
        screenshotContent
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
    }

    @ViewBuilder
    private var screenshotContent: some View {
        SlopImage(image: $data.screenshot, placeholder: "Drop screenshot here")
            .aspectRatio(deviceAspectRatio, contentMode: .fit)
            .background(theme.surface)
    }
}
