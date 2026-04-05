import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct Debt: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Balance") var balance: Double = 0
    @Field("Interest Rate") var interestRate: Double = 0
    @Field("Minimum Payment") var minimumPayment: Double = 0
    @Field("Extra Payment") var extraPayment: Double = 0

    var totalPayment: Double { minimumPayment + extraPayment }
    var monthlyInterest: Double { (interestRate / 100) / 12 }

    var monthsToPayoff: Int {
        guard totalPayment > 0, balance > 0 else { return 0 }
        let principal = totalPayment - (balance * monthlyInterest)
        guard principal > 0 else { return 999 }
        return Int(ceil(balance / principal))
    }

    var totalInterest: Double {
        guard totalPayment > 0, balance > 0 else { return 0 }
        return (totalPayment * Double(monthsToPayoff)) - balance
    }
}

@SlopData
public struct DebtPayoffPlannerData {
    @SlopKit.Section("Overview") @Field("Title") var title: String = "Debt Payoff Planner"
    @Field("Currency", options: ["USD", "EUR", "GBP", "JPY"]) var currency: String = "USD"
    @Field("Strategy", options: ["Snowball", "Avalanche"]) var strategy: String = "Avalanche"
    @SlopKit.Section("Debts") @Field("Debts") var debts: [Debt] = DebtPayoffPlannerData.defaultDebts

    var totalDebt: Double { debts.reduce(0) { $0 + $1.balance } }
    var totalMinimumPayment: Double { debts.reduce(0) { $0 + $1.minimumPayment } }
    var totalExtraPayment: Double { debts.reduce(0) { $0 + $1.extraPayment } }
    var totalPayment: Double { totalMinimumPayment + totalExtraPayment }
    var totalInterest: Double { debts.reduce(0) { $0 + $1.totalInterest } }

    var sortedDebtsSnowball: [Debt] {
        debts.sorted { $0.balance < $1.balance }
    }

    var sortedDebtsAvalanche: [Debt] {
        debts.sorted { $0.interestRate > $1.interestRate }
    }

    var recommendedOrder: [Debt] {
        strategy == "Snowball" ? sortedDebtsSnowball : sortedDebtsAvalanche
    }

    var averagePayoffMonths: Int {
        guard !debts.isEmpty else { return 0 }
        let sum = debts.reduce(0) { $0 + $1.monthsToPayoff }
        return sum / debts.count
    }
}

extension DebtPayoffPlannerData {
    static var defaultDebts: [Debt] {
        func debt(_ name: String, _ balance: Double, _ rate: Double, _ minPay: Double, _ extra: Double) -> Debt {
            var d = Debt()
            d.name = name
            d.balance = balance
            d.interestRate = rate
            d.minimumPayment = minPay
            d.extraPayment = extra
            return d
        }

        return [
            debt("Credit Card", 5000, 18.9, 150, 100),
            debt("Student Loan", 15000, 4.5, 200, 50),
            debt("Car Loan", 8000, 6.5, 250, 0),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.debt-payoff-planner",
    name: "Debt Payoff Planner",
    description: "Track multiple debts with snowball vs. avalanche strategy comparison.",
    version: "1.0.0",
    width: 380, height: 700,
    minWidth: 340, minHeight: 550,
    shape: .roundedRect(radius: 16),
    theme: "terminal",
    alwaysOnTop: false,
    categories: ["finance"]
)
struct DebtPayoffPlannerView: View {
    @TemplateData var data: DebtPayoffPlannerData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                SlopTextField("Title", text: $data.title)
                    .font(theme.title(size: 22))
                    .foregroundStyle(theme.foreground)

                // Strategy selector
                HStack(spacing: 8) {
                    Text("Strategy:")
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                    ForEach(["Snowball", "Avalanche"], id: \.self) { strat in
                        Button(action: { data.strategy = strat }) {
                            Text(strat)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(data.strategy == strat ? theme.accent : theme.surface)
                                .foregroundStyle(data.strategy == strat ? .white : theme.foreground)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Overall metrics
                HStack(spacing: 10) {
                    MetricPill(
                        formatted(data.totalDebt),
                        tint: .red
                    )
                    MetricPill(
                        formatted(data.totalPayment) + "/mo",
                        tint: theme.accent
                    )
                    Spacer()
                }

                Divider().background(theme.divider)

                // Debts list
                if data.debts.isEmpty {
                    EmptyState(
                        icon: "creditcard",
                        title: "No debts tracked",
                        subtitle: "Add a debt to start planning payoff"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach($data.debts) { $debt in
                            VStack(alignment: .leading, spacing: 8) {
                                // Debt header
                                HStack {
                                    SlopTextField("Debt name", text: $debt.name)
                                        .font(theme.font(size: 14, weight: .semibold))
                                        .foregroundStyle(theme.foreground)
                                    Spacer()
                                    RemoveButton {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            data.debts.removeAll { $0.id == debt.id }
                                        }
                                    }
                                }

                                // Progress bar
                                let progress = min(debt.totalPayment / max(debt.balance, 1), 1.0)
                                ProgressBar(
                                    progress: progress,
                                    fillColor: theme.accent,
                                    backgroundColor: theme.surface,
                                    height: 6
                                )

                                // Metrics
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Balance")
                                            .font(theme.font(size: 9))
                                            .foregroundStyle(theme.secondary)
                                        Text(formatted(debt.balance))
                                            .font(theme.font(size: 11, weight: .semibold))
                                            .foregroundStyle(theme.foreground)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("APR")
                                            .font(theme.font(size: 9))
                                            .foregroundStyle(theme.secondary)
                                        Text("\(String(format: "%.1f", debt.interestRate))%")
                                            .font(theme.font(size: 11, weight: .semibold))
                                            .foregroundStyle(.orange)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Payoff")
                                            .font(theme.font(size: 9))
                                            .foregroundStyle(theme.secondary)
                                        Text("\(debt.monthsToPayoff)mo")
                                            .font(theme.font(size: 11, weight: .semibold))
                                            .foregroundStyle(theme.accent)
                                    }
                                    Spacer()
                                }

                                // Editable fields
                                SlopInteractiveOnly {
                                    VStack(spacing: 6) {
                                        HStack {
                                            Text("Balance:")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondary)
                                            Spacer()
                                            CurrencyInput(
                                                currency: data.currency,
                                                value: $debt.balance,
                                                width: 80,
                                                symbolColor: theme.secondary,
                                                valueColor: theme.foreground
                                            )
                                        }
                                        HStack {
                                            Text("Interest Rate (%):")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondary)
                                            Spacer()
                                            SlopNumberField("0", value: $debt.interestRate, format: "%.1f")
                                                .frame(width: 50)
                                                .multilineTextAlignment(.trailing)
                                                .font(.caption)
                                        }
                                        HStack {
                                            Text("Min Payment:")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondary)
                                            Spacer()
                                            CurrencyInput(
                                                currency: data.currency,
                                                value: $debt.minimumPayment,
                                                width: 80,
                                                symbolColor: theme.secondary,
                                                valueColor: theme.foreground
                                            )
                                        }
                                        HStack {
                                            Text("Extra Payment:")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondary)
                                            Spacer()
                                            CurrencyInput(
                                                currency: data.currency,
                                                value: $debt.extraPayment,
                                                width: 80,
                                                symbolColor: theme.secondary,
                                                valueColor: theme.foreground
                                            )
                                        }
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                            .padding(12)
                            .background(theme.surface.opacity(0.3))
                            .cornerRadius(8)
                        }

                        AddItemButton("Add Debt") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.debts.append(Debt())
                            }
                        }
                    }
                }

                Divider().background(theme.divider)

                // Debt comparison chart
                if !data.debts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Debt Comparison")

                        ColumnBarChart(
                            items: data.debts.map { debt in
                                BarChartItem(
                                    name: debt.name,
                                    value: debt.balance,
                                    color: colorForDebt(debt),
                                    formattedValue: formatted(debt.balance)
                                )
                            }
                        )
                    }
                }

                Divider().background(theme.divider)

                // Summary
                SummaryRow(
                    label: "Total Debt",
                    value: formatted(data.totalDebt),
                    valueColor: .red.opacity(0.8),
                    isBold: true
                )

                SummaryRow(
                    label: "Total Payment/mo",
                    value: formatted(data.totalPayment),
                    valueColor: theme.accent
                )

                SummaryRow(
                    label: "Est. Total Interest",
                    value: formatted(data.totalInterest),
                    valueColor: .orange
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

    private func colorForDebt(_ debt: Debt) -> Color {
        let hash = abs(debt.id.hashValue)
        let colors: [Color] = [
            Color(red: 0.9, green: 0.3, blue: 0.5),
            Color(red: 0.9, green: 0.5, blue: 0.3),
            Color(red: 0.9, green: 0.7, blue: 0.3),
            Color(red: 0.5, green: 0.6, blue: 0.9),
        ]
        return colors[hash % colors.count]
    }
}

