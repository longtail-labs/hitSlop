import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct TimeBlock: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Time") var time: String = "9:00 AM"
    @Field("Task") var task: String = ""
    @Field("Done") var done: Bool = false
}

@SlopData
public struct PlannerDay: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = "Monday"
    @Field("Blocks") var blocks: [TimeBlock] = []
}

@SlopData
public struct WeeklyPlannerData {
    @SlopKit.Section("Week")
    @Field("Week Of") var weekOf: String = "March 30, 2026"

    @SlopKit.Section("Days")
    @Field("Days") var days: [PlannerDay] = defaultDays

    var totalTasks: Int {
        days.reduce(0) { $0 + $1.blocks.count }
    }

    var completedTasks: Int {
        days.reduce(0) { total, day in
            total + day.blocks.filter { $0.done }.count
        }
    }

    var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}

extension WeeklyPlannerData {
    static var defaultDays: [PlannerDay] {
        func block(_ time: String, _ task: String, _ done: Bool) -> TimeBlock {
            var b = TimeBlock()
            b.time = time
            b.task = task
            b.done = done
            return b
        }

        func day(_ name: String, _ blocks: [TimeBlock]) -> PlannerDay {
            var d = PlannerDay()
            d.name = name
            d.blocks = blocks
            return d
        }

        return [
            day("Monday", [
                block("9:00 AM", "Team standup", false),
                block("10:00 AM", "Project review", false),
                block("2:00 PM", "Client meeting", false)
            ]),
            day("Tuesday", [
                block("9:30 AM", "Design session", false),
                block("1:00 PM", "Code review", false)
            ]),
            day("Wednesday", [
                block("10:00 AM", "Sprint planning", false),
                block("3:00 PM", "1-on-1 with manager", false)
            ]),
            day("Thursday", [
                block("9:00 AM", "Focus time - coding", false),
                block("2:00 PM", "Testing session", false),
                block("4:00 PM", "Documentation", false)
            ]),
            day("Friday", [
                block("9:00 AM", "Weekly recap", false),
                block("11:00 AM", "Deploy to staging", false)
            ]),
            day("Saturday", []),
            day("Sunday", [])
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.weekly-planner",
    name: "Weekly Planner",
    description: "Organize your week with time blocks for each day.",
    version: "1.0.0",
    width: 500, height: 600,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["personal"]
)
struct WeeklyPlannerView: View {
    @TemplateData var data: WeeklyPlannerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    private let dayAbbreviations = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Week of")
                            .font(theme.font(size: 14))
                            .foregroundColor(theme.secondary)

                        SlopTextField("Week Of", text: $data.weekOf)
                            .font(theme.titleFont)
                            .foregroundColor(theme.foreground)
                    }

                    // Completion summary
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(data.completedTasks)/\(data.totalTasks) tasks done")
                                .font(theme.font(size: 13))
                                .foregroundColor(theme.secondary)

                            Spacer()

                            Text("\(Int(data.completionRate * 100))%")
                                .font(theme.font(size: 13, weight: .medium))
                                .foregroundColor(theme.accent)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.surface)
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.accent)
                                    .frame(width: geometry.size.width * data.completionRate, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }

                Divider()
                    .background(theme.divider)

                // 7-column grid
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(data.days.enumerated()), id: \.offset) { dayIndex, day in
                        VStack(spacing: 8) {
                            // Day header
                            Text(dayAbbreviations[dayIndex])
                                .font(theme.font(size: 11, weight: .semibold))
                                .foregroundColor(theme.foreground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(theme.surface)
                                .cornerRadius(6)

                            // Time blocks
                            VStack(spacing: 6) {
                                ForEach(Array(day.blocks.enumerated()), id: \.element.id) { blockIndex, block in
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Time
                                        SlopTextField("Time", text: Binding(
                                            get: { data.days[dayIndex].blocks[blockIndex].time },
                                            set: { data.days[dayIndex].blocks[blockIndex].time = $0 }
                                        ))
                                        .font(theme.font(size: 9))
                                        .foregroundColor(theme.secondary)
                                        .lineLimit(1)

                                        // Task
                                        HStack(spacing: 4) {
                                            if renderTarget == .interactive {
                                                SlopInteractiveOnly {
                                                    Button(action: {
                                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                            data.days[dayIndex].blocks[blockIndex].done.toggle()
                                                        }
                                                    }) {
                                                        Image(systemName: block.done ? "checkmark.circle.fill" : "circle")
                                                            .font(theme.font(size: 10))
                                                            .foregroundColor(block.done ? theme.accent : theme.secondary.opacity(0.5))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            } else {
                                                if block.done {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(theme.font(size: 10))
                                                        .foregroundColor(theme.accent)
                                                }
                                            }

                                            SlopTextField("Task", text: Binding(
                                                get: { data.days[dayIndex].blocks[blockIndex].task },
                                                set: { data.days[dayIndex].blocks[blockIndex].task = $0 }
                                            ))
                                            .font(theme.font(size: 10))
                                            .foregroundColor(block.done ? theme.secondary.opacity(0.6) : theme.foreground)
                                            .strikethrough(block.done)
                                            .lineLimit(2)
                                        }
                                    }
                                    .padding(6)
                                    .background(theme.surface)
                                    .cornerRadius(4)
                                    .opacity(block.done ? 0.7 : 1.0)
                                }

                                // Add block button
                                SlopInteractiveOnly {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            var newBlock = TimeBlock()
                                            newBlock.time = "12:00 PM"
                                            newBlock.task = "New task"
                                            newBlock.done = false
                                            data.days[dayIndex].blocks.append(newBlock)
                                        }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(theme.font(size: 12))
                                            .foregroundColor(theme.accent.opacity(0.6))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .background(theme.background)
    }
}
