import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct SymptomEntry: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Date", editor: .date) var date: Date = .now
    @Field("Symptom") var symptom: String = ""
    @Field("Severity") var severity: Int = 5
    @Field("Triggers", editor: .stringList) var triggers: [String] = []
    @Field("Notes", editor: .multiLine) var notes: String = ""

    var severityColor: Color {
        switch severity {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default: return .red
        }
    }
}

@SlopData
public struct SymptomTrackerData {
    @SlopKit.Section("Overview")
    @Field("Tracker Name") var trackerName: String = "Health Journal"
    @Field("Patient") var patient: String = "John Doe"

    @SlopKit.Section("Entries")
    @Field("Entries") var entries: [SymptomEntry] = SymptomTrackerData.defaultEntries

    var totalEntries: Int { entries.count }

    var averageSeverity: Double {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + $1.severity }
        return Double(total) / Double(entries.count)
    }

    var commonTriggers: Set<String> {
        Set(entries.flatMap(\.triggers).filter { !$0.isEmpty })
    }

    var triggersByFrequency: [(trigger: String, count: Int)] {
        var counts: [String: Int] = [:]
        for trigger in entries.flatMap(\.triggers) where !trigger.isEmpty {
            counts[trigger, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map { (trigger: $0.key, count: $0.value) }
    }

    var recentEntries: [SymptomEntry] {
        Array(entries.prefix(10))
    }
}

extension SymptomTrackerData {
    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    static var defaultEntries: [SymptomEntry] {
        func entry(_ date: Date, _ symptom: String, _ severity: Int, _ triggers: [String], _ notes: String = "") -> SymptomEntry {
            var e = SymptomEntry()
            e.date = date
            e.symptom = symptom
            e.severity = severity
            e.triggers = triggers
            e.notes = notes
            return e
        }

        return [
            entry(makeDate(2026, 4, 3), "Headache", 7, ["Stress", "Lack of sleep"], "Intense pressure on left side"),
            entry(makeDate(2026, 4, 2), "Fatigue", 5, ["Poor diet"], "Low energy afternoon"),
            entry(makeDate(2026, 4, 1), "Nausea", 4, ["Skipped meal"], "Mild discomfort"),
            entry(makeDate(2026, 3, 31), "Headache", 8, ["Stress", "Screen time"], "Sharp pain"),
            entry(makeDate(2026, 3, 30), "Fatigue", 6, ["Lack of sleep"], "Needed afternoon nap"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.symptom-tracker",
    name: "Symptom Tracker",
    description: "Log symptoms with severity and triggers for health monitoring.",
    version: "1.0.0",
    width: 380, height: 640,
    minWidth: 340, minHeight: 520,
    shape: .roundedRect(radius: 16),
    theme: "forest-club",
    alwaysOnTop: false,
    categories: ["health"]
)
struct SymptomTrackerView: View {
    @TemplateData var data: SymptomTrackerData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(
                    titlePlaceholder: "Health tracker",
                    title: $data.trackerName,
                    subtitlePlaceholder: "Patient",
                    subtitle: $data.patient
                )

                // Metrics
                HStack(spacing: 10) {
                    MetricPill("\(data.totalEntries) entries", tint: theme.accent)
                    MetricPill(
                        String(format: "%.1f avg", data.averageSeverity),
                        tint: severityColorForAverage(data.averageSeverity)
                    )
                    Spacer()
                }

                Divider().background(theme.divider)

                SlopSurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Severity Scale")

                        HStack(spacing: 4) {
                            ForEach(1...10, id: \.self) { level in
                                Rectangle()
                                    .fill(severityColorForLevel(level))
                                    .frame(height: 20)
                                    .cornerRadius(2)
                            }
                        }

                        HStack {
                            Text("Mild (1-3)")
                                .font(.caption2)
                                .foregroundStyle(theme.secondary)
                            Spacer()
                            Text("Moderate (4-6)")
                                .font(.caption2)
                                .foregroundStyle(theme.secondary)
                            Spacer()
                            Text("Severe (7-10)")
                                .font(.caption2)
                                .foregroundStyle(theme.secondary)
                        }
                    }
                }

                // Common triggers
                if !data.triggersByFrequency.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Common Triggers")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(data.triggersByFrequency, id: \.trigger) { item in
                                    Text(item.trigger)
                                        .font(.caption2)
                                        .foregroundStyle(theme.foreground)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(theme.accent.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }

                Divider().background(theme.divider)

                SlopRecordListSection(
                    title: "Recent Entries",
                    isEmpty: data.entries.isEmpty,
                    addLabel: "Add Entry",
                    onAdd: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.entries.insert(SymptomEntry(), at: 0)
                        }
                    },
                    emptyState: {
                        EmptyState(
                            icon: "heart.text.square",
                            title: "No entries yet",
                            subtitle: "Log your first symptom to start tracking"
                        )
                    },
                    content: {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach($data.entries) { $entry in
                                    SlopSurfaceCard(padding: 12) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                SlopDateField($entry.date)

                                                Spacer()

                                                MetricPill(
                                                    "Severity \(entry.severity)/10",
                                                    tint: entry.severityColor
                                                )

                                                RemoveButton {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        data.entries.removeAll { $0.id == entry.id }
                                                    }
                                                }
                                            }

                                            SlopTextField("Symptom", text: $entry.symptom)
                                                .font(theme.font(size: 14, weight: .semibold))
                                                .foregroundStyle(theme.foreground)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Severity")
                                                    .font(.caption2)
                                                    .foregroundStyle(theme.secondary)

                                                SlopInteractiveOnly {
                                                    HStack(spacing: 8) {
                                                        Slider(
                                                            value: Binding(
                                                                get: { Double(entry.severity) },
                                                                set: { entry.severity = Int($0) }
                                                            ),
                                                            in: 1...10,
                                                            step: 1
                                                        )
                                                        .tint(entry.severityColor)

                                                        Text("\(entry.severity)")
                                                            .font(theme.font(size: 14, weight: .bold))
                                                            .foregroundStyle(entry.severityColor)
                                                            .frame(width: 30)
                                                    }
                                                }

                                            }

                                            SlopStringListEditor(
                                                title: "Triggers",
                                                items: $entry.triggers,
                                                addLabel: "Add Trigger",
                                                placeholder: "Trigger"
                                            )

                                            SlopTextArea("Notes", text: $entry.notes, minHeight: 50)
                                                .font(.caption)
                                                .foregroundStyle(theme.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                )

                Divider().background(theme.divider)

                // Summary
                SummaryRow(
                    label: "Total Entries",
                    value: "\(data.totalEntries)",
                    valueColor: theme.foreground
                )

                SummaryRow(
                    label: "Average Severity",
                    value: String(format: "%.1f / 10", data.averageSeverity),
                    valueColor: severityColorForAverage(data.averageSeverity),
                    isBold: true
                )
            }
            .padding(24)
        }
        .background(theme.background)
    }

    // MARK: - Helpers

    private func severityColorForLevel(_ level: Int) -> Color {
        switch level {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default: return .red
        }
    }

    private func severityColorForAverage(_ avg: Double) -> Color {
        severityColorForLevel(Int(avg.rounded()))
    }
}

