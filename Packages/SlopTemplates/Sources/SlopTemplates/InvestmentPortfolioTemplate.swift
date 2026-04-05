import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct Holding: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Symbol") var symbol: String = ""
    @Field("Shares") var shares: Double = 0
    @Field("Cost Basis") var costBasis: Double = 0
    @Field("Current Price") var currentPrice: Double = 0

    var costTotal: Double { shares * costBasis }
    var currentValue: Double { shares * currentPrice }
    var gainLoss: Double { currentValue - costTotal }
    var gainLossPct: Double {
        guard costTotal > 0 else { return 0 }
        return (gainLoss / costTotal) * 100
    }
}

@SlopData
public struct InvestmentPortfolioData {
    @SlopKit.Section("Overview") @Field("Portfolio Name") var title: String = "Investment Portfolio"
    @Field("Account Type") var accountType: String = "Brokerage"
    @Field("Currency", options: ["USD", "EUR", "GBP", "JPY"]) var currency: String = "USD"
    @SlopKit.Section("Holdings") @Field("Holdings") var holdings: [Holding] = InvestmentPortfolioData.defaultHoldings

    var totalCost: Double { holdings.reduce(0) { $0 + $1.costTotal } }
    var totalValue: Double { holdings.reduce(0) { $0 + $1.currentValue } }
    var totalGainLoss: Double { totalValue - totalCost }
    var totalGainLossPct: Double {
        guard totalCost > 0 else { return 0 }
        return (totalGainLoss / totalCost) * 100
    }
}

extension InvestmentPortfolioData {
    static var defaultHoldings: [Holding] {
        func holding(_ symbol: String, _ shares: Double, _ costBasis: Double, _ currentPrice: Double) -> Holding {
            var h = Holding()
            h.symbol = symbol
            h.shares = shares
            h.costBasis = costBasis
            h.currentPrice = currentPrice
            return h
        }

        return [
            holding("AAPL", 10, 150.00, 175.00),
            holding("GOOGL", 5, 2800.00, 3100.00),
            holding("MSFT", 8, 280.00, 320.00),
            holding("TSLA", 3, 220.00, 240.00),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.investment-portfolio",
    name: "Investment Portfolio",
    description: "Track stocks, crypto, and other investments with gain/loss calculations.",
    version: "1.0.0",
    width: 380, height: 640,
    minWidth: 340, minHeight: 500,
    shape: .roundedRect(radius: 16),
    theme: "terminal",
    alwaysOnTop: false,
    categories: ["finance"]
)
struct InvestmentPortfolioView: View {
    @TemplateData var data: InvestmentPortfolioData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    SlopTextField("Portfolio Name", text: $data.title)
                        .font(theme.title(size: 22))
                        .foregroundStyle(theme.foreground)
                    SlopTextField("Account Type", text: $data.accountType)
                        .font(theme.font(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                }

                // Overall metrics
                HStack(spacing: 12) {
                    MetricPill(
                        formatted(data.totalValue),
                        tint: theme.accent
                    )
                    MetricPill(
                        gainLossText(data.totalGainLoss, data.totalGainLossPct),
                        tint: data.totalGainLoss >= 0 ? .green : .red
                    )
                    Spacer()
                }

                Divider().background(theme.divider)

                // Holdings list
                if data.holdings.isEmpty {
                    EmptyState(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No holdings yet",
                        subtitle: "Add a stock or asset to start tracking"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        // Header
                        HStack {
                            Text("Symbol")
                                .frame(width: 60, alignment: .leading)
                            Text("Shares")
                                .frame(width: 50, alignment: .trailing)
                            Text("Value")
                                .frame(width: 70, alignment: .trailing)
                            Text("Gain/Loss")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(theme.mono(size: 10, weight: .bold))
                        .foregroundStyle(theme.secondary)

                        ForEach($data.holdings) { $holding in
                            HStack(spacing: 8) {
                                SlopTextField("SYMB", text: $holding.symbol)
                                    .font(theme.mono(size: 13, weight: .bold))
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 60, alignment: .leading)

                                SlopNumberField("0", value: $holding.shares, format: "%.2f")
                                    .font(theme.font(size: 12))
                                    .foregroundStyle(theme.foreground.opacity(0.8))
                                    .frame(width: 50, alignment: .trailing)

                                Text(formatted(holding.currentValue))
                                    .font(theme.font(size: 12, weight: .semibold))
                                    .foregroundStyle(theme.foreground)
                                    .frame(width: 70, alignment: .trailing)

                                Text(gainLossText(holding.gainLoss, holding.gainLossPct))
                                    .font(theme.mono(size: 11, weight: .medium))
                                    .foregroundStyle(holding.gainLoss >= 0 ? .green : .red)
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                RemoveButton {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        data.holdings.removeAll { $0.id == holding.id }
                                    }
                                }
                            }
                            .padding(.vertical, 2)

                            // Expandable details
                            SlopInteractiveOnly {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Cost Basis:")
                                            .font(.caption2)
                                            .foregroundStyle(theme.secondary)
                                        Spacer()
                                        CurrencyInput(
                                            currency: data.currency,
                                            value: $holding.costBasis,
                                            width: 60,
                                            symbolColor: theme.secondary,
                                            valueColor: theme.secondary
                                        )
                                        .font(.caption)
                                    }
                                    HStack {
                                        Text("Current Price:")
                                            .font(.caption2)
                                            .foregroundStyle(theme.secondary)
                                        Spacer()
                                        CurrencyInput(
                                            currency: data.currency,
                                            value: $holding.currentPrice,
                                            width: 60,
                                            symbolColor: theme.secondary,
                                            valueColor: theme.secondary
                                        )
                                        .font(.caption)
                                    }
                                }
                                .padding(.leading, 16)
                                .padding(.top, 4)
                            }
                        }

                        AddItemButton("Add Holding") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.holdings.append(Holding())
                            }
                        }
                    }
                }

                Divider().background(theme.divider)

                // Allocation donut chart
                if !data.holdings.isEmpty && data.totalValue > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Portfolio Allocation")

                        HStack {
                            Spacer()
                            DonutChart(
                                segments: data.holdings.map { holding in
                                    DonutSegment(
                                        color: colorForSymbol(holding.symbol),
                                        fraction: holding.currentValue / data.totalValue,
                                        label: holding.symbol
                                    )
                                },
                                centerLabel: "\(data.holdings.count)\nHoldings",
                                size: 120,
                                lineWidth: 18,
                                backgroundColor: theme.surface
                            )
                            Spacer()
                        }

                        ColumnBarChart(
                            items: data.holdings.map { holding in
                                BarChartItem(
                                    name: holding.symbol,
                                    value: holding.currentValue,
                                    color: colorForSymbol(holding.symbol),
                                    formattedValue: formatted(holding.currentValue)
                                )
                            }
                        )
                    }
                }

                Divider().background(theme.divider)

                // Summary
                SummaryRow(
                    label: "Total Cost",
                    value: formatted(data.totalCost),
                    valueColor: theme.secondary
                )

                SummaryRow(
                    label: "Current Value",
                    value: formatted(data.totalValue),
                    valueColor: theme.accent,
                    isBold: true
                )

                SummaryRow(
                    label: "Total Gain/Loss",
                    value: gainLossText(data.totalGainLoss, data.totalGainLossPct),
                    valueColor: data.totalGainLoss >= 0 ? .green : .red,
                    isBold: true
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

    private func gainLossText(_ amount: Double, _ pct: Double) -> String {
        let sign = amount >= 0 ? "+" : ""
        return "\(sign)\(formatted(amount)) (\(sign)\(String(format: "%.1f", pct))%)"
    }

    private func colorForSymbol(_ symbol: String) -> Color {
        // Simple hash-based color assignment
        let colors: [Color] = [
            Color(red: 0.9, green: 0.3, blue: 0.5),
            Color(red: 0.3, green: 0.6, blue: 0.9),
            Color(red: 0.5, green: 0.8, blue: 0.3),
            Color(red: 0.9, green: 0.7, blue: 0.2),
            Color(red: 0.7, green: 0.4, blue: 0.9),
            Color(red: 0.3, green: 0.8, blue: 0.8),
        ]
        let hash = abs(symbol.hashValue)
        return colors[hash % colors.count]
    }
}

