import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct CleaningTask: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Room") var room: String = ""
    @Field("Frequency", options: ["Daily", "Weekly", "Biweekly", "Monthly"]) var frequency: String = "Weekly"
    @Field("Last Done") var lastDone: Date = .now
    @Field("Assignee") var assignee: String = ""
}

@SlopData
public struct CleaningScheduleData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Cleaning Schedule"

    @SlopKit.Section("Tasks")
    @Field("Tasks") var tasks: [CleaningTask] = CleaningScheduleData.defaultTasks

    var overdueCount: Int {
        tasks.filter { Calendar.current.dateComponents([.day], from: $0.lastDone, to: .now).day ?? 0 > 7 }.count
    }

    var completedCount: Int {
        tasks.filter { Calendar.current.dateComponents([.day], from: $0.lastDone, to: .now).day ?? 0 <= 7 }.count
    }
}

extension CleaningScheduleData {
    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }

    static var defaultTasks: [CleaningTask] {
        func task(_ name: String, _ room: String, _ frequency: String, _ lastDone: Date, _ assignee: String) -> CleaningTask {
            var t = CleaningTask()
            t.name = name
            t.room = room
            t.frequency = frequency
            t.lastDone = lastDone
            t.assignee = assignee
            return t
        }

        return [
            task("Vacuum Living Room", "Living Room", "Weekly", makeDate(2026, 3, 28), "Me"),
            task("Clean Bathroom", "Bathroom", "Weekly", makeDate(2026, 3, 25), "Partner"),
            task("Wash Dishes", "Kitchen", "Daily", makeDate(2026, 3, 30), "Me"),
            task("Mop Kitchen", "Kitchen", "Biweekly", makeDate(2026, 3, 20), "Me"),
            task("Dust Shelves", "Living Room", "Monthly", makeDate(2026, 3, 1), "Partner")
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.cleaning-schedule",
    name: "Cleaning Schedule",
    description: "Stay on top of household chores with frequency tracking and overdue alerts.",
    version: "1.0.0",
    width: 380, height: 520,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["personal"]
)
struct CleaningScheduleView: View {
    @TemplateData var data: CleaningScheduleData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                SlopTextField("Title", text: $data.title)
                    .font(theme.titleFont)
                    .foregroundColor(theme.foreground)

                // Summary badges
                HStack(spacing: 8) {
                    if data.overdueCount > 0 {
                        Label("\(data.overdueCount) overdue", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(12)
                    }

                    Label("\(data.completedCount) done", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(12)
                }

                Divider()
                    .background(theme.divider)

                // Task list
                VStack(alignment: .leading, spacing: 12) {
                    ForEach($data.tasks) { $task in
                        TaskRow(task: $task, theme: theme, renderTarget: renderTarget)
                    }
                }

                // Add task button
                SlopInteractiveOnly {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.tasks.append(CleaningTask())
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Task")
                        }
                        .font(.subheadline)
                        .foregroundColor(theme.accent)
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

struct TaskRow: View {
    @Binding var task: CleaningTask
    let theme: SlopTheme
    let renderTarget: SlopRenderTarget

    var frequencyColor: Color {
        switch task.frequency {
        case "Daily": return .orange
        case "Weekly": return .blue
        case "Biweekly": return .purple
        case "Monthly": return .green
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SlopTextField("Task name", text: $task.name)
                        .font(.body.bold())
                        .foregroundColor(theme.foreground)

                    HStack(spacing: 8) {
                        SlopTextField("Room", text: $task.room)
                            .font(.caption)
                            .foregroundColor(theme.secondary)

                        Text(task.frequency)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(frequencyColor)
                            .cornerRadius(8)

                        SlopTextField("Assignee", text: $task.assignee)
                            .font(.caption)
                            .foregroundColor(theme.secondary)
                    }
                }

                Spacer()
            }

            HStack {
                SlopEditable($task.lastDone) { value in
                    Text(value, style: .date)
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                } editor: { $value in
                    DatePicker("", selection: $value, displayedComponents: .date)
                        .labelsHidden()
                }

                Spacer()

                SlopInteractiveOnly {
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                task.lastDone = Date()
                            }
                        }) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(8)
    }
}
