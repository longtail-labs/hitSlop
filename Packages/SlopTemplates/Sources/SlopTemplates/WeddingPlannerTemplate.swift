import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct WeddingVendor: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Category", options: ["Venue", "Catering", "Photography", "Florist", "Music/DJ", "Officiant", "Attire", "Cake", "Decor", "Other"]) var category: String = "Other"
    @Field("Cost") var cost: Double = 0
    @Field("Paid") var paid: Bool = false
    @Field("Contact") var contact: String = ""
    @Field("Status", options: ["Researching", "Contacted", "Booked", "Confirmed", "Cancelled"]) var status: String = "Researching"
    @Field("Notes") var notes: String = ""
}

@SlopData
public struct WeddingTask: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Task") var task: String = ""
    @Field("Due Date") var dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @Field("Done") var done: Bool = false
    @Field("Assignee") var assignee: String = ""
}

@SlopData
public struct WeddingGuest: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Email") var email: String = ""
    @Field("RSVP Status", options: ["Invited", "RSVP'd Yes", "RSVP'd No", "No Response"]) var rsvpStatus: String = "Invited"
    @Field("Meal Choice") var mealChoice: String = ""
    @Field("Plus One") var plusOne: Bool = false
    @Field("Dietary Notes") var dietaryNotes: String = ""
}

@SlopData
public struct WeddingPlannerData {
    @SlopKit.Section("Wedding")
    @Field("Title") var title: String = "Our Wedding"
    @Field("Wedding Date") var weddingDate: Date = Calendar.current.date(from: DateComponents(year: 2027, month: 6, day: 20)) ?? .now
    @Field("Venue") var venue: String = "Garden Estate"
    @Field("Venue Address") var venueAddress: String = "456 Garden Lane"
    @Field("Ceremony Time") var ceremonyTime: String = "4:00 PM"
    @Field("Partner 1") var partner1: String = "Alex"
    @Field("Partner 2") var partner2: String = "Jordan"

    @SlopKit.Section("Budget")
    @Field("Currency", options: ["USD", "EUR", "GBP"]) var currency: String = "USD"
    @Field("Total Budget") var totalBudget: Double = 30000

    @SlopKit.Section("Vendors")
    @Field("Vendors") var vendors: [WeddingVendor] = WeddingPlannerData.defaultVendors

    @SlopKit.Section("Tasks")
    @Field("Tasks") var tasks: [WeddingTask] = WeddingPlannerData.defaultTasks

    @SlopKit.Section("Guests")
    @Field("Guest List") var guestList: [WeddingGuest] = WeddingPlannerData.defaultGuests
    @Field("Meal A Label") var mealALabel: String = "Chicken"
    @Field("Meal B Label") var mealBLabel: String = "Fish"
    @Field("Meal C Label") var mealCLabel: String = "Vegetarian"

    var totalSpent: Double { vendors.reduce(0) { $0 + $1.cost } }
    var totalPaid: Double { vendors.filter(\.paid).reduce(0) { $0 + $1.cost } }
    var budgetRemaining: Double { totalBudget - totalSpent }
    var completedTasks: Int { tasks.filter(\.done).count }
    var taskProgress: Double { tasks.isEmpty ? 0 : Double(completedTasks) / Double(tasks.count) }

    var confirmedGuests: Int { guestList.filter { $0.rsvpStatus == "RSVP'd Yes" }.count }
    var declinedGuests: Int { guestList.filter { $0.rsvpStatus == "RSVP'd No" }.count }
    var pendingGuests: Int { guestList.filter { $0.rsvpStatus == "Invited" || $0.rsvpStatus == "No Response" }.count }

    var mealACounts: Int { guestList.filter { $0.mealChoice == "A" }.count }
    var mealBCounts: Int { guestList.filter { $0.mealChoice == "B" }.count }
    var mealCCounts: Int { guestList.filter { $0.mealChoice == "C" }.count }

    var daysUntilWedding: Int {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: weddingDate)).day ?? 0
        return max(days, 0)
    }
}

extension WeddingPlannerData {
    static var defaultVendors: [WeddingVendor] {
        func vendor(_ name: String, _ category: String, _ cost: Double, _ status: String) -> WeddingVendor {
            var v = WeddingVendor()
            v.name = name
            v.category = category
            v.cost = cost
            v.status = status
            return v
        }
        return [
            vendor("Garden Estate", "Venue", 8000, "Booked"),
            vendor("Delicious Bites Catering", "Catering", 6500, "Contacted"),
            vendor("Lens & Light Photography", "Photography", 3500, "Booked"),
            vendor("Petal & Bloom", "Florist", 2000, "Researching"),
            vendor("DJ Mike", "Music/DJ", 1500, "Contacted"),
        ]
    }

    static var defaultTasks: [WeddingTask] {
        func task(_ name: String, _ daysFromNow: Int, _ done: Bool, _ assignee: String) -> WeddingTask {
            var t = WeddingTask()
            t.task = name
            t.dueDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now) ?? .now
            t.done = done
            t.assignee = assignee
            return t
        }
        return [
            task("Book venue", -30, true, "Both"),
            task("Send save-the-dates", 14, false, "Alex"),
            task("Book photographer", 7, true, "Jordan"),
            task("Choose caterer", 30, false, "Both"),
            task("Order invitations", 45, false, "Alex"),
            task("First dress fitting", 60, false, "Alex"),
            task("Book honeymoon", 90, false, "Jordan"),
        ]
    }

    static var defaultGuests: [WeddingGuest] {
        func guest(_ name: String, _ email: String, _ rsvp: String, _ meal: String = "", _ plusOne: Bool = false, _ dietary: String = "") -> WeddingGuest {
            var g = WeddingGuest()
            g.name = name
            g.email = email
            g.rsvpStatus = rsvp
            g.mealChoice = meal
            g.plusOne = plusOne
            g.dietaryNotes = dietary
            return g
        }
        return [
            guest("Sarah Chen", "sarah@email.com", "RSVP'd Yes", "A", true),
            guest("Marcus Johnson", "marcus@email.com", "RSVP'd Yes", "C", false, "Vegan"),
            guest("Emily Rivera", "emily@email.com", "No Response"),
            guest("David Park", "david@email.com", "RSVP'd No"),
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.wedding-planner",
    name: "Wedding Planner",
    description: "Plan your wedding with budget tracking, vendor management, tasks, and guest list.",
    version: "1.0.0",
    width: 720, height: 660,
    minWidth: 600, minHeight: 500,
    shape: .roundedRect(radius: 20),
    theme: "rose-garden",
    alwaysOnTop: true,
    categories: ["events"]
)
struct WeddingPlannerView: View {
    @TemplateData var data: WeddingPlannerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                ThemeDivider()

                // Two-column layout
                HStack(alignment: .top, spacing: 20) {
                    // Left column: budget + vendors
                    VStack(alignment: .leading, spacing: 16) {
                        budgetSection
                        ThemeDivider()
                        vendorSection
                    }
                    .frame(maxWidth: .infinity)

                    // Right column: tasks + guests
                    VStack(alignment: .leading, spacing: 16) {
                        taskSection
                        ThemeDivider()
                        guestSection
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                SlopTextField("Title", text: $data.title)
                    .font(theme.title(size: 22))
                    .foregroundStyle(theme.foreground)

                HStack(spacing: 4) {
                    SlopTextField("Partner 1", text: $data.partner1)
                        .font(theme.font(size: 14, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .frame(maxWidth: 80)
                    Text("&")
                        .font(theme.font(size: 14))
                        .foregroundStyle(theme.secondary.opacity(0.6))
                    SlopTextField("Partner 2", text: $data.partner2)
                        .font(theme.font(size: 14, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .frame(maxWidth: 80)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundStyle(theme.secondary)
                        SlopEditable($data.weddingDate) { value in
                            Text(value, style: .date)
                                .foregroundStyle(theme.secondary)
                        } editor: { $value in
                            DatePicker("", selection: $value, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .font(theme.font(size: 12))

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Time", text: $data.ceremonyTime)
                            .foregroundStyle(theme.secondary)
                    }
                    .font(theme.font(size: 12))
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle")
                        .foregroundStyle(theme.secondary)
                    SlopTextField("Venue", text: $data.venue)
                        .font(theme.font(size: 12, weight: .medium))
                        .foregroundStyle(theme.foreground)
                    Text("·")
                        .foregroundStyle(theme.secondary)
                    SlopTextField("Address", text: $data.venueAddress)
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(data.daysUntilWedding)")
                    .font(theme.font(size: 28, weight: .bold))
                    .foregroundStyle(theme.accent)
                Text("days to go")
                    .font(theme.font(size: 11))
                    .foregroundStyle(theme.secondary)
            }
            .padding(10)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Budget

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Budget")

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("Budget")
                        .font(theme.font(size: 10))
                        .foregroundStyle(theme.secondary)
                    Text(formatCurrency(data.totalBudget, code: data.currency))
                        .font(theme.font(size: 13, weight: .bold))
                        .foregroundStyle(theme.foreground)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("Spent")
                        .font(theme.font(size: 10))
                        .foregroundStyle(theme.secondary)
                    Text(formatCurrency(data.totalSpent, code: data.currency))
                        .font(theme.font(size: 13, weight: .bold))
                        .foregroundStyle(data.totalSpent > data.totalBudget ? .red : theme.accent)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("Remaining")
                        .font(theme.font(size: 10))
                        .foregroundStyle(theme.secondary)
                    Text(formatCurrency(data.budgetRemaining, code: data.currency))
                        .font(theme.font(size: 13, weight: .bold))
                        .foregroundStyle(data.budgetRemaining < 0 ? .red : .green)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            ProgressBar(progress: data.totalBudget > 0 ? min(data.totalSpent / data.totalBudget, 1.0) : 0, fillColor: theme.accent, backgroundColor: theme.surface)

            if renderTarget == .interactive {
                HStack {
                    Text("Total budget:")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                    Text(currencySymbol(for: data.currency))
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                    SlopNumberField("0", value: $data.totalBudget, format: "%.0f")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.foreground)
                        .frame(width: 70)
                }
            }
        }
    }

    // MARK: - Vendors

    private var vendorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Vendors (\(data.vendors.count))")

            ForEach($data.vendors) { $vendor in
                vendorRow(vendor: $vendor)
            }

            SlopInteractiveOnly {
                AddItemButton("Add Vendor") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.vendors.append(WeddingVendor())
                    }
                }
            }

            SummaryRow(label: "Total Cost", value: formatCurrency(data.totalSpent, code: data.currency))
            SummaryRow(label: "Total Paid", value: formatCurrency(data.totalPaid, code: data.currency))
        }
    }

    // MARK: - Tasks

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Tasks (\(data.completedTasks)/\(data.tasks.count))")
            ProgressBar(progress: data.taskProgress, fillColor: theme.accent, backgroundColor: theme.surface)

            ForEach($data.tasks) { $task in
                taskRow(task: $task)
            }

            SlopInteractiveOnly {
                AddItemButton("Add Task") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.tasks.append(WeddingTask())
                    }
                }
            }
        }
    }

    // MARK: - Guests

    private var guestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Guest List (\(data.guestList.count))")

            // RSVP stats
            HStack(spacing: 6) {
                StatBadge(count: data.confirmedGuests, label: "Yes", tint: .green)
                StatBadge(count: data.declinedGuests, label: "No", tint: .red)
                StatBadge(count: data.pendingGuests, label: "Pending", tint: .orange)
            }

            // Meal summary
            HStack(spacing: 8) {
                mealSummaryPill(label: data.mealALabel, count: data.mealACounts)
                mealSummaryPill(label: data.mealBLabel, count: data.mealBCounts)
                mealSummaryPill(label: data.mealCLabel, count: data.mealCCounts)
            }

            // Meal option labels (editable)
            if renderTarget == .interactive {
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Text("A:")
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Meal A", text: $data.mealALabel)
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.secondary)
                    }
                    HStack(spacing: 2) {
                        Text("B:")
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Meal B", text: $data.mealBLabel)
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.secondary)
                    }
                    HStack(spacing: 2) {
                        Text("C:")
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Meal C", text: $data.mealCLabel)
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.secondary)
                    }
                }
            }

            // Guest rows
            ForEach($data.guestList) { $guest in
                guestRow(guest: $guest)
            }

            SlopInteractiveOnly {
                AddItemButton("Add Guest") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.guestList.append(WeddingGuest())
                    }
                }
            }
        }
    }

    // MARK: - Row Views

    private func vendorRow(vendor: Binding<WeddingVendor>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SlopTextField("Vendor name", text: vendor.name)
                    .font(theme.font(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Spacer()
                Text(formatCurrency(vendor.wrappedValue.cost, code: data.currency))
                    .font(theme.font(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                SlopInteractiveOnly {
                    RemoveButton {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.vendors.removeAll { $0.id == vendor.id }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if renderTarget == .interactive {
                    Picker("", selection: vendor.category) {
                        Text("Venue").tag("Venue")
                        Text("Catering").tag("Catering")
                        Text("Photography").tag("Photography")
                        Text("Florist").tag("Florist")
                        Text("Music/DJ").tag("Music/DJ")
                        Text("Officiant").tag("Officiant")
                        Text("Attire").tag("Attire")
                        Text("Cake").tag("Cake")
                        Text("Decor").tag("Decor")
                        Text("Other").tag("Other")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.mini)
                } else {
                    StatusBadge(vendor.wrappedValue.category)
                }

                SlopInteractiveOnly {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            let statuses = ["Researching", "Contacted", "Booked", "Confirmed", "Cancelled"]
                            guard let idx = statuses.firstIndex(of: vendor.wrappedValue.status) else { return }
                            vendor.wrappedValue.status = statuses[(idx + 1) % statuses.count]
                        }
                    } label: {
                        StatusBadge(vendor.wrappedValue.status)
                    }
                    .buttonStyle(.plain)
                }
                if renderTarget != .interactive {
                    StatusBadge(vendor.wrappedValue.status)
                }

                SlopInteractiveOnly {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            vendor.wrappedValue.paid.toggle()
                        }
                    } label: {
                        Text(vendor.wrappedValue.paid ? "Paid" : "Unpaid")
                            .font(theme.font(size: 10, weight: .medium))
                            .foregroundStyle(vendor.wrappedValue.paid ? .green : .orange)
                    }
                    .buttonStyle(.plain)
                }
                if renderTarget != .interactive {
                    Text(vendor.wrappedValue.paid ? "Paid" : "Unpaid")
                        .font(theme.font(size: 10, weight: .medium))
                        .foregroundStyle(vendor.wrappedValue.paid ? .green : .orange)
                }
            }

            if renderTarget == .interactive {
                HStack(spacing: 4) {
                    Text("Cost: \(currencySymbol(for: data.currency))")
                        .font(theme.font(size: 11))
                        .foregroundStyle(theme.secondary)
                    SlopNumberField("0", value: vendor.cost, format: "%.0f")
                        .font(theme.font(size: 11))
                        .foregroundStyle(theme.foreground)
                        .frame(width: 60)
                    Spacer()
                    if !vendor.wrappedValue.contact.isEmpty || renderTarget == .interactive {
                        SlopTextField("Contact", text: vendor.contact)
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                    }
                }
            }
        }
        .padding(10)
        .background(theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func taskRow(task: Binding<WeddingTask>) -> some View {
        HStack(spacing: 10) {
            CheckmarkIndicator(isChecked: task.done)

            VStack(alignment: .leading, spacing: 2) {
                SlopTextField("Task", text: task.task)
                    .font(theme.font(size: 12))
                    .foregroundStyle(task.wrappedValue.done ? theme.secondary : theme.foreground)
                    .strikethrough(task.wrappedValue.done)

                HStack(spacing: 8) {
                    SlopEditable(task.dueDate) { value in
                        Text(dateStringAbbreviated(value))
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.secondary)
                    } editor: { $value in
                        DatePicker("", selection: $value, displayedComponents: .date)
                            .labelsHidden()
                    }

                    if !task.wrappedValue.assignee.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 8))
                            SlopTextField("Assignee", text: task.assignee)
                        }
                        .font(theme.font(size: 10))
                        .foregroundStyle(theme.secondary)
                    }
                }
            }

            Spacer()

            SlopInteractiveOnly {
                RemoveButton {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.tasks.removeAll { $0.id == task.id }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func guestRow(guest: Binding<WeddingGuest>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SlopTextField("Guest name", text: guest.name)
                    .font(theme.font(size: 12, weight: .semibold))
                    .foregroundStyle(theme.foreground)

                Spacer()

                SlopInteractiveOnly {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            let statuses = ["Invited", "RSVP'd Yes", "RSVP'd No", "No Response"]
                            guard let idx = statuses.firstIndex(of: guest.wrappedValue.rsvpStatus) else { return }
                            guest.wrappedValue.rsvpStatus = statuses[(idx + 1) % statuses.count]
                        }
                    } label: {
                        StatusBadge(guest.wrappedValue.rsvpStatus)
                    }
                    .buttonStyle(.plain)
                }
                if renderTarget != .interactive {
                    StatusBadge(guest.wrappedValue.rsvpStatus)
                }

                SlopInteractiveOnly {
                    RemoveButton {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.guestList.removeAll { $0.id == guest.id }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if !guest.wrappedValue.email.isEmpty || renderTarget == .interactive {
                    SlopTextField("Email", text: guest.email)
                        .font(theme.font(size: 10))
                        .foregroundStyle(theme.secondary)
                }

                SlopInteractiveOnly {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            guest.wrappedValue.plusOne.toggle()
                        }
                    } label: {
                        Text(guest.wrappedValue.plusOne ? "+1" : "No +1")
                            .font(theme.font(size: 10, weight: .medium))
                            .foregroundStyle(guest.wrappedValue.plusOne ? theme.accent : theme.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                if renderTarget != .interactive && guest.wrappedValue.plusOne {
                    Text("+1")
                        .font(theme.font(size: 10, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
            }

            // Meal choice (only when RSVP'd Yes)
            if guest.wrappedValue.rsvpStatus == "RSVP'd Yes" {
                HStack(spacing: 6) {
                    Text("Meal:")
                        .font(theme.font(size: 10))
                        .foregroundStyle(theme.secondary)

                    if renderTarget == .interactive {
                        Picker("", selection: guest.mealChoice) {
                            Text("—").tag("")
                            Text("A: \(data.mealALabel)").tag("A")
                            Text("B: \(data.mealBLabel)").tag("B")
                            Text("C: \(data.mealCLabel)").tag("C")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.mini)
                    } else {
                        let label = guest.wrappedValue.mealChoice == "A" ? data.mealALabel :
                                    guest.wrappedValue.mealChoice == "B" ? data.mealBLabel :
                                    guest.wrappedValue.mealChoice == "C" ? data.mealCLabel : "—"
                        Text(label)
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.foreground)
                    }

                    if !guest.wrappedValue.dietaryNotes.isEmpty || renderTarget == .interactive {
                        SlopTextField("Dietary notes", text: guest.dietaryNotes)
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func mealSummaryPill(label: String, count: Int) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(theme.font(size: 10))
                .foregroundStyle(theme.secondary)
            Text("\(count)")
                .font(theme.font(size: 10, weight: .semibold))
                .foregroundStyle(theme.foreground)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(theme.surface)
        .clipShape(Capsule())
    }
}

