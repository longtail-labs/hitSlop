import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct InventoryItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Value") var value: Double = 0
    @Field("Category", options: ["Furniture", "Electronics", "Appliance", "Other"]) var category: String = "Other"
    @Field("Purchase Date", editor: .date) var purchaseDate: Date = .now
    @Field("Notes", editor: .multiLine) var notes: String = ""
}

@SlopData
public struct InventoryRoom: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Icon") var icon: String = "📦"
    @Field("Items") var items: [InventoryItem] = []

    var totalValue: Double {
        items.reduce(0) { $0 + $1.value }
    }
}

@SlopData
public struct HomeInventoryData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Home Inventory"
    @Field("Currency", options: ["USD", "EUR", "GBP"]) var currency: String = "USD"

    @SlopKit.Section("Rooms")
    @Field("Rooms") var rooms: [InventoryRoom] = HomeInventoryData.defaultRooms

    var grandTotal: Double {
        rooms.reduce(0) { $0 + $1.totalValue }
    }

    var totalItems: Int {
        rooms.reduce(0) { $0 + $1.items.count }
    }
}

extension HomeInventoryData {
    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }

    static var defaultRooms: [InventoryRoom] {
        func item(_ name: String, _ value: Double, _ category: String, _ purchaseDate: Date, _ notes: String) -> InventoryItem {
            var i = InventoryItem()
            i.name = name
            i.value = value
            i.category = category
            i.purchaseDate = purchaseDate
            i.notes = notes
            return i
        }

        func room(_ name: String, _ items: [InventoryItem]) -> InventoryRoom {
            var r = InventoryRoom()
            r.name = name
            r.items = items
            return r
        }

        return [
            room("Living Room", [
                item("TV", 800, "Electronics", makeDate(2023, 1, 15), "65 inch 4K"),
                item("Sofa", 1200, "Furniture", makeDate(2022, 6, 20), "Leather sectional"),
                item("Bookshelf", 300, "Furniture", makeDate(2021, 9, 10), "Oak wood")
            ]),
            room("Kitchen", [
                item("Refrigerator", 1500, "Appliance", makeDate(2022, 3, 12), "French door style"),
                item("Dishwasher", 600, "Appliance", makeDate(2022, 3, 12), "Stainless steel")
            ]),
            room("Bedroom", [
                item("Bed Frame", 500, "Furniture", makeDate(2021, 11, 5), "Queen size"),
                item("Laptop", 1400, "Electronics", makeDate(2024, 1, 20), "MacBook Pro")
            ])
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.home-inventory",
    name: "Home Inventory",
    description: "Catalog belongings by room with values for insurance purposes.",
    version: "1.0.0",
    width: 440, height: 600,
    shape: .roundedRect(radius: 16),
    theme: "paper-ledger",
    alwaysOnTop: true,
    categories: ["personal"]
)
struct HomeInventoryView: View {
    @TemplateData var data: HomeInventoryData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(
                    titlePlaceholder: "Home inventory",
                    title: $data.title
                ) {
                    SlopSurfaceCard(padding: 10) {
                        SlopEnumField(selection: $data.currency, options: ["USD", "EUR", "GBP"])
                    }
                }

                // Grand total hero
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Value")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(currencySymbol(for: data.currency))
                            .font(theme.title(size: 32))
                            .foregroundColor(theme.accent)

                        Text(String(format: "%.2f", data.grandTotal))
                            .font(theme.title(size: 48))
                            .foregroundColor(theme.accent)
                    }

                    Text("\(data.totalItems) items across \(data.rooms.count) rooms")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: 1)

                // Rooms and items
                ForEach($data.rooms) { $room in
                    roomSection(room: $room)
                }

                // Add room button
                SlopInteractiveOnly {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            var newRoom = InventoryRoom()
                            newRoom.name = "New Room"
                            data.rooms.append(newRoom)
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Room")
                        }
                        .font(theme.bodyFont)
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func roomSection(room: Binding<InventoryRoom>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Room header
            HStack {
                SlopEmojiPicker(room.icon)
                    .objectEmojis()
                    .font(.system(size: 20))

                SlopTextField("Room name", text: room.name)
                    .font(theme.bodyFont.weight(.bold))
                    .foregroundColor(theme.foreground)

                Spacer()

                Text(currencySymbol(for: data.currency) + String(format: "%.2f", room.wrappedValue.totalValue))
                    .font(theme.bodyFont.weight(.semibold))
                    .foregroundColor(theme.accent)

                SlopInteractiveOnly {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.rooms.removeAll { $0.id == room.wrappedValue.id }
                        }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(theme.font(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Items in room
            ForEach(room.items) { item in
                if let index = room.wrappedValue.items.firstIndex(where: { $0.id == item.id }) {
                    itemRow(item: room.items[index], roomBinding: room)
                }
            }

            // Add item button
            SlopInteractiveOnly {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        var newItem = InventoryItem()
                        newItem.name = "New Item"
                        newItem.value = 0
                        newItem.category = "Other"
                        room.wrappedValue.items.append(newItem)
                    }
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Item")
                    }
                    .font(theme.bodyFont)
                    .foregroundColor(theme.accent.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.leading, 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func itemRow(item: Binding<InventoryItem>, roomBinding: Binding<InventoryRoom>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Category icon
            Image(systemName: categoryIcon(for: item.wrappedValue.category))
                .foregroundColor(theme.accent)
                .font(theme.font(size: 20))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SlopTextField("Item name", text: item.name)
                        .font(theme.bodyFont.weight(.medium))
                        .foregroundColor(theme.foreground)

                    Spacer()

                    SlopCurrencyField(currency: data.currency, value: item.value)
                }

                HStack(spacing: 8) {
                    SlopEnumField(
                        selection: item.category,
                        options: ["Furniture", "Electronics", "Appliance", "Other"]
                    )
                    .font(.caption)

                    Text("•")
                        .foregroundColor(theme.divider)

                    SlopDateField(item.purchaseDate)
                }

                SlopTextArea("Notes", text: item.notes, minHeight: 68)
                    .font(theme.bodyFont.italic())
                    .foregroundColor(theme.secondary.opacity(0.8))
            }

            // Remove item button
            SlopInteractiveOnly {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        roomBinding.wrappedValue.items.removeAll { $0.id == item.wrappedValue.id }
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondary.opacity(0.6))
                        .font(theme.font(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(theme.surface)
        .cornerRadius(8)
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Furniture":
            return "bed.double.fill"
        case "Electronics":
            return "tv.fill"
        case "Appliance":
            return "refrigerator.fill"
        default:
            return "archivebox.fill"
        }
    }
}
