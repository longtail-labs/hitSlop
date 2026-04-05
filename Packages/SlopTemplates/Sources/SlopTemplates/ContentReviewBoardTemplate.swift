import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct ReviewItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Media") var media: TemplateImage = TemplateImage("")
    @Field("Status", options: ["pending", "approved", "rejected", "revision"]) var status: String = "pending"
    @Field("Notes") var notes: String = ""
    @Field("Prompt") var prompt: String = ""
}

@SlopData
public struct ContentReviewBoardData {
    @Field("Title") var title: String = "Content Review"
    @Field("Items") var items: [ReviewItem] = ContentReviewBoardData.defaultItems

    var approvedCount: Int { items.filter { $0.status == "approved" }.count }
    var pendingCount: Int { items.filter { $0.status == "pending" }.count }
    var rejectedCount: Int { items.filter { $0.status == "rejected" }.count }
}

extension ContentReviewBoardData {
    static var defaultItems: [ReviewItem] {
        func item(_ prompt: String, _ status: String) -> ReviewItem {
            var i = ReviewItem()
            i.prompt = prompt
            i.status = status
            return i
        }
        return [
            item("Sunset over mountains, photorealistic", "pending"),
            item("Abstract gradient background, vibrant colors", "approved"),
            item("Product flat-lay, minimalist, white bg", "pending"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.content-review-board",
    name: "Content Review Board",
    description: "Approve/reject workflow for batch AI-generated content with status tracking.",
    version: "1.0.0",
    width: 500, height: 650,
    minWidth: 400, minHeight: 500,
    shape: .roundedRect(radius: 18),
    alwaysOnTop: true,
    categories: ["ai-content"]
)
struct ContentReviewBoardView: View {
    @TemplateData var data: ContentReviewBoardData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SlopTextField("Board Title", text: $data.title)
                        .font(theme.title(size: 22))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                }

                // Summary badges
                HStack(spacing: 8) {
                    StatBadge(count: data.approvedCount, label: "approved", tint: theme.success)
                    StatBadge(count: data.pendingCount, label: "pending", tint: theme.warning)
                    StatBadge(count: data.rejectedCount, label: "rejected", tint: theme.error)
                }

                Text("\(data.approvedCount)/\(data.items.count) approved")
                    .font(theme.mono(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondary)

                ThemeDivider()

                ForEach($data.items) { $item in
                    reviewCard(item: $item)
                }

                AddItemButton("Add Item") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.items.append(ReviewItem())
                    }
                }
            }
            .padding(20)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func reviewCard(item: Binding<ReviewItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                SlopImage(image: item.media, placeholder: "Drop image")
                    .frame(width: 100, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    StatusBadge(item.wrappedValue.status)

                    SlopTextField("Prompt used…", text: item.prompt)
                        .font(theme.font(size: 11))
                        .foregroundStyle(theme.foreground.opacity(0.8))
                        .lineLimit(2)

                    SlopTextField("Notes…", text: item.notes)
                        .font(theme.font(size: 10))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(2)
                }

                Spacer()

                RemoveButton {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.items.removeAll { $0.id == item.wrappedValue.id }
                    }
                }
            }

            // Action buttons
            SlopInteractiveOnly {
                HStack(spacing: 6) {
                    actionButton("Approve", icon: "checkmark.circle.fill", status: "approved", item: item)
                    actionButton("Reject", icon: "xmark.circle.fill", status: "rejected", item: item)
                    actionButton("Revision", icon: "arrow.triangle.2.circlepath", status: "revision", item: item)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surface)
        )
    }

    private func actionButton(_ label: String, icon: String, status: String, item: Binding<ReviewItem>) -> some View {
        Button {
            withAnimation { item.wrappedValue.status = status }
        } label: {
            Label(label, systemImage: icon)
                .font(theme.font(size: 10, weight: .medium))
                .foregroundStyle(item.wrappedValue.status == status ? theme.accent : theme.secondary)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
}
