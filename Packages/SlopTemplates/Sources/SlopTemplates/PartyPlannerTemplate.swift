import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct PartyGuest: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("RSVP", options: ["Yes", "No", "Maybe"]) var rsvp: String = "Maybe"
    @Field("Plus Ones") var plusOnes: Double = 0
    @Field("Dietary Notes") var dietaryNotes: String = ""
}

@SlopData
public struct PartyTodo: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Task") var task: String = ""
    @Field("Done") var done: Bool = false
    @Field("Assignee") var assignee: String = ""
}

@SlopData
public struct PartyPlannerData {
    @SlopKit.Section("Event")
    @Field("Event Name") var eventName: String = "Birthday Party"
    @Field("Date") var date: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15)) ?? .now
    @Field("Location") var location: String = "Central Park"
    @Field("Budget") var budget: Double = 500

    @SlopKit.Section("Guests")
    @Field("Guests") var guests: [PartyGuest] = PartyPlannerData.defaultGuests

    @SlopKit.Section("Tasks")
    @Field("To-Do Items") var todoItems: [PartyTodo] = PartyPlannerData.defaultTodoItems

    var confirmedCount: Int {
        guests.filter { $0.rsvp == "Yes" }.count
    }

    var pendingCount: Int {
        guests.filter { $0.rsvp == "Maybe" }.count
    }

    var declinedCount: Int {
        guests.filter { $0.rsvp == "No" }.count
    }

    var totalGuests: Double {
        let confirmed = guests.filter { $0.rsvp == "Yes" }
        let baseCount = Double(confirmed.count)
        let plusOnesSum = confirmed.reduce(0.0) { $0 + $1.plusOnes }
        return baseCount + plusOnesSum
    }
}

extension PartyPlannerData {
    static var defaultGuests: [PartyGuest] {
        func guest(_ name: String, _ rsvp: String, _ plusOnes: Double, _ dietaryNotes: String) -> PartyGuest {
            var g = PartyGuest()
            g.name = name
            g.rsvp = rsvp
            g.plusOnes = plusOnes
            g.dietaryNotes = dietaryNotes
            return g
        }
        return [
            guest("Alice Johnson", "Yes", 1, "Vegetarian"),
            guest("Bob Smith", "Yes", 0, ""),
            guest("Charlie Davis", "Maybe", 1, ""),
            guest("Diana Martinez", "No", 0, ""),
            guest("Ethan Wilson", "Maybe", 2, "Gluten-free")
        ]
    }

    static var defaultTodoItems: [PartyTodo] {
        func todo(_ task: String, _ done: Bool, _ assignee: String) -> PartyTodo {
            var t = PartyTodo()
            t.task = task
            t.done = done
            t.assignee = assignee
            return t
        }
        return [
            todo("Book venue", true, "Sarah"),
            todo("Order cake", false, "Mike"),
            todo("Send invitations", true, "Sarah"),
            todo("Buy decorations", false, "Lisa")
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.party-planner",
    name: "Party Planner",
    description: "Manage guest RSVPs, to-dos, and budget for your next event.",
    version: "1.0.0",
    width: 420, height: 600,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["events"]
)
struct PartyPlannerView: View {
    @TemplateData var data: PartyPlannerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }

    private var daysUntilEvent: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: data.date)).day ?? 0
    }

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header Section
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        SlopTextField("Event Name", text: $data.eventName)
                            .font(theme.titleFont)
                            .foregroundStyle(theme.foreground)

                        HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .foregroundStyle(theme.secondary)
                            SlopEditable($data.date) { value in
                                Text(value, style: .date)
                                    .font(theme.bodyFont)
                                    .foregroundStyle(theme.secondary)
                            } editor: { $value in
                                DatePicker("", selection: $value, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle")
                                .foregroundStyle(theme.secondary)
                            SlopTextField("Location", text: $data.location)
                                .font(theme.bodyFont)
                                .foregroundStyle(theme.secondary)
                        }
                    }
                    }

                    Spacer()

                    // Countdown badge
                    VStack(spacing: 2) {
                        Text("\(daysUntilEvent)")
                            .font(theme.title(size: 28))
                            .foregroundStyle(theme.accent)
                        Text("days to go")
                            .font(.caption2)
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.surface)
                    .cornerRadius(10)
                }

                // Stats Row
                HStack(spacing: 12) {
                    StatBadge(count: data.confirmedCount, label: "Confirmed", tint: .green)
                    StatBadge(count: data.pendingCount, label: "Pending", tint: .orange)
                    StatBadge(count: data.declinedCount, label: "Declined", tint: .red)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Expected")
                            .font(.caption2)
                            .foregroundStyle(theme.secondary)
                        Text("\(Int(data.totalGuests))")
                            .font(.headline)
                            .foregroundStyle(theme.foreground)
                    }
                }

                // Budget
                HStack {
                    Text("Budget:")
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.secondary)
                    Text("$")
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground)
                    SlopNumberField("0", value: $data.budget)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground)
                    Spacer()
                }

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: 1)

                // Guest List Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Guest List")
                        .font(.headline)
                        .foregroundStyle(theme.foreground)

                    ForEach($data.guests) { $guest in
                        GuestRow(guest: $guest, theme: theme, renderTarget: renderTarget, onRemove: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.guests.removeAll { $0.id == guest.id }
                            }
                        })
                    }

                    SlopInteractiveOnly {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.guests.append(PartyGuest())
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Guest")
                            }
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: 1)

                // To-Do Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("To Do")
                        .font(.headline)
                        .foregroundStyle(theme.foreground)

                    ForEach($data.todoItems) { $item in
                        TodoRow(item: $item, theme: theme, renderTarget: renderTarget, onRemove: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.todoItems.removeAll { $0.id == item.id }
                            }
                        })
                    }

                    SlopInteractiveOnly {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.todoItems.append(PartyTodo())
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Task")
                            }
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

struct GuestRow: View {
    @Binding var guest: PartyGuest
    let theme: SlopTheme
    let renderTarget: SlopRenderTarget
    let onRemove: () -> Void

    var rsvpColor: Color {
        switch guest.rsvp {
        case "Yes": return .green
        case "No": return .red
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SlopTextField("Guest name", text: $guest.name)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.foreground)

                Spacer()

                SlopInteractiveOnly {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            guest.rsvp = guest.rsvp == "Yes" ? "Maybe" : (guest.rsvp == "Maybe" ? "No" : "Yes")
                        }
                    }) {
                        Text(guest.rsvp)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(rsvpColor.opacity(0.8))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if renderTarget != .interactive {
                    Text(guest.rsvp)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(rsvpColor.opacity(0.8))
                        .clipShape(Capsule())
                }

                if guest.rsvp == "Yes" {
                    HStack(spacing: 4) {
                        Text("+")
                            .font(.caption)
                            .foregroundStyle(theme.secondary)
                        SlopNumberField("0", value: $guest.plusOnes)
                            .font(.caption)
                            .foregroundStyle(theme.secondary)
                            .frame(width: 30)
                    }
                }

                SlopInteractiveOnly {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !guest.dietaryNotes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.secondary)
                    SlopTextField("Dietary notes", text: $guest.dietaryNotes)
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                }
            }
        }
        .padding(10)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TodoRow: View {
    @Binding var item: PartyTodo
    let theme: SlopTheme
    let renderTarget: SlopRenderTarget
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CheckmarkIndicator(isChecked: $item.done)

            VStack(alignment: .leading, spacing: 4) {
                SlopTextField("Task", text: $item.task)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.foreground)
                    .strikethrough(item.done)

                if !item.assignee.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Assignee", text: $item.assignee)
                            .font(.caption)
                            .foregroundStyle(theme.secondary)
                    }
                }
            }

            Spacer()

            SlopInteractiveOnly {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
