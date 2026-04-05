import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct SleepEntry: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Date", editor: .date) var date: Date = .now
    @Field("Hours Slept") var hours: Double = 0
    @Field("Quality", options: ["great", "solid", "rough"]) var quality: String = "solid"
    @Field("Notes", editor: .multiLine) var notes: String = ""
}

@SlopData
public struct SleepTrackerData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Sleep Tracker"
    @Field("Target Hours") var targetHours: Double = 8

    @SlopKit.Section("Entries")
    @Field("Entries") var entries: [SleepEntry] = [
        Self.makeEntry(0, 7.8, "solid", "Fell asleep quickly."),
        Self.makeEntry(1, 8.4, "great", "Deep sleep and steady wake-up."),
        Self.makeEntry(2, 6.7, "rough", "Late caffeine."),
    ]

    var averageHours: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0) { $0 + $1.hours } / Double(entries.count)
    }

    var hitRate: Double {
        guard !entries.isEmpty else { return 0 }
        let metTarget = entries.filter { $0.hours >= targetHours }.count
        return Double(metTarget) / Double(entries.count)
    }

    private static func makeEntry(_ daysAgo: Int, _ hours: Double, _ quality: String, _ notes: String) -> SleepEntry {
        var entry = SleepEntry()
        entry.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        entry.hours = hours
        entry.quality = quality
        entry.notes = notes
        return entry
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.sleep-tracker",
    name: "Sleep Tracker",
    description: "Track nightly sleep duration, quality, and recovery notes from one surface.",
    version: "1.0.0",
    width: 400, height: 620,
    minWidth: 340, minHeight: 520,
    shape: .roundedRect(radius: 18),
    theme: "forest-club",
    alwaysOnTop: false,
    categories: ["health"]
)
struct SleepTrackerView: View {
    @TemplateData var data: SleepTrackerData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(titlePlaceholder: "Sleep tracker", title: $data.title) {
                    SlopSurfaceCard(padding: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(theme.secondary)
                            SlopNumberField("0", value: $data.targetHours, format: "%.1f")
                                .font(theme.font(size: 18, weight: .bold))
                                .foregroundStyle(theme.accent)
                        }
                    }
                }

                HStack(spacing: 10) {
                    MetricPill(String(format: "%.1f avg hrs", data.averageHours), tint: theme.accent)
                    MetricPill("\(Int(data.hitRate * 100))% target hit", tint: theme.secondary)
                    Spacer()
                }

                ProgressBar(
                    progress: min(max(data.averageHours / max(data.targetHours, 1), 0), 1),
                    fillColor: data.averageHours >= data.targetHours ? .green : theme.accent,
                    backgroundColor: theme.surface,
                    height: 10
                )

                SlopRecordListSection(
                    title: "Sleep Log",
                    isEmpty: data.entries.isEmpty,
                    addLabel: "Add Night",
                    onAdd: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.entries.insert(SleepEntry(), at: 0)
                        }
                    },
                    emptyState: {
                        EmptyState(icon: "bed.double", title: "No sleep entries yet", subtitle: "Log a night to start tracking recovery.")
                    },
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach($data.entries) { $entry in
                                SlopSurfaceCard(padding: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            SlopDateField($entry.date)
                                            Spacer()
                                            SlopEnumField(selection: $entry.quality, options: ["great", "solid", "rough"])
                                                .font(.caption)
                                            RemoveButton {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    data.entries.removeAll { $0.id == entry.id }
                                                }
                                            }
                                        }

                                        HStack(spacing: 6) {
                                            Text("Hours")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondary)
                                            SlopNumberField("0", value: $entry.hours, format: "%.1f")
                                                .font(theme.font(size: 18, weight: .bold))
                                                .foregroundStyle(entry.hours >= data.targetHours ? .green : theme.foreground)
                                        }

                                        SlopTextArea("Notes", text: $entry.notes, minHeight: 70)
                                    }
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
}

