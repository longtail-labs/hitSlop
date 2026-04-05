import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct IncomeSource: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Amount") var amount: Double = 0
}

@SlopData
public struct HustleExpense: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Amount") var amount: Double = 0
}

@SlopData
public struct SideHustleTrackerData {
    @SlopKit.Section("Overview") @Field("Title") var title: String = "Side Hustle Tracker"
    @Field("Month") var month: String = "April 2026"
    @Field("Currency", options: ["USD", "EUR", "GBP", "JPY"]) var currency: String = "USD"
    @SlopKit.Section("Income & Expenses") @Field("Income Sources") var incomeSources: [IncomeSource] = SideHustleTrackerData.defaultIncomeSources
    @Field("Expenses") var expenses: [HustleExpense] = SideHustleTrackerData.defaultExpenses

    var totalIncome: Double { incomeSources.reduce(0) { $0 + $1.amount } }
    var totalExpenses: Double { expenses.reduce(0) { $0 + $1.amount } }
    var netProfit: Double { totalIncome - totalExpenses }
    var profitMargin: Double {
        guard totalIncome > 0 else { return 0 }
        return (netProfit / totalIncome) * 100
    }
}

extension SideHustleTrackerData {
    static func currentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    static var defaultIncomeSources: [IncomeSource] {
        func source(_ name: String, _ amount: Double) -> IncomeSource {
            var s = IncomeSource()
            s.name = name
            s.amount = amount
            return s
        }
        return [
            source("Freelance Design", 1200),
            source("Online Course Sales", 450),
            source("Consulting", 800),
        ]
    }

    static var defaultExpenses: [HustleExpense] {
        func expense(_ name: String, _ amount: Double) -> HustleExpense {
            var e = HustleExpense()
            e.name = name
            e.amount = amount
            return e
        }
        return [
            expense("Software Subscriptions", 120),
            expense("Marketing", 200),
            expense("Domain & Hosting", 50),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.side-hustle-tracker",
    name: "Side Hustle Tracker",
    description: "Track multiple income streams and expenses with profit analysis.",
    version: "1.0.0",
    width: 380, height: 680,
    minWidth: 340, minHeight: 520,
    shape: .roundedRect(radius: 16),
    theme: "terminal",
    alwaysOnTop: false,
    categories: ["finance"]
)
struct SideHustleTrackerView: View {
    @TemplateData var data: SideHustleTrackerData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    SlopTextField("Title", text: $data.title)
                        .font(theme.title(size: 22))
                        .foregroundStyle(theme.foreground)
                    SlopTextField("Month", text: $data.month)
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                }

                // Key metrics
                HStack(spacing: 10) {
                    MetricPill(
                        formatted(data.netProfit),
                        tint: data.netProfit >= 0 ? .green : .red
                    )
                    MetricPill(
                        "\(String(format: "%.1f", data.profitMargin))%",
                        tint: theme.accent
                    )
                    Spacer()
                }

                Divider().background(theme.divider)

                // Income breakdown donut
                if !data.incomeSources.isEmpty && data.totalIncome > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Income Breakdown")

                        HStack {
                            Spacer()
                            DonutChart(
                                segments: data.incomeSources.map { source in
                                    DonutSegment(
                                        color: colorForIncomeSource(source),
                                        fraction: source.amount / data.totalIncome,
                                        label: source.name
                                    )
                                },
                                centerLabel: formatted(data.totalIncome),
                                size: 120,
                                lineWidth: 18,
                                backgroundColor: theme.surface
                            )
                            Spacer()
                        }
                    }

                    Divider().background(theme.divider)
                }

                // Income vs Expenses chart
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Income vs Expenses")

                    ColumnBarChart(
                        items: [
                            BarChartItem(
                                name: "Income",
                                value: data.totalIncome,
                                color: .green,
                                formattedValue: formatted(data.totalIncome)
                            ),
                            BarChartItem(
                                name: "Expenses",
                                value: data.totalExpenses,
                                color: .red,
                                formattedValue: formatted(data.totalExpenses)
                            ),
                        ]
                    )
                }

                Divider().background(theme.divider)

                // Income sources
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Income Sources")

                    if data.incomeSources.isEmpty {
                        EmptyState(
                            icon: "dollarsign.circle",
                            title: "No income sources",
                            subtitle: "Add your first income stream"
                        )
                    } else {
                        ForEach($data.incomeSources) { $source in
                            HStack(spacing: 8) {
                                SlopTextField("Source", text: $source.name)
                                    .font(theme.font(size: 13))
                                    .foregroundStyle(theme.foreground)
                                Spacer()
                                CurrencyInput(
                                    currency: data.currency,
                                    value: $source.amount,
                                    width: 80,
                                    symbolColor: .green,
                                    valueColor: .green
                                )
                                RemoveButton {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        data.incomeSources.removeAll { $0.id == source.id }
                                    }
                                }
                            }
                        }

                        AddItemButton("Add Income Source") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.incomeSources.append(IncomeSource())
                            }
                        }
                    }
                }

                Divider().background(theme.divider)

                // Expenses
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Expenses")

                    if data.expenses.isEmpty {
                        EmptyState(
                            icon: "cart",
                            title: "No expenses",
                            subtitle: "Track your business costs"
                        )
                    } else {
                        ForEach($data.expenses) { $expense in
                            HStack(spacing: 8) {
                                SlopTextField("Expense", text: $expense.name)
                                    .font(theme.font(size: 13))
                                    .foregroundStyle(theme.foreground)
                                Spacer()
                                CurrencyInput(
                                    currency: data.currency,
                                    value: $expense.amount,
                                    width: 80,
                                    symbolColor: .red,
                                    valueColor: .red
                                )
                                RemoveButton {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        data.expenses.removeAll { $0.id == expense.id }
                                    }
                                }
                            }
                        }

                        AddItemButton("Add Expense") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.expenses.append(HustleExpense())
                            }
                        }
                    }
                }

                Divider().background(theme.divider)

                // Summary
                SummaryRow(
                    label: "Total Income",
                    value: formatted(data.totalIncome),
                    valueColor: .green
                )

                SummaryRow(
                    label: "Total Expenses",
                    value: formatted(data.totalExpenses),
                    valueColor: .red
                )

                SummaryRow(
                    label: "Net Profit",
                    value: formatted(data.netProfit),
                    valueColor: data.netProfit >= 0 ? theme.accent : .red,
                    isBold: true
                )

                SummaryRow(
                    label: "Profit Margin",
                    value: "\(String(format: "%.1f", data.profitMargin))%",
                    valueColor: theme.secondary
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

    private func colorForIncomeSource(_ source: IncomeSource) -> Color {
        let hash = abs(source.id.hashValue)
        let colors: [Color] = [
            Color(red: 0.3, green: 0.8, blue: 0.5),
            Color(red: 0.3, green: 0.6, blue: 0.9),
            Color(red: 0.9, green: 0.7, blue: 0.3),
            Color(red: 0.7, green: 0.4, blue: 0.9),
            Color(red: 0.9, green: 0.5, blue: 0.4),
        ]
        return colors[hash % colors.count]
    }
}

