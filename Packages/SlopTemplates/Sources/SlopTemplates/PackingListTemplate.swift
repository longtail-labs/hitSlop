import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct PackingItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Packed") var packed: Bool = false
    @Field("Quantity") var quantity: Double = 1
}

@SlopData
public struct PackingCategory: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Items") var items: [PackingItem] = []

    var packedCount: Int { items.filter(\.packed).count }
}

@SlopData
public struct PackingListData {
    @SlopKit.Section("Trip")
    @Field("Title") var title: String = "Packing List"
    @Field("Emoji") var emoji: String = "🧳"
    @Field("Departure Date") var departureDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    @SlopKit.Section("Categories")
    @Field("Categories") var categories: [PackingCategory] = PackingListData.defaultCategories

    var totalItems: Int { categories.reduce(0) { $0 + $1.items.count } }
    var packedItems: Int { categories.reduce(0) { $0 + $1.packedCount } }
    var packedPercentage: Double { totalItems > 0 ? Double(packedItems) / Double(totalItems) : 0 }
}

extension PackingListData {
    static var defaultCategories: [PackingCategory] {
        func item(_ name: String, _ qty: Double = 1) -> PackingItem {
            var i = PackingItem()
            i.name = name
            i.quantity = qty
            return i
        }

        func category(_ name: String, _ items: [PackingItem]) -> PackingCategory {
            var c = PackingCategory()
            c.name = name
            c.items = items
            return c
        }

        return [
            category("Clothes", [
                item("T-shirts", 4), item("Pants", 2), item("Underwear", 5),
                item("Socks", 4), item("Jacket")
            ]),
            category("Toiletries", [
                item("Toothbrush"), item("Toothpaste"), item("Deodorant"),
                item("Shampoo"), item("Sunscreen")
            ]),
            category("Electronics", [
                item("Phone charger"), item("Laptop"), item("Headphones"),
                item("Power adapter")
            ]),
            category("Documents", [
                item("Passport"), item("Boarding pass"), item("Hotel confirmation"),
                item("Travel insurance")
            ]),
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.packing-list",
    name: "Packing List",
    description: "Organize and track your packing with categories and checklists.",
    version: "1.0.0",
    width: 380, height: 520,
    minWidth: 320, minHeight: 400,
    shape: .roundedRect(radius: 16),
    theme: "ocean-glass",
    alwaysOnTop: true,
    categories: ["travel"]
)
struct PackingListView: View {
    @TemplateData var data: PackingListData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    SlopEmojiPicker($data.emoji)
                        .travelEmojis()
                        .font(.system(size: 22))
                    SlopTextField("Title", text: $data.title)
                        .font(theme.title(size: 22))
                        .foregroundStyle(theme.foreground)
                }

                HStack(spacing: 12) {
                    SlopEditable($data.departureDate) { value in
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .foregroundStyle(theme.secondary)
                            Text(value, style: .date)
                                .foregroundStyle(theme.secondary)
                        }
                        .font(theme.font(size: 12))
                    } editor: { $value in
                        DatePicker("", selection: $value, displayedComponents: .date)
                            .labelsHidden()
                    }
                }

                ThemeDivider()

                // Progress
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(data.packedItems)/\(data.totalItems) packed")
                            .font(theme.font(size: 12, weight: .medium))
                            .foregroundStyle(theme.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", data.packedPercentage * 100))
                            .font(theme.font(size: 12, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                    ProgressBar(progress: data.packedPercentage, fillColor: theme.accent, backgroundColor: theme.surface)
                }

                HStack(spacing: 8) {
                    StatBadge(count: data.packedItems, label: "Packed", tint: .green)
                    StatBadge(count: data.totalItems - data.packedItems, label: "Remaining", tint: .orange)
                }

                // Categories
                ForEach($data.categories) { $category in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SlopTextField("Category", text: $category.name)
                                .font(theme.font(size: 14, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                            Spacer()
                            Text("\(category.packedCount)/\(category.items.count)")
                                .font(theme.font(size: 11))
                                .foregroundStyle(theme.secondary)
                            SlopInteractiveOnly {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        data.categories.removeAll { $0.id == category.id }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(theme.secondary.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ForEach($category.items) { $item in
                            HStack(spacing: 8) {
                                SlopInteractiveOnly {
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            item.packed.toggle()
                                        }
                                    } label: {
                                        Image(systemName: item.packed ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(item.packed ? .green : theme.secondary.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                if renderTarget != .interactive {
                                    Image(systemName: item.packed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.packed ? .green : theme.secondary.opacity(0.5))
                                }

                                SlopTextField("Item", text: $item.name)
                                    .font(theme.font(size: 13))
                                    .foregroundStyle(item.packed ? theme.secondary : theme.foreground)
                                    .strikethrough(item.packed)

                                Spacer()

                                if item.quantity > 1 {
                                    Text("×\(Int(item.quantity))")
                                        .font(theme.font(size: 11))
                                        .foregroundStyle(theme.secondary)
                                }

                                SlopInteractiveOnly {
                                    RemoveButton {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            category.items.removeAll { $0.id == item.id }
                                        }
                                    }
                                }
                            }
                        }

                        SlopInteractiveOnly {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    category.items.append(PackingItem())
                                }
                            } label: {
                                Label("Add Item", systemImage: "plus")
                                    .font(.caption)
                                    .foregroundStyle(theme.accent.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(theme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Category") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.categories.append(PackingCategory())
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

