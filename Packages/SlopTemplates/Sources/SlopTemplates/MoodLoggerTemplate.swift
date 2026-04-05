import Foundation
import SwiftUI
import SlopKit

// MARK: - Data Model

@SlopData
public struct MoodEntry: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Date") var date: Date = .now
    @Field("Mood") var mood: Double = 3
    @Field("Energy") var energy: Double = 3
    @Field("Note") var note: String = ""
}

@SlopData
public struct MoodLoggerData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Mood Logger"

    @SlopKit.Section("Entries")
    @Field("Entries") var entries: [MoodEntry] = MoodLoggerData.defaultEntries

    var streak: Int {
        let sorted = entries.sorted { $0.date > $1.date }
        guard !sorted.isEmpty else { return 0 }
        var count = 1
        for i in 1..<sorted.count {
            let prev = sorted[i - 1].date
            let curr = sorted[i].date
            let diff = Calendar.current.dateComponents([.day], from: curr, to: prev).day ?? 0
            if diff == 1 {
                count += 1
            } else {
                break
            }
        }
        return count
    }
}

extension MoodLoggerData {
    static var defaultEntries: [MoodEntry] {
        func entry(_ daysAgo: Int, mood: Double, energy: Double, note: String) -> MoodEntry {
            var e = MoodEntry()
            e.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            e.mood = mood
            e.energy = energy
            e.note = note
            return e
        }

        return [
            entry(0, mood: 4, energy: 4, note: "Great morning workout"),
            entry(1, mood: 5, energy: 5, note: "Had a wonderful day off"),
            entry(2, mood: 3, energy: 2, note: "Tired after long meeting"),
            entry(3, mood: 4, energy: 3, note: "Productive coding session"),
            entry(4, mood: 2, energy: 2, note: "Didn't sleep well"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.mood-logger",
    name: "Mood Logger",
    description: "Capture daily mood check-ins and short reflections over time.",
    version: "1.0.0",
    width: 320, height: 420,
    shape: .roundedRect(radius: 20),
    alwaysOnTop: true,
    categories: ["health"]
)
struct MoodLoggerView: View {
    @TemplateData var data: MoodLoggerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    @State private var selectedMood: Double = 3
    @State private var selectedEnergy: Double = 3
    @State private var todayNote: String = ""

    private let moodFaces: [(Double, String, String)] = [
        (1, "\u{1F629}", "Terrible"),
        (2, "\u{1F61E}", "Bad"),
        (3, "\u{1F610}", "Okay"),
        (4, "\u{1F60A}", "Good"),
        (5, "\u{1F929}", "Great"),
    ]

    var body: some View {
        Group {
            if renderTarget == .interactive {
                ScrollView(showsIndicators: false) {
                    interactiveContent
                }
            } else {
                exportContent
            }
        }
        .background(theme.background)
    }

    // MARK: Interactive

    private var interactiveContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Title", text: $data.title)
                .font(theme.title(size: 22))
                .foregroundStyle(theme.foreground)
                .textFieldStyle(.plain)

            // Streak
            streakBadge

            Divider().background(theme.divider)

            // Today's log
            Text("How are you feeling?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.secondary)

            moodSelector

            VStack(alignment: .leading, spacing: 4) {
                Text("Energy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.secondary)
                HStack(spacing: 4) {
                    Slider(value: $selectedEnergy, in: 1...5, step: 1)
                        .tint(theme.accent)
                    Text(String(format: "%.0f", selectedEnergy))
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.secondary)
                        .frame(width: 16)
                }
            }

            TextField("Add a note...", text: $todayNote)
                .font(.caption)
                .foregroundStyle(theme.foreground.opacity(0.8))
                .textFieldStyle(.plain)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.surface)
                )

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    logToday()
                }
            } label: {
                Text("Log Mood")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.accent)
                    )
            }
            .buttonStyle(.plain)

            Divider().background(theme.divider)

            // Mini calendar
            Text("Last 14 Days")
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondary)

            miniCalendar

            Divider().background(theme.divider)

            // History
            Text("History")
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondary)

            ForEach(sortedEntries) { entry in
                historyRow(entry)
            }
        }
        .padding(20)
        .onAppear { loadTodayEntry() }
    }

    // MARK: Export

    private var exportContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(data.title)
                .font(theme.title(size: 22))
                .foregroundStyle(theme.foreground)

            streakBadge

            Divider().background(theme.divider)

            Text("Last 14 Days")
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondary)

            miniCalendar

            Divider().background(theme.divider)

            ForEach(sortedEntries) { entry in
                historyRow(entry)
            }
        }
        .padding(20)
    }

    // MARK: - Components

    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(data.streak) day streak")
                .font(theme.font(size: 14, weight: .semibold))
                .foregroundStyle(theme.foreground)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(theme.surface)
        )
    }

    private var moodSelector: some View {
        HStack(spacing: 0) {
            ForEach(moodFaces, id: \.0) { value, emoji, label in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedMood = value
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(emoji)
                            .font(theme.font(size: selectedMood == value ? 28 : 22))
                        Text(label)
                            .font(theme.font(size: 8, weight: .medium))
                            .foregroundStyle(selectedMood == value ? theme.foreground : theme.secondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedMood == value ? theme.surface : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var miniCalendar: some View {
        let days = last14Days()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { date in
                let entry = data.entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
                RoundedRectangle(cornerRadius: 4)
                    .fill(moodColor(entry?.mood))
                    .frame(height: 24)
                    .overlay {
                        Text(dayLabel(date))
                            .font(theme.mono(size: 8, weight: .medium))
                            .foregroundStyle(entry != nil ? Color.white : theme.secondary.opacity(0.5))
                    }
            }
        }
    }

    private func historyRow(_ entry: MoodEntry) -> some View {
        HStack(spacing: 10) {
            Text(moodEmoji(entry.mood))
                .font(theme.font(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.date, style: .date)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    Text("E: \(String(format: "%.0f", entry.energy))")
                        .font(theme.mono(size: 10))
                        .foregroundStyle(theme.secondary)
                }
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundStyle(theme.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.surface)
        )
    }

    // MARK: - Helpers

    private var sortedEntries: [MoodEntry] {
        data.entries.sorted { $0.date > $1.date }
    }

    private func logToday() {
        let today = Calendar.current.startOfDay(for: Date())

        if let index = data.entries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            data.entries[index].mood = selectedMood
            data.entries[index].energy = selectedEnergy
            data.entries[index].note = todayNote
        } else {
            var entry = MoodEntry()
            entry.date = today
            entry.mood = selectedMood
            entry.energy = selectedEnergy
            entry.note = todayNote
            data.entries.append(entry)
        }
    }

    private func loadTodayEntry() {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = data.entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            selectedMood = existing.mood
            selectedEnergy = existing.energy
            todayNote = existing.note
        }
    }

    private func last14Days() -> [Date] {
        return (0..<14).reversed().map { daysAgo in
            Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }

    private func moodColor(_ mood: Double?) -> Color {
        guard let mood else { return theme.surface }
        switch mood {
        case ..<1.5: return Color(red: 0.9, green: 0.2, blue: 0.2)
        case 1.5..<2.5: return Color(red: 0.9, green: 0.5, blue: 0.2)
        case 2.5..<3.5: return Color(red: 0.9, green: 0.85, blue: 0.2)
        case 3.5..<4.5: return Color(red: 0.5, green: 0.8, blue: 0.3)
        default: return Color(red: 0.2, green: 0.8, blue: 0.3)
        }
    }

    private func moodEmoji(_ mood: Double) -> String {
        switch mood {
        case ..<1.5: return "\u{1F629}"
        case 1.5..<2.5: return "\u{1F61E}"
        case 2.5..<3.5: return "\u{1F610}"
        case 3.5..<4.5: return "\u{1F60A}"
        default: return "\u{1F929}"
        }
    }
}

