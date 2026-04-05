import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct FinancialGoal: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Target Amount") var targetAmount: Double = 0
    @Field("Current Amount") var currentAmount: Double = 0
    @Field("Monthly Contribution") var monthlyContribution: Double = 0
    @Field("Deadline") var deadline: String = ""

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }

    var remaining: Double {
        max(targetAmount - currentAmount, 0)
    }

    var monthsRemaining: Int {
        guard monthlyContribution > 0, remaining > 0 else { return 0 }
        return Int(ceil(remaining / monthlyContribution))
    }

    var isOnTrack: Bool {
        // Simple heuristic: if we have a deadline, check if we're on pace
        guard !deadline.isEmpty else { return true }
        // For now, just check if we're making progress
        return monthlyContribution > 0
    }

    var statusColor: Color {
        if progress >= 1.0 { return .green }
        if isOnTrack { return .blue }
        return .orange
    }

    var statusText: String {
        if progress >= 1.0 { return "Complete" }
        if isOnTrack { return "On Track" }
        return "Review"
    }
}

@SlopData
public struct FinancialGoalsSimulatorData {
    @SlopKit.Section("Overview") @Field("Title") var title: String = "Financial Goals"
    @Field("Currency", options: ["USD", "EUR", "GBP", "JPY"]) var currency: String = "USD"
    @SlopKit.Section("Goals") @Field("Goals") var goals: [FinancialGoal] = FinancialGoalsSimulatorData.defaultGoals

    var totalTarget: Double { goals.reduce(0) { $0 + $1.targetAmount } }
    var totalCurrent: Double { goals.reduce(0) { $0 + $1.currentAmount } }
    var totalMonthlyContribution: Double { goals.reduce(0) { $0 + $1.monthlyContribution } }
    var overallProgress: Double {
        guard totalTarget > 0 else { return 0 }
        return min(totalCurrent / totalTarget, 1.0)
    }
    var goalsCompleted: Int { goals.filter { $0.progress >= 1.0 }.count }
}

extension FinancialGoalsSimulatorData {
    static var defaultGoals: [FinancialGoal] {
        func goal(_ name: String, _ target: Double, _ current: Double, _ monthly: Double, _ deadline: String) -> FinancialGoal {
            var g = FinancialGoal()
            g.name = name
            g.targetAmount = target
            g.currentAmount = current
            g.monthlyContribution = monthly
            g.deadline = deadline
            return g
        }

        return [
            goal("Emergency Fund", 10000, 3500, 500, "Dec 2026"),
            goal("Vacation", 3000, 1200, 200, "Jun 2026"),
            goal("Down Payment", 50000, 15000, 1000, "Dec 2027"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.financial-goals-simulator",
    name: "Financial Goals Simulator",
    description: "Track savings goals with progress indicators and timeline projections.",
    version: "1.0.0",
    width: 380, height: 700,
    minWidth: 340, minHeight: 550,
    shape: .roundedRect(radius: 16),
    theme: "terminal",
    alwaysOnTop: false,
    categories: ["finance"]
)
struct FinancialGoalsSimulatorView: View {
    @TemplateData var data: FinancialGoalsSimulatorData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                SlopTextField("Title", text: $data.title)
                    .font(theme.title(size: 22))
                    .foregroundStyle(theme.foreground)

                // Overall metrics
                HStack(spacing: 10) {
                    MetricPill(
                        "\(data.goalsCompleted)/\(data.goals.count)",
                        tint: .green
                    )
                    MetricPill(
                        "\(String(format: "%.0f", data.overallProgress * 100))%",
                        tint: theme.accent
                    )
                    Spacer()
                }

                // Overall progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Overall Progress")
                            .font(.caption)
                            .foregroundStyle(theme.secondary)
                        Spacer()
                        Text(formatted(data.totalCurrent))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.foreground)
                        Text("of")
                            .font(.caption2)
                            .foregroundStyle(theme.secondary)
                        Text(formatted(data.totalTarget))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.foreground)
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
                        title: "No goals set",
                        subtitle: "Add a financial goal to start tracking"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach($data.goals) { $goal in
                            VStack(alignment: .leading, spacing: 8) {
                                // Goal header
                                HStack {
                                    SlopTextField("Goal name", text: $goal.name)
                                        .font(theme.font(size: 14, weight: .semibold))
                                        .foregroundStyle(theme.foreground)
                                    Spacer()
                                    MetricPill(
                                        goal.statusText,
                                        tint: goal.statusColor
                                    )
                                    RemoveButton {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            data.goals.removeAll { $0.id == goal.id }
                                        }
                                    }
                                }

                                // Progress bar
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(formatted(goal.currentAmount))
                                            .font(.caption)
                                            .foregroundStyle(theme.foreground)
                                        Spacer()
                                        Text(formatted(goal.targetAmount))
                                            .font(.caption)
                                            .foregroundStyle(theme.secondary)
                                    }
                                    ProgressBar(
                                        progress: goal.progress,
                                        fillColor: goal.statusColor,
                                        backgroundColor: theme.surface,
                                        height: 8
                                    )
                                }

                                // Stats
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Remaining")
                                            .font(theme.font(size: 9))
                                            .foregroundStyle(theme.secondary)
                                        Text(formatted(goal.remaining))
                                            .font(theme.font(size: 11, weight: .semibold))
                                            .foregroundStyle(theme.foreground)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Months Left")
                                            .font(theme.font(size: 9))
                                            .foregroundStyle(theme.secondary)
                                        Text("\(goal.monthsRemaining)")
                                            .font(theme.font(size: 11, weight: .semibold))
                                            .foregroundStyle(theme.accent)
                                    }
                                    Spacer()
                                }

                                // Editable fields
                                SlopInteractiveOnly {
                                    VStack(spacing: 6) {
                                        HStack {
                                            Text("Target:")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondary)
                                            Spacer()
                                            CurrencyInput(
                                                currency: data.currency,
                                                value: $goal.targetAmount,
                                                width: 80,
                                                symbolColor: theme.secondary,
                                                valueColor: theme.foreground
                                            )
                                        }
                                        HStack {
                                            Text("Current:")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondary)
                                            Spacer()
                                            CurrencyInput(
                                                currency: data.currency,
                                                value: $goal.currentAmount,
                                                width: 80,
                                                symbolColor: theme.secondary,
                                                valueColor: theme.foreground
                                            )
                                        }
                                        HStack {
                                            Text("Monthly:")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondary)
                                            Spacer()
                                            CurrencyInput(
                                                currency: data.currency,
                                                value: $goal.monthlyContribution,
                                                width: 80,
                                                symbolColor: theme.secondary,
                                                valueColor: theme.foreground
                                            )
                                        }
                                        HStack {
                                            Text("Deadline:")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondary)
                                            Spacer()
                                            SlopTextField("Dec 2026", text: $goal.deadline)
                                                .font(.caption)
                                                .multilineTextAlignment(.trailing)
                                                .frame(width: 80)
                                        }
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                            .padding(12)
                            .background(theme.surface.opacity(0.3))
                            .cornerRadius(8)
                        }

                        AddItemButton("Add Goal") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.goals.append(FinancialGoal())
                            }
                        }
                    }
                }

                Divider().background(theme.divider)

                // Summary
                SummaryRow(
                    label: "Total Target",
                    value: formatted(data.totalTarget),
                    valueColor: theme.secondary
                )

                SummaryRow(
                    label: "Total Saved",
                    value: formatted(data.totalCurrent),
                    valueColor: theme.accent,
                    isBold: true
                )

                SummaryRow(
                    label: "Monthly Contributions",
                    value: formatted(data.totalMonthlyContribution),
                    valueColor: .green
                )
            }
            .padding(24)
        }
        .background(theme.background)
    }

    // MARK: - Helpers

    private func formatted(_ value: Double) -> String {
        "\(currencySymbol(for: data.currency))\(String(format: "%.0f", value))"
    }
}

