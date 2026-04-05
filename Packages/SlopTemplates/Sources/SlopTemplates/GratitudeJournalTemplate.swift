import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct GratitudeEntry: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Date", editor: .date) var date: Date = .now
    @Field("First Thing", editor: .multiLine) var gratitude1: String = ""
    @Field("Second Thing", editor: .multiLine) var gratitude2: String = ""
    @Field("Third Thing", editor: .multiLine) var gratitude3: String = ""
    @Field("Mood", options: ["great", "good", "okay", "bad"]) var mood: String = "good"
}

@SlopData
public struct GratitudeJournalData {
    @SlopKit.Section("Journal")
    @Field("Title") var title: String = "Gratitude Journal"
    @Field("Entries") var entries: [GratitudeEntry] = GratitudeJournalData.defaultEntries

    var totalEntries: Int { entries.count }

    var currentStreak: Int {
        // Count consecutive entries from most recent
        guard !entries.isEmpty else { return 0 }
        var streak = 0
        for _ in entries {
            streak += 1
        }
        return streak
    }

    var moodDistribution: [String: Int] {
        var dist: [String: Int] = ["great": 0, "good": 0, "okay": 0, "bad": 0]
        for entry in entries {
            dist[entry.mood, default: 0] += 1
        }
        return dist
    }

    var greatCount: Int { moodDistribution["great"] ?? 0 }
    var goodCount: Int { moodDistribution["good"] ?? 0 }
    var okayCount: Int { moodDistribution["okay"] ?? 0 }
    var badCount: Int { moodDistribution["bad"] ?? 0 }
}

extension GratitudeJournalData {
    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    static var defaultEntries: [GratitudeEntry] {
        var e1 = GratitudeEntry()
        e1.date = makeDate(2026, 4, 3)
        e1.gratitude1 = "Great progress on my project today"
        e1.gratitude2 = "Coffee with a good friend"
        e1.gratitude3 = "Beautiful weather this morning"
        e1.mood = "great"

        var e2 = GratitudeEntry()
        e2.date = makeDate(2026, 4, 2)
        e2.gratitude1 = "Finished reading a great book"
        e2.gratitude2 = "Family dinner"
        e2.gratitude3 = "Good night's sleep"
        e2.mood = "good"

        return [e1, e2]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.gratitude-journal",
    name: "Gratitude Journal",
    description: "Daily gratitude entries with mood tracking for mindfulness practice.",
    version: "1.0.0",
    width: 360, height: 640,
    minWidth: 320, minHeight: 500,
    shape: .roundedRect(radius: 16),
    theme: "playroom",
    alwaysOnTop: false,
    categories: ["personal"]
)
struct GratitudeJournalView: View {
    @TemplateData var data: GratitudeJournalData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(titlePlaceholder: "Gratitude Journal", title: $data.title)

                HStack(spacing: 10) {
                    MetricPill("\(data.currentStreak) day streak", tint: theme.accent)
                    MetricPill("\(data.totalEntries) entries", tint: theme.secondary)
                    Spacer()
                }

                // Mood distribution
                if data.totalEntries > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Mood Overview")

                        HStack(spacing: 8) {
                            moodPill("😄", count: data.greatCount, mood: "great")
                            moodPill("🙂", count: data.goodCount, mood: "good")
                            moodPill("😐", count: data.okayCount, mood: "okay")
                            moodPill("😔", count: data.badCount, mood: "bad")
                        }
                    }
                }

                Divider().background(theme.divider)

                SlopRecordListSection(
                    title: "Entries",
                    isEmpty: data.entries.isEmpty,
                    addLabel: "Add Entry",
                    onAdd: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.entries.insert(GratitudeEntry(), at: 0)
                        }
                    },
                    emptyState: {
                        EmptyState(
                            icon: "heart.text.square",
                            title: "No entries yet",
                            subtitle: "Start your gratitude practice today"
                        )
                    },
                    content: {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach($data.entries) { $entry in
                                    entryCard(entry: $entry)
                                }
                            }
                        }
                    }
                )
            }
            .padding(24)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func moodPill(_ emoji: String, count: Int, mood: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(theme.font(size: 16))
            Text("\(count)")
                .font(theme.mono(size: 11, weight: .bold))
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.surface)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func entryCard(entry: Binding<GratitudeEntry>) -> some View {
        SlopSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SlopDateField(entry.date)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(moodEmoji(for: entry.wrappedValue.mood))
                            .font(theme.font(size: 18))
                        SlopEnumField(selection: entry.mood, options: ["great", "good", "okay", "bad"])
                            .font(.caption)
                    }

                    RemoveButton {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.entries.removeAll { $0.id == entry.wrappedValue.id }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    gratitudeField(number: 1, text: entry.gratitude1)
                    gratitudeField(number: 2, text: entry.gratitude2)
                    gratitudeField(number: 3, text: entry.gratitude3)
                }
            }
        }
    }

    @ViewBuilder
    private func gratitudeField(number: Int, text: Binding<String>) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(theme.mono(size: 12, weight: .bold))
                .foregroundStyle(theme.accent)
                .frame(width: 20, alignment: .leading)

            SlopTextArea("Grateful for", text: text, minHeight: 54)
                .font(theme.font(size: 13))
        }
    }

    private func moodEmoji(for mood: String) -> String {
        switch mood {
        case "great": return "😄"
        case "good": return "🙂"
        case "okay": return "😐"
        case "bad": return "😔"
        default: return "🙂"
        }
    }

}

