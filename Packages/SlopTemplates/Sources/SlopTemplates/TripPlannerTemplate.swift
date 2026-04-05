import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct TripActivity: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Time") var time: String = "09:00"
    @Field("Activity") var activity: String = ""
    @Field("Notes", editor: .multiLine) var notes: String = ""
    @Field("Category", options: ["Transport", "Food", "Sightseeing", "Hotel", "Other"]) var category: String = "Sightseeing"
}

@SlopData
public struct TripDay: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Day Number") var dayNumber: Double = 1
    @Field("Title") var title: String = "Day 1"
    @Field("Activities") var activities: [TripActivity] = []
}

@SlopData
public struct TripPlannerData {
    @SlopKit.Section("Trip")
    @Field("Trip Name") var tripName: String = "Summer Vacation"
    @Field("Destination") var destination: String = "Barcelona"
    @Field("Start Date", editor: .date) var startDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 1)) ?? .now
    @Field("End Date", editor: .date) var endDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 7)) ?? .now

    @SlopKit.Section("Itinerary")
    @Field("Days") var days: [TripDay] = defaultDays

    var totalActivities: Int {
        days.reduce(0) { $0 + $1.activities.count }
    }
}

extension TripPlannerData {
    static var defaultDays: [TripDay] {
        func activity(_ time: String, _ activity: String, _ notes: String, _ category: String) -> TripActivity {
            var a = TripActivity()
            a.time = time
            a.activity = activity
            a.notes = notes
            a.category = category
            return a
        }

        func day(_ dayNumber: Double, _ title: String, _ activities: [TripActivity]) -> TripDay {
            var d = TripDay()
            d.dayNumber = dayNumber
            d.title = title
            d.activities = activities
            return d
        }

        return [
            day(1, "Day 1", [
                activity("10:00", "Flight to Barcelona", "Terminal 2", "Transport"),
                activity("14:00", "Hotel check-in", "Hotel Arts Barcelona", "Hotel"),
                activity("19:00", "Dinner at La Rambla", "Tapas restaurant", "Food")
            ]),
            day(2, "Day 2", [
                activity("09:00", "Visit Sagrada Familia", "Pre-booked tickets", "Sightseeing"),
                activity("13:00", "Lunch in Gothic Quarter", "", "Food"),
                activity("15:00", "Park Güell", "Guided tour", "Sightseeing")
            ])
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.trip-planner",
    name: "Trip Planner",
    description: "Plan your trip day by day with activities, times, and categories.",
    version: "1.0.0",
    width: 440, height: 620,
    shape: .roundedRect(radius: 16),
    theme: "ocean-glass",
    alwaysOnTop: true,
    categories: ["travel"]
)
struct TripPlannerView: View {
    @TemplateData var data: TripPlannerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    @State private var selectedDay: Int = 0

    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Transport": return "airplane"
        case "Food": return "fork.knife"
        case "Sightseeing": return "binoculars"
        case "Hotel": return "bed.double"
        case "Other": return "star"
        default: return "star"
        }
    }

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(
                    titlePlaceholder: "Trip name",
                    title: $data.tripName,
                    subtitlePlaceholder: "Destination",
                    subtitle: $data.destination
                )

                HStack {
                    SlopDateField($data.startDate)

                    Text("—")
                        .foregroundColor(theme.secondary)

                    SlopDateField($data.endDate)
                }

                Divider()
                    .background(theme.divider)

                if renderTarget == .interactive {
                    // Day selector (interactive only)
                    SlopInteractiveOnly {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(data.days.enumerated()), id: \.offset) { index, day in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedDay = index
                                        }
                                    }) {
                                        VStack(spacing: 4) {
                                            Text("Day \(Int(day.dayNumber))")
                                                .font(theme.font(size: 12, weight: selectedDay == index ? .semibold : .regular))

                                            Text("\(day.activities.count) items")
                                                .font(theme.font(size: 10))
                                                .foregroundColor(theme.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedDay == index ? theme.accent.opacity(0.2) : theme.surface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedDay == index ? theme.accent : Color.clear, lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Selected day activities
                    if selectedDay < data.days.count {
                        let day = data.days[selectedDay]

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SlopTextField("Day Title", text: Binding(
                                    get: { data.days[selectedDay].title },
                                    set: { data.days[selectedDay].title = $0 }
                                ))
                                .font(theme.font(size: 16, weight: .semibold))
                                .foregroundColor(theme.foreground)

                                Spacer()
                            }

                            ForEach(Array(day.activities.sorted(by: { $0.time < $1.time }).enumerated()), id: \.element.id) { _, activity in
                                let activityIndex = data.days[selectedDay].activities.firstIndex(where: { $0.id == activity.id }) ?? 0
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: categoryIcon(for: activity.category))
                                        .foregroundColor(theme.accent)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            SlopTextField("Time", text: Binding(
                                                get: { data.days[selectedDay].activities[activityIndex].time },
                                                set: { data.days[selectedDay].activities[activityIndex].time = $0 }
                                            ))
                                            .font(theme.font(size: 12, weight: .medium))
                                            .foregroundColor(theme.secondary)
                                            .frame(width: 50)

                                            SlopTextField("Activity", text: Binding(
                                                get: { data.days[selectedDay].activities[activityIndex].activity },
                                                set: { data.days[selectedDay].activities[activityIndex].activity = $0 }
                                            ))
                                            .font(theme.font(size: 14))
                                            .foregroundColor(theme.foreground)

                                            Spacer()

                                            SlopInteractiveOnly {
                                                Button(action: {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        data.days[selectedDay].activities.removeAll { $0.id == activity.id }
                                                    }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(theme.secondary.opacity(0.5))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }

                                        if !activity.notes.isEmpty || renderTarget == .interactive {
                                            SlopTextArea("Notes", text: Binding(
                                                get: { data.days[selectedDay].activities[activityIndex].notes },
                                                set: { data.days[selectedDay].activities[activityIndex].notes = $0 }
                                            ), minHeight: 52)
                                            .font(theme.font(size: 12))
                                            .foregroundColor(theme.secondary.opacity(0.8))
                                        }
                                    }
                                }
                                .padding(12)
                                .background(theme.surface)
                                .cornerRadius(8)
                            }

                            SlopInteractiveOnly {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        var newActivity = TripActivity()
                                        newActivity.time = "12:00"
                                        newActivity.activity = "New Activity"
                                        newActivity.notes = ""
                                        newActivity.category = "Sightseeing"
                                        data.days[selectedDay].activities.append(newActivity)
                                        data.days[selectedDay].activities.sort { $0.time < $1.time }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Activity")
                                    }
                                    .font(theme.font(size: 13))
                                    .foregroundColor(theme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()

                    SlopInteractiveOnly {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                let newDayNumber = (data.days.map { $0.dayNumber }.max() ?? 0) + 1
                                var newDay = TripDay()
                                newDay.dayNumber = newDayNumber
                                newDay.title = "Day \(Int(newDayNumber))"
                                newDay.activities = []
                                data.days.append(newDay)
                                selectedDay = data.days.count - 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Day")
                            }
                            .font(theme.font(size: 14, weight: .medium))
                            .foregroundColor(theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(theme.surface)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Export view: show all days
                    ForEach(Array(data.days.enumerated()), id: \.element.id) { _, day in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(day.title)
                                .font(theme.font(size: 16, weight: .semibold))
                                .foregroundColor(theme.foreground)

                            ForEach(day.activities.sorted(by: { $0.time < $1.time })) { activity in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: categoryIcon(for: activity.category))
                                        .foregroundColor(theme.accent)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(activity.time)
                                                .font(theme.font(size: 12, weight: .medium))
                                                .foregroundColor(theme.secondary)

                                            Text(activity.activity)
                                                .font(theme.font(size: 14))
                                                .foregroundColor(theme.foreground)
                                        }

                                        if !activity.notes.isEmpty {
                                            Text(activity.notes)
                                                .font(theme.font(size: 12))
                                                .foregroundColor(theme.secondary.opacity(0.8))
                                        }
                                    }
                                }
                                .padding(12)
                                .background(theme.surface)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}
