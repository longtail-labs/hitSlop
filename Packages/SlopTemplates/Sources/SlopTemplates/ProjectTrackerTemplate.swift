import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct ProjectTask: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Task Name") var name: String = ""
    @Field("Done") var isDone: Bool = false
}

@SlopData
public struct ProjectMilestone: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Milestone Name") var name: String = ""
    @Field("Deadline", editor: .date) var deadline: Date = .now
    @Field("Tasks") var tasks: [ProjectTask] = []

    var completedTasks: Int { tasks.filter(\.isDone).count }
    var totalTasks: Int { tasks.count }
    var progress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}

@SlopData
public struct ProjectTrackerData {
    @SlopKit.Section("Project")
    @Field("Project Name") var projectName: String = "Q2 Product Launch"
    @Field("Description", editor: .multiLine) var description: String = "Ship new features and templates"

    @SlopKit.Section("Milestones")
    @Field("Milestones") var milestones: [ProjectMilestone] = ProjectTrackerData.defaultMilestones

    var completedTasks: Int {
        milestones.reduce(0) { $0 + $1.completedTasks }
    }

    var totalTasks: Int {
        milestones.reduce(0) { $0 + $1.totalTasks }
    }

    var overallProgress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}

extension ProjectTrackerData {
    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    static var defaultMilestones: [ProjectMilestone] {
        func milestone(_ name: String, _ deadline: Date, _ tasks: [ProjectTask]) -> ProjectMilestone {
            var m = ProjectMilestone()
            m.name = name
            m.deadline = deadline
            m.tasks = tasks
            return m
        }

        func task(_ name: String, _ isDone: Bool = false) -> ProjectTask {
            var t = ProjectTask()
            t.name = name
            t.isDone = isDone
            return t
        }

        return [
            milestone("Planning & Design", makeDate(2026, 4, 15), [
                task("Define requirements", true),
                task("Create wireframes", true),
                task("Review with team", false),
            ]),
            milestone("Development", makeDate(2026, 5, 1), [
                task("Build core features", false),
                task("Write tests", false),
                task("Code review", false),
            ]),
            milestone("Launch", makeDate(2026, 5, 15), [
                task("Deploy to staging", false),
                task("QA testing", false),
                task("Production deploy", false),
            ]),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.project-tracker",
    name: "Project Tracker",
    description: "Track project milestones and tasks with progress visualization.",
    version: "1.0.0",
    width: 380, height: 600,
    minWidth: 340, minHeight: 500,
    shape: .roundedRect(radius: 16),
    theme: "signal-grid",
    alwaysOnTop: false,
    categories: ["work"]
)
struct ProjectTrackerView: View {
    @TemplateData var data: ProjectTrackerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(titlePlaceholder: "Project name", title: $data.projectName)

                SlopSurfaceCard(padding: 10) {
                    SlopTextArea("Description", text: $data.description, minHeight: 72)
                }

                // Overall metrics
                HStack(spacing: 10) {
                    MetricPill("\(data.completedTasks) done", tint: theme.accent)
                    MetricPill("\(data.totalTasks) tasks", tint: theme.secondary)
                    MetricPill("\(data.milestones.count) milestones", tint: theme.secondary)
                    Spacer()
                }

                // Overall progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Overall Progress")
                            .font(.caption2)
                            .foregroundStyle(theme.secondary)
                        Spacer()
                        Text("\(Int(data.overallProgress * 100))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.accent)
                            .contentTransition(.numericText())
                    }

                    ProgressBar(
                        progress: data.overallProgress,
                        fillColor: theme.accent,
                        backgroundColor: theme.surface,
                        height: 10
                    )
                }

                Divider().background(theme.divider)

                // Milestones
                if data.milestones.isEmpty {
                    EmptyState(
                        icon: "flag.checkered",
                        title: "No milestones yet",
                        subtitle: "Add your first milestone to start tracking"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach($data.milestones) { $milestone in
                                VStack(alignment: .leading, spacing: 10) {
                                    // Milestone header
                                    HStack(spacing: 8) {
                                        SlopTextField("Milestone", text: $milestone.name)
                                            .font(theme.font(size: 14, weight: .bold))
                                            .foregroundStyle(theme.foreground)

                                        Spacer()

                                        RemoveButton {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                data.milestones.removeAll { $0.id == milestone.id }
                                            }
                                        }
                                    }

                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .font(.caption)
                                            .foregroundStyle(theme.secondary)

                                        SlopDateField($milestone.deadline)
                                    }

                                    // Milestone progress
                                    HStack(spacing: 8) {
                                        ProgressBar(
                                            progress: milestone.progress,
                                            fillColor: theme.accent,
                                            backgroundColor: theme.surface,
                                            height: 6
                                        )
                                        .frame(maxWidth: .infinity)

                                        Text("\(milestone.completedTasks)/\(milestone.totalTasks)")
                                            .font(theme.mono(size: 10))
                                            .foregroundStyle(theme.secondary)
                                    }

                                    // Tasks
                                    if !milestone.tasks.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach($milestone.tasks) { $task in
                                                HStack(spacing: 8) {
                                                    // Checkbox
                                                    SlopInteractiveOnly {
                                                        Button {
                                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                                task.isDone.toggle()
                                                            }
                                                        } label: {
                                                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                                                .font(.caption)
                                                                .foregroundStyle(task.isDone ? theme.accent : theme.secondary.opacity(0.3))
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                    if renderTarget != .interactive {
                                                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                                            .font(.caption)
                                                            .foregroundStyle(task.isDone ? theme.accent : theme.secondary.opacity(0.3))
                                                    }

                                                    SlopTextField("Task", text: $task.name)
                                                        .font(theme.font(size: 12))
                                                        .foregroundStyle(task.isDone ? theme.secondary.opacity(0.7) : theme.foreground)
                                                        .strikethrough(task.isDone, color: theme.secondary)

                                                    if renderTarget != .interactive {
                                                        Spacer()
                                                    }

                                                    RemoveButton {
                                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                            milestone.tasks.removeAll { $0.id == task.id }
                                                        }
                                                    }
                                                }
                                            }

                                            AddItemButton("Add Task") {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    milestone.tasks.append(ProjectTask())
                                                }
                                            }
                                        }
                                        .padding(.leading, 20)
                                    }
                                }
                                .padding(12)
                                .background(theme.surface)
                                .cornerRadius(8)
                            }

                            AddItemButton("Add Milestone") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    data.milestones.append(ProjectMilestone())
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

