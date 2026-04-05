import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct WeeklyReviewData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Weekly Review"
    @Field("Week Of", editor: .date) var weekOf: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 6)) ?? .now
    @Field("Mood", options: ["energized", "steady", "tired"]) var mood: String = "steady"

    @SlopKit.Section("Reflection")
    @Field("Wins", editor: .stringList) var wins: [String] = [
        "Shipped the picker refactor",
        "Finished the new theme catalog",
        "Reduced duplicate inline field code"
    ]
    @Field("Lessons", editor: .stringList) var lessons: [String] = [
        "Template polish needs shared controls first",
        "Theme resources should be data-first"
    ]
    @Field("Blockers", editor: .stringList) var blockers: [String] = [
        "A few templates still need migration",
        "Need visual QA on the picker"
    ]
    @Field("Next Week Priorities", editor: .stringList) var nextWeekPriorities: [String] = [
        "Finish template migrations",
        "Run focused QA on date editing",
        "Tighten export snapshots"
    ]

    var completionCount: Int {
        wins.count + lessons.count + nextWeekPriorities.count
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.weekly-review",
    name: "Weekly Review",
    description: "A GTD-style weekly reflection with wins, blockers, and next-week priorities.",
    version: "1.0.0",
    width: 420, height: 620,
    minWidth: 360, minHeight: 520,
    shape: .roundedRect(radius: 18),
    theme: "paper-ledger",
    alwaysOnTop: false,
    categories: ["personal"]
)
struct WeeklyReviewView: View {
    @TemplateData var data: WeeklyReviewData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(titlePlaceholder: "Weekly review", title: $data.title) {
                    SlopSurfaceCard(padding: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            SlopDateField($data.weekOf)
                            SlopEnumField(selection: $data.mood, options: ["energized", "steady", "tired"])
                                .font(.caption)
                        }
                    }
                }

                HStack(spacing: 10) {
                    MetricPill("\(data.wins.count) wins", tint: theme.accent)
                    MetricPill("\(data.blockers.count) blockers", tint: theme.secondary)
                    MetricPill("\(data.completionCount) notes", tint: theme.foreground.opacity(0.5))
                    Spacer()
                }

                SlopSurfaceCard {
                    SlopStringListEditor(
                        title: "Wins",
                        items: $data.wins,
                        addLabel: "Add Win",
                        placeholder: "A real win from the week"
                    )
                }

                SlopSurfaceCard {
                    SlopStringListEditor(
                        title: "Lessons",
                        items: $data.lessons,
                        addLabel: "Add Lesson",
                        placeholder: "What changed your thinking?"
                    )
                }

                SlopSurfaceCard {
                    SlopStringListEditor(
                        title: "Blockers",
                        items: $data.blockers,
                        addLabel: "Add Blocker",
                        placeholder: "What slowed you down?"
                    )
                }

                SlopSurfaceCard {
                    SlopStringListEditor(
                        title: "Next Week Priorities",
                        items: $data.nextWeekPriorities,
                        addLabel: "Add Priority",
                        placeholder: "What should happen next?"
                    )
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

