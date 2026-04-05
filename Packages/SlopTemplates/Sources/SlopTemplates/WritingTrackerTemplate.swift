import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct WritingSession: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Date", editor: .date) var date: Date = .now
    @Field("Word Count") var wordCount: Int = 0
    @Field("Duration (minutes)") var duration: Int = 0
    @Field("Project") var project: String = ""
}

@SlopData
public struct WritingTrackerData {
    @SlopKit.Section("Goal")
    @Field("Daily Word Goal") var dailyWordCount: Int = 1000
    @Field("Current Project") var currentProject: String = "Novel Draft"

    @SlopKit.Section("Sessions")
    @Field("Sessions") var sessions: [WritingSession] = WritingTrackerData.defaultSessions

    var totalWords: Int {
        sessions.reduce(0) { $0 + $1.wordCount }
    }

    var todaySessions: [WritingSession] {
        sessions.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todayWords: Int {
        todaySessions.reduce(0) { $0 + $1.wordCount }
    }

    var progressToGoal: Double {
        guard dailyWordCount > 0 else { return 0 }
        return min(1.0, Double(todayWords) / Double(dailyWordCount))
    }

    var currentStreak: Int {
        var streak = 0
        var foundGap = false

        for session in sessions.reversed() {
            if session.wordCount > 0 && !foundGap {
                streak += 1
            } else if session.wordCount == 0 {
                foundGap = true
            }
        }

        return streak
    }

    var averagePerDay: Int {
        guard !sessions.isEmpty else { return 0 }
        return totalWords / sessions.count
    }

    var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.duration }
    }
}

extension WritingTrackerData {
    private static func daysAgo(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -offset, to: .now) ?? .now
    }

    static var defaultSessions: [WritingSession] {
        func session(_ date: Date, _ wordCount: Int, _ duration: Int, _ project: String) -> WritingSession {
            var s = WritingSession()
            s.date = date
            s.wordCount = wordCount
            s.duration = duration
            s.project = project
            return s
        }

        return [
            session(daysAgo(0), 650, 45, "Novel Draft"),
            session(daysAgo(0), 320, 25, "Essay Draft"),
            session(daysAgo(1), 1150, 90, "Novel Draft"),
            session(daysAgo(2), 890, 60, "Novel Draft"),
            session(daysAgo(3), 1020, 75, "Novel Draft"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.writing-tracker",
    name: "Writing Tracker",
    description: "Track writing sessions and word count goals with streak monitoring.",
    version: "1.0.0",
    width: 380, height: 620,
    minWidth: 340, minHeight: 500,
    shape: .roundedRect(radius: 16),
    theme: "sunset-poster",
    alwaysOnTop: false,
    categories: ["creative"]
)
struct WritingTrackerView: View {
    @TemplateData var data: WritingTrackerData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(
                    titlePlaceholder: "Current project",
                    title: $data.currentProject
                ) {
                    SlopSurfaceCard(padding: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Goal")
                                .font(.caption2)
                                .foregroundStyle(theme.secondary)

                            HStack(spacing: 4) {
                                SlopNumberField("0", value: Binding(
                                    get: { Double(data.dailyWordCount) },
                                    set: { data.dailyWordCount = Int($0) }
                                ), format: "%.0f")
                                .font(theme.font(size: 16, weight: .bold))
                                .foregroundStyle(theme.accent)

                                Text("words")
                                    .font(theme.font(size: 12, weight: .medium))
                                    .foregroundStyle(theme.secondary)
                            }
                        }
                    }
                }

                SlopSurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SectionHeader("Today's Progress")
                            Spacer()
                            Text("\(data.todayWords) / \(data.dailyWordCount)")
                                .font(theme.font(size: 12, weight: .bold))
                                .foregroundStyle(theme.accent)
                                .contentTransition(.numericText())
                        }

                        ProgressBar(
                            progress: data.progressToGoal,
                            fillColor: data.progressToGoal >= 1.0 ? .green : theme.accent,
                            backgroundColor: theme.surface,
                            height: 12
                        )

                        if data.progressToGoal >= 1.0 {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Goal achieved!")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                // Stats cards
                HStack(spacing: 10) {
                    MetricPill("\(data.currentStreak) day streak", tint: theme.accent)
                    MetricPill("\(formatNumber(data.totalWords)) total", tint: theme.secondary)
                    Spacer()
                }

                Divider().background(theme.divider)

                // Quick stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avg/Day")
                            .font(.caption2)
                            .foregroundStyle(theme.secondary)
                        Text("\(formatNumber(data.averagePerDay))")
                            .font(theme.font(size: 18, weight: .bold))
                            .foregroundStyle(theme.accent)
                            .contentTransition(.numericText())
                    }

                    Divider()
                        .frame(height: 30)
                        .background(theme.divider)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sessions")
                            .font(.caption2)
                            .foregroundStyle(theme.secondary)
                        Text("\(data.sessions.count)")
                            .font(theme.font(size: 18, weight: .bold))
                            .foregroundStyle(theme.foreground)
                            .contentTransition(.numericText())
                    }

                    Divider()
                        .frame(height: 30)
                        .background(theme.divider)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hours")
                            .font(.caption2)
                            .foregroundStyle(theme.secondary)
                        Text(String(format: "%.1f", Double(data.totalMinutes) / 60.0))
                            .font(theme.font(size: 18, weight: .bold))
                            .foregroundStyle(theme.foreground)
                            .contentTransition(.numericText())
                    }
                }
                .padding(12)
                .background(theme.surface)
                .cornerRadius(8)

                Divider().background(theme.divider)

                SlopRecordListSection(
                    title: "Writing Sessions",
                    isEmpty: data.sessions.isEmpty,
                    addLabel: "Add Session",
                    onAdd: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.sessions.insert(WritingSession(), at: 0)
                        }
                    },
                    emptyState: {
                        EmptyState(
                            icon: "doc.text",
                            title: "No sessions yet",
                            subtitle: "Log your first writing session"
                        )
                    },
                    content: {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach($data.sessions) { $session in
                                    SlopSurfaceCard(padding: 12) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                SlopDateField($session.date)

                                                SlopTextField("Project", text: $session.project)
                                                    .font(theme.font(size: 13, weight: .semibold))
                                                    .foregroundStyle(theme.foreground)

                                                HStack(spacing: 12) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "doc.text")
                                                            .font(.caption2)
                                                            .foregroundStyle(theme.accent)

                                                        SlopNumberField("0", value: Binding(
                                                            get: { Double(session.wordCount) },
                                                            set: { session.wordCount = Int($0) }
                                                        ), format: "%.0f")
                                                        .font(.caption.weight(.bold))
                                                        .foregroundStyle(theme.accent)

                                                        Text("words")
                                                            .font(.caption2)
                                                            .foregroundStyle(theme.secondary)
                                                    }

                                                    HStack(spacing: 4) {
                                                        Image(systemName: "clock")
                                                            .font(.caption2)
                                                            .foregroundStyle(theme.secondary)

                                                        SlopNumberField("0", value: Binding(
                                                            get: { Double(session.duration) },
                                                            set: { session.duration = Int($0) }
                                                        ), format: "%.0f")
                                                        .font(.caption)
                                                        .foregroundStyle(theme.secondary)

                                                        Text("min")
                                                            .font(.caption2)
                                                            .foregroundStyle(theme.secondary)
                                                    }
                                                }
                                            }

                                            Spacer()

                                            VStack(spacing: 6) {
                                                MetricPill(
                                                    "\(session.wordCount)",
                                                    tint: session.wordCount >= data.dailyWordCount ? .green : theme.accent
                                                )

                                                RemoveButton {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        data.sessions.removeAll { $0.id == session.id }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                )

                Divider().background(theme.divider)

                // Summary
                VStack(spacing: 4) {
                    SummaryRow(
                        label: "Total Words",
                        value: formatNumber(data.totalWords),
                        valueColor: theme.accent,
                        isBold: true
                    )

                    SummaryRow(
                        label: "Current Streak",
                        value: "\(data.currentStreak) days",
                        valueColor: data.currentStreak >= 7 ? .green : theme.foreground
                    )

                    SummaryRow(
                        label: "Completion Rate",
                        value: "\(Int(data.progressToGoal * 100))%",
                        valueColor: data.progressToGoal >= 1.0 ? .green : theme.secondary
                    )
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    // MARK: - Helpers

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fk", Double(num) / 1000.0)
        }
        return "\(num)"
    }
}

