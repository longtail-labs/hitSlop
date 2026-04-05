import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct FIRECalculatorData {
    @SlopKit.Section("Inputs")
    @Field("Current Savings") var currentSavings: Double = 50000
    @Field("Annual Income") var annualIncome: Double = 85000
    @Field("Annual Expenses") var annualExpenses: Double = 45000
    @Field("Expected Return") var expectedReturn: Double = 7.0
    @Field("Target Multiple") var targetMultiple: Double = 25

    var savingsRate: Double {
        guard annualIncome > 0 else { return 0 }
        return ((annualIncome - annualExpenses) / annualIncome) * 100
    }

    var annualSavings: Double {
        max(0, annualIncome - annualExpenses)
    }

    var fireNumber: Double {
        annualExpenses * targetMultiple
    }

    var yearsToFIRE: Double {
        guard fireNumber > 0, annualSavings > 0, expectedReturn > 0 else { return 100 }

        var currentAmount = currentSavings
        var years: Double = 0
        let returnRate = expectedReturn / 100.0

        while currentAmount < fireNumber && years < 100 {
            currentAmount = currentAmount * (1 + returnRate) + annualSavings
            years += 1
        }

        return years >= 100 ? 100 : years
    }

    var monthlyNeeded: Double {
        annualSavings / 12
    }

    var currentProgress: Double {
        guard fireNumber > 0 else { return 0 }
        return min((currentSavings / fireNumber) * 100, 100)
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.fire-calculator",
    name: "FIRE Calculator",
    description: "Calculate your path to financial independence with savings projections.",
    version: "1.0.0",
    width: 400, height: 540,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["finance"]
)
struct FIRECalculatorView: View {
    @TemplateData var data: FIRECalculatorData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text("FIRE Calculator")
                    .font(theme.titleFont)
                    .foregroundColor(theme.foreground)

                // Hero Number
                VStack(alignment: .center, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", data.yearsToFIRE))
                            .font(theme.title(size: 52))
                            .foregroundColor(theme.accent)
                        Text("years")
                            .font(theme.font(size: 20, weight: .medium))
                            .foregroundColor(theme.secondary)
                    }
                    Text("to FIRE")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)

                    Text("$" + String(format: "%.0f", data.fireNumber))
                        .font(theme.bodyFont.weight(.medium))
                        .foregroundColor(theme.foreground)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                // Savings Rate Circle
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(theme.surface, lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: min(data.savingsRate / 100, 1.0))
                            .stroke(theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text(String(format: "%.0f%%", data.savingsRate))
                                .font(theme.font(size: 16, weight: .bold))
                                .foregroundColor(theme.foreground)
                            Text("savings")
                                .font(.caption2)
                                .foregroundColor(theme.secondary)
                        }
                    }
                    Spacer()
                }

                Divider()
                    .background(theme.divider)

                // Input Fields
                VStack(alignment: .leading, spacing: 16) {
                    InputRow(
                        label: "Current Savings",
                        value: $data.currentSavings,
                        theme: theme
                    )

                    InputRow(
                        label: "Annual Income",
                        value: $data.annualIncome,
                        theme: theme
                    )

                    InputRow(
                        label: "Annual Expenses",
                        value: $data.annualExpenses,
                        theme: theme
                    )

                    InputRow(
                        label: "Expected Return %",
                        value: $data.expectedReturn,
                        theme: theme
                    )

                    InputRow(
                        label: "Target Multiple",
                        value: $data.targetMultiple,
                        theme: theme
                    )
                }

                Divider()
                    .background(theme.divider)

                // Summary Stats Grid
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        StatCard(
                            label: "Monthly Savings",
                            value: "$" + String(format: "%.0f", data.monthlyNeeded),
                            theme: theme
                        )

                        StatCard(
                            label: "FIRE Number",
                            value: "$" + String(format: "%.0f", data.fireNumber),
                            theme: theme
                        )
                    }

                    HStack(spacing: 12) {
                        StatCard(
                            label: "Savings Rate",
                            value: String(format: "%.1f%%", data.savingsRate),
                            theme: theme
                        )

                        StatCard(
                            label: "Current Progress",
                            value: String(format: "%.1f%%", data.currentProgress),
                            theme: theme
                        )
                    }
                }

                // Progress Bar
                VStack(alignment: .leading, spacing: 6) {
                    Text("Progress to FIRE")
                        .font(.caption)
                        .foregroundColor(theme.secondary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(theme.surface)
                                .frame(height: 12)
                                .cornerRadius(6)

                            Rectangle()
                                .fill(theme.accent)
                                .frame(width: geometry.size.width * CGFloat(data.currentProgress / 100), height: 12)
                                .cornerRadius(6)
                        }
                    }
                    .frame(height: 12)
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

// Helper Views
private struct InputRow: View {
    let label: String
    @Binding var value: Double
    let theme: SlopTheme

    var body: some View {
        HStack {
            Text(label)
                .font(theme.bodyFont)
                .foregroundColor(theme.secondary)

            Spacer()

            HStack(spacing: 4) {
                Text(label.contains("%") ? "" : "$")
                    .font(theme.bodyFont)
                    .foregroundColor(theme.secondary)
                SlopNumberField("0", value: $value)
                    .font(theme.bodyFont.weight(.medium))
                    .foregroundColor(theme.foreground)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    let theme: SlopTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondary)
            Text(value)
                .font(theme.bodyFont.weight(.semibold))
                .foregroundColor(theme.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.surface)
        .cornerRadius(8)
    }
}
