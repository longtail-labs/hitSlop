import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct GoalMilestone: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Done") var isDone: Bool = false
}

@SlopData
public struct Goal: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Description") var description: String = ""
    @Field("Deadline") var deadline: String = ""
    @Field("Milestones") var milestones: [GoalMilestone] = []

    var completedMilestones: Int { milestones.filter(\.isDone).count }
    var totalMilestones: Int { milestones.count }
    var progress: Double {
        guard totalMilestones > 0 else { return 0 }
        return Double(completedMilestones) / Double(totalMilestones)
    }
}

@SlopData
public struct GoalTrackerData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "2026 Goals"
    @Field("Goals") var goals: [Goal] = GoalTrackerData.defaultGoals

    var totalMilestones: Int { goals.reduce(0) { $0 + $1.totalMilestones } }
    var completedMilestones: Int { goals.reduce(0) { $0 + $1.completedMilestones } }
    var overallProgress: Double {
        guard totalMilestones > 0 else { return 0 }
        return Double(completedMilestones) / Double(totalMilestones)
    }
}

extension GoalTrackerData {
    static var defaultGoals: [Goal] {
        var goal1 = Goal()
        goal1.name = "Launch Product"
        goal1.description = "Ship v1.0 to production"
        goal1.deadline = "June 2026"

        var m1 = GoalMilestone()
        m1.name = "Complete MVP"
        m1.isDone = true
        var m2 = GoalMilestone()
        m2.name = "Beta testing"
        m2.isDone = true
        var m3 = GoalMilestone()
        m3.name = "Production deploy"
        m3.isDone = false

        goal1.milestones = [m1, m2, m3]

        var goal2 = Goal()
        goal2.name = "Fitness Goal"
        goal2.description = "Run a half marathon"
        goal2.deadline = "October 2026"

        var m4 = GoalMilestone()
        m4.name = "5K milestone"
        m4.isDone = false
        var m5 = GoalMilestone()
        m5.name = "10K milestone"
        m5.isDone = false

        goal2.milestones = [m4, m5]

        return [goal1, goal2]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.goal-tracker",
    name: "Goal Tracker",
    description: "Track long-term goals with milestones and progress monitoring.",
    version: "1.0.0",
    width: 380, height: 620,
    minWidth: 340, minHeight: 500,
    shape: .roundedRect(radius: 16),
    theme: "cool",
    alwaysOnTop: true,
    categories: ["work"]
)
struct GoalTrackerView: View {
    @TemplateData var data: GoalTrackerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                SlopTextField("Title", text: $data.title)
                    .font(theme.title(size: 24))
                    .foregroundStyle(theme.foreground)

                // Overall progress
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        MetricPill("\(data.goals.count) goals", tint: theme.accent)
                        MetricPill("\(data.completedMilestones)/\(data.totalMilestones) milestones", tint: theme.secondary)
                        Spacer()
                    }

                    ProgressBar(
                        progress: data.overallProgress,
                        fillColor: theme.accent,
                        backgroundColor: theme.surface,
                        height: 10
                    )
                }

                Divider().background(theme.divider)

                // Goals list
                if data.goals.isEmpty {
                    EmptyState(
                        icon: "target",
                        title: "No goals yet",
                        subtitle: "Add your first goal to start tracking"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach($data.goals) { $goal in
                                goalCard(goal: $goal)
                            }

                            AddItemButton("Add Goal") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    data.goals.append(Goal())
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

    @ViewBuilder
    private func goalCard(goal: Binding<Goal>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    SlopTextField("Goal name", text: goal.name)
                        .font(theme.font(size: 16, weight: .bold))
                        .foregroundStyle(theme.foreground)

                    SlopTextField("Description", text: goal.description)
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                }

                Spacer()

                RemoveButton {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.goals.removeAll { $0.id == goal.wrappedValue.id }
                    }
                }
            }

            HStack {
                Image(systemName: "calendar")
                    .font(theme.font(size: 10))
                    .foregroundStyle(theme.secondary)
                SlopTextField("Deadline", text: goal.deadline)
                    .font(theme.font(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondary)
            }

            // Progress
            HStack(spacing: 8) {
                MetricPill("\(Int(goal.wrappedValue.progress * 100))%", tint: theme.accent)
                MetricPill("\(goal.wrappedValue.completedMilestones)/\(goal.wrappedValue.totalMilestones)", tint: theme.secondary)
                Spacer()
            }

            ProgressBar(
                progress: goal.wrappedValue.progress,
                fillColor: theme.accent,
                backgroundColor: theme.surface,
                height: 6
            )

            // Milestones
            if !goal.wrappedValue.milestones.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader("Milestones")

                    ForEach(goal.milestones) { $milestone in
                        HStack(spacing: 10) {
                            SlopInteractiveOnly {
                                Button {
                                    withAnimation { milestone.isDone.toggle() }
                                } label: {
                                    Image(systemName: milestone.isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(milestone.isDone ? theme.accent : theme.secondary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                            }
                            if renderTarget != .interactive {
                                Image(systemName: milestone.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(milestone.isDone ? theme.accent : theme.secondary.opacity(0.3))
                            }

                            SlopTextField("Milestone", text: $milestone.name)
                                .font(theme.font(size: 12, weight: milestone.isDone ? .regular : .medium))
                                .foregroundStyle(milestone.isDone ? theme.secondary.opacity(0.7) : theme.foreground)
                                .strikethrough(milestone.isDone, color: theme.secondary)

                            if renderTarget != .interactive {
                                Spacer()
                            }

                            RemoveButton {
                                withAnimation {
                                    goal.wrappedValue.milestones.removeAll { $0.id == milestone.id }
                                }
                            }
                        }
                    }

                    AddItemButton("Add Milestone") {
                        withAnimation {
                            goal.wrappedValue.milestones.append(GoalMilestone())
                        }
                    }
                }
            } else {
                AddItemButton("Add First Milestone") {
                    withAnimation {
                        goal.wrappedValue.milestones.append(GoalMilestone())
                    }
                }
            }
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(12)
    }
}

