import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct SocialPostPreviewData {
    @SlopKit.Section("Content")
    @Field("Media") var media: TemplateImage = TemplateImage("")
    @Field("Caption") var caption: String = "Your caption here ✨"
    @Field("Hashtags") var hashtags: String = "#ai #generated #art"
    @Field("Username") var username: String = "@yourhandle"

    @SlopKit.Section("Platform")
    @Field("Platform", options: ["Instagram Post", "Instagram Story", "TikTok"]) var platform: String = "Instagram Post"
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.social-post-preview",
    name: "Social Post Preview",
    description: "Mockup how AI content will look as an Instagram post, story, or TikTok.",
    version: "1.0.0",
    width: 420, height: 700,
    minWidth: 360, minHeight: 560,
    shape: .roundedRect(radius: 18),
    alwaysOnTop: true,
    categories: ["media"]
)
struct SocialPostPreviewView: View {
    @TemplateData var data: SocialPostPreviewData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(spacing: 0) {
                // Platform selector
                HStack {
                    SlopTextField("Platform", text: $data.platform)
                        .font(theme.mono(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    StatusBadge(data.platform)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                ThemeDivider()

                // Device mockup
                VStack(spacing: 0) {
                    // Profile header
                    HStack(spacing: 8) {
                        Circle()
                            .fill(theme.accent.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(theme.font(size: 12))
                                    .foregroundStyle(theme.accent)
                            )
                        SlopTextField("@handle", text: $data.username)
                            .font(theme.font(size: 12, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                        Spacer()
                        Image(systemName: "ellipsis")
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    // Media area with aspect ratio per platform
                    SlopMedia(media: $data.media, placeholder: "Drop photo or video")
                        .aspectRatio(platformAspectRatio, contentMode: .fit)
                        .background(theme.surface)
                        .clipped()

                    // Engagement row (static mockup)
                    if !isStoryOrTikTok {
                        HStack(spacing: 16) {
                            Image(systemName: "heart")
                            Image(systemName: "bubble.right")
                            Image(systemName: "paperplane")
                            Spacer()
                            Image(systemName: "bookmark")
                        }
                        .font(theme.font(size: 16))
                        .foregroundStyle(theme.foreground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }

                    // Caption area
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 4) {
                            Text(data.username)
                                .font(theme.font(size: 12, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                            SlopTextField("Write a caption…", text: $data.caption)
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.foreground)
                        }
                        SlopTextField("#hashtags", text: $data.hashtags)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.accent.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(16)

                Spacer(minLength: 0)
            }
        }
        .background(theme.background)
    }

    private var platformAspectRatio: CGFloat {
        switch data.platform {
        case "Instagram Post":
            return 1.0 / 1.0      // Square
        case "Instagram Story", "TikTok":
            return 9.0 / 16.0     // Tall portrait
        default:
            return 1.0 / 1.0
        }
    }

    private var isStoryOrTikTok: Bool {
        data.platform == "Instagram Story" || data.platform == "TikTok"
    }
}
