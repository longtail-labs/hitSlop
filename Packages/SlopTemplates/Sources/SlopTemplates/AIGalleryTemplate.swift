import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct GalleryItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Image") var image: TemplateImage = TemplateImage("")
    @Field("Caption") var caption: String = ""
    @Field("Rating") var rating: Double = 0
    @Field("Prompt") var prompt: String = ""
}

@SlopData
public struct AIGalleryData {
    @Field("Title") var title: String = "AI Gallery"
    @Field("Items") var items: [GalleryItem] = AIGalleryData.defaultItems

    var ratedCount: Int { items.filter { $0.rating > 0 }.count }
}

extension AIGalleryData {
    static var defaultItems: [GalleryItem] {
        func item(_ caption: String, _ prompt: String) -> GalleryItem {
            var i = GalleryItem()
            i.caption = caption
            i.prompt = prompt
            return i
        }
        return [
            item("Sunset cityscape", "A futuristic cityscape at golden hour, cinematic lighting"),
            item("Portrait study", "Professional headshot, studio lighting, neutral background"),
            item("Product shot", "Minimal product photography, white background, soft shadows"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.ai-gallery",
    name: "AI Gallery",
    description: "Grid of AI-generated images with captions, ratings, and prompt tracking.",
    version: "1.0.0",
    width: 600, height: 700,
    minWidth: 460, minHeight: 500,
    shape: .roundedRect(radius: 18),
    alwaysOnTop: true,
    categories: ["ai-content"]
)
struct AIGalleryView: View {
    @TemplateData var data: AIGalleryData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SlopTextField("Gallery Title", text: $data.title)
                        .font(theme.title(size: 24))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    StatBadge(count: data.items.count, label: "items", tint: theme.accent)
                }

                if data.ratedCount > 0 {
                    Text("\(data.ratedCount) of \(data.items.count) rated")
                        .font(theme.mono(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondary)
                }

                ThemeDivider()

                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ]

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach($data.items) { $item in
                        galleryCard(item: $item)
                    }
                }

                AddItemButton("Add Image") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.items.append(GalleryItem())
                    }
                }
            }
            .padding(20)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func galleryCard(item: Binding<GalleryItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SlopImage(image: item.image, placeholder: "Drop image")
                .frame(minHeight: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            SlopTextField("Caption", text: item.caption)
                .font(theme.font(size: 12, weight: .medium))
                .foregroundStyle(theme.foreground)
                .lineLimit(2)

            starRating(value: item.rating)

            SlopTextField("Prompt used…", text: item.prompt)
                .font(theme.font(size: 10))
                .foregroundStyle(theme.secondary)
                .lineLimit(2)

            HStack {
                Spacer()
                RemoveButton {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.items.removeAll { $0.id == item.wrappedValue.id }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surface)
        )
    }

    @ViewBuilder
    private func starRating(value: Binding<Double>) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                SlopInteractiveOnly {
                    Button {
                        value.wrappedValue = Double(star)
                    } label: {
                        Image(systemName: Double(star) <= value.wrappedValue ? "star.fill" : "star")
                            .font(theme.font(size: 10))
                            .foregroundStyle(Double(star) <= value.wrappedValue ? theme.accent : theme.secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
