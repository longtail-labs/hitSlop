import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct DailyTimeBlock: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Time", hint: "09:00") var time: String = ""
    @Field("Activity", editor: .multiLine) var activity: String = ""
    @Field("Done") var isDone: Bool = false
}

@SlopData
public struct DailyPlannerData {
    @SlopKit.Section("Overview")
    @Field("Date", editor: .date) var date: Date = DailyPlannerData.makeDate(2026, 4, 3)
    @Field("Focus", editor: .multiLine) var focus: String = "Deep work on Q2 goals"
    @Field("Top Priority", editor: .multiLine) var topPriority: String = "Finish portfolio templates"

    @SlopKit.Section("Time Blocks")
    @Field("Time Blocks") var blocks: [DailyTimeBlock] = DailyPlannerData.defaultBlocks

    var completedCount: Int { blocks.filter(\.isDone).count }
    var totalCount: Int { blocks.count }
    var completionRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

extension DailyPlannerData {
    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    static var defaultBlocks: [DailyTimeBlock] {
        func block(_ time: String, _ activity: String, _ isDone: Bool = false) -> DailyTimeBlock {
            var b = DailyTimeBlock()
            b.time = time
            b.activity = activity
            b.isDone = isDone
            return b
        }

        return [
            block("7:00", "Morning routine", true),
            block("8:00", "Deep work: Templates", true),
            block("10:00", "Team standup", false),
            block("11:00", "Code review", false),
            block("12:00", "Lunch break", false),
            block("13:00", "Focus: Implementation", false),
            block("15:00", "Emails and slack", false),
            block("17:00", "Evening walk", false),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.daily-planner",
    name: "Daily Planner",
    description: "Plan your day with time blocks and track completion progress.",
    version: "1.0.0",
    width: 340, height: 580,
    minWidth: 300, minHeight: 450,
    shape: .roundedRect(radius: 16),
    theme: "studio-noir",
    alwaysOnTop: true,
    categories: ["popular", "work"]
)
struct DailyPlannerView: View {
    @TemplateData var data: DailyPlannerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(
                    titlePlaceholder: "Top priority",
                    title: $data.topPriority,
                    subtitlePlaceholder: "Today's focus",
                    subtitle: $data.focus
                ) {
                    SlopSurfaceCard(padding: 10) {
                        SlopDateField($data.date)
                    }
                }

                HStack(spacing: 10) {
                    MetricPill("\(data.completedCount) done", tint: theme.accent)
                    MetricPill("\(data.totalCount - data.completedCount) left", tint: theme.secondary)
                    Spacer()
                }

                ProgressBar(
                    progress: data.completionRatio,
                    fillColor: theme.accent,
                    backgroundColor: theme.surface,
                    height: 8
                )

                Divider().background(theme.divider)

                SlopRecordListSection(
                    title: "Schedule",
                    isEmpty: data.blocks.isEmpty,
                    addLabel: "Add Block",
                    onAdd: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.blocks.append(DailyTimeBlock())
                        }
                    },
                    emptyState: {
                        EmptyState(
                            icon: "calendar",
                            title: "No time blocks yet",
                            subtitle: "Add your first block to plan your day"
                        )
                    },
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach($data.blocks) { $block in
                                SlopSurfaceCard(padding: 12) {
                                    HStack(alignment: .top, spacing: 12) {
                                        HStack(spacing: 8) {
                                            SlopInteractiveOnly {
                                                Button {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        block.isDone.toggle()
                                                    }
                                                } label: {
                                                    Image(systemName: block.isDone ? "checkmark.circle.fill" : "circle")
                                                        .foregroundStyle(block.isDone ? theme.accent : theme.secondary.opacity(0.35))
                                                }
                                                .buttonStyle(.plain)
                                            }

                                            if renderTarget != .interactive {
                                                Image(systemName: block.isDone ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(block.isDone ? theme.accent : theme.secondary.opacity(0.35))
                                            }

                                            SlopTextField("09:00", text: $block.time)
                                                .font(theme.monoFont.weight(.semibold))
                                                .foregroundStyle(block.isDone ? theme.secondary : theme.accent)
                                                .frame(width: 62, alignment: .leading)
                                        }

                                        SlopTextArea("What matters in this block?", text: $block.activity, minHeight: 54)
                                            .font(theme.font(size: 13, weight: block.isDone ? .regular : .medium))
                                            .foregroundStyle(block.isDone ? theme.secondary : theme.foreground)
                                            .strikethrough(block.isDone, color: theme.secondary)

                                        RemoveButton {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                data.blocks.removeAll { $0.id == block.id }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                )

                Divider().background(theme.divider)

                SlopSurfaceCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Completion")
                                .font(.caption2)
                                .foregroundStyle(theme.secondary)
                            Text("\(Int(data.completionRatio * 100))%")
                                .font(theme.title(size: 24))
                                .foregroundStyle(theme.accent)
                                .contentTransition(.numericText())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Blocks")
                                .font(.caption2)
                                .foregroundStyle(theme.secondary)
                            Text("\(data.totalCount)")
                                .font(theme.title(size: 24))
                                .foregroundStyle(theme.foreground)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

