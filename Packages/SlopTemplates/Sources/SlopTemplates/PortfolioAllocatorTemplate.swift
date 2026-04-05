import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct PortfolioAllocation: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Ticker") var ticker: String = ""
    @Field("Target Allocation") var targetAllocation: Double = 0
    @Field("Current Allocation") var currentAllocation: Double = 0
}

@SlopData
public struct PortfolioAllocatorData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Portfolio Allocator"
    @Field("As Of", editor: .date) var asOf: Date = .now
    @Field("Currency", options: ["USD", "EUR", "GBP"]) var currency: String = "USD"
    @Field("Total Investable Value", editor: .currency(codeField: "currency")) var totalValue: Double = 250000

    @SlopKit.Section("Allocations")
    @Field("Allocations") var allocations: [PortfolioAllocation] = [
        Self.makeAllocation("US Equities", "VTI", 45, 42),
        Self.makeAllocation("International", "VXUS", 20, 18),
        Self.makeAllocation("Bonds", "BND", 20, 25),
        Self.makeAllocation("Cash", "USD", 5, 7),
        Self.makeAllocation("Alternative", "GLDM", 10, 8),
    ]

    var maxDrift: Double {
        allocations.map { abs($0.currentAllocation - $0.targetAllocation) }.max() ?? 0
    }

    var investedValue: Double {
        totalValue * allocations.reduce(0) { $0 + $1.currentAllocation } / 100
    }

    private static func makeAllocation(_ name: String, _ ticker: String, _ target: Double, _ current: Double) -> PortfolioAllocation {
        var allocation = PortfolioAllocation()
        allocation.name = name
        allocation.ticker = ticker
        allocation.targetAllocation = target
        allocation.currentAllocation = current
        return allocation
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.portfolio-allocator",
    name: "Portfolio Allocator",
    description: "Compare target and actual portfolio weights, then rebalance from one view.",
    version: "1.0.0",
    width: 430, height: 620,
    minWidth: 360, minHeight: 520,
    shape: .roundedRect(radius: 18),
    theme: "signal-grid",
    alwaysOnTop: false,
    categories: ["finance"]
)
struct PortfolioAllocatorView: View {
    @TemplateData var data: PortfolioAllocatorData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(titlePlaceholder: "Portfolio allocator", title: $data.title) {
                    SlopSurfaceCard(padding: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            SlopDateField($data.asOf)
                            SlopEnumField(selection: $data.currency, options: ["USD", "EUR", "GBP"])
                                .font(.caption)
                        }
                    }
                }

                SlopSurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Investable Value")
                            .font(.caption)
                            .foregroundStyle(theme.secondary)

                        SlopCurrencyField(currency: data.currency, value: $data.totalValue, width: 120)
                            .font(theme.title(size: 28))

                        HStack(spacing: 10) {
                            MetricPill("max drift \(String(format: "%.1f", data.maxDrift))%", tint: theme.accent)
                            MetricPill("invested \(currencySymbol(for: data.currency))\(Int(data.investedValue))", tint: theme.secondary)
                        }
                    }
                }

                SlopRecordListSection(
                    title: "Allocations",
                    isEmpty: data.allocations.isEmpty,
                    addLabel: "Add Allocation",
                    onAdd: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.allocations.append(PortfolioAllocation())
                        }
                    },
                    emptyState: {
                        EmptyState(icon: "chart.pie", title: "No allocations yet", subtitle: "Add your first sleeve to map the portfolio.")
                    },
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach($data.allocations) { $allocation in
                                SlopSurfaceCard(padding: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                SlopTextField("Allocation name", text: $allocation.name)
                                                    .font(theme.font(size: 14, weight: .semibold))
                                                    .foregroundStyle(theme.foreground)

                                                SlopTextField("Ticker", text: $allocation.ticker)
                                                    .font(theme.monoFont)
                                                    .foregroundStyle(theme.secondary)
                                            }

                                            Spacer()

                                            RemoveButton {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    data.allocations.removeAll { $0.id == allocation.id }
                                                }
                                            }
                                        }

                                        HStack(spacing: 18) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Target")
                                                    .font(.caption2)
                                                    .foregroundStyle(theme.secondary)
                                                SlopNumberField("0", value: $allocation.targetAllocation, format: "%.1f")
                                                    .font(theme.font(size: 16, weight: .bold))
                                                    .foregroundStyle(theme.accent)
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Current")
                                                    .font(.caption2)
                                                    .foregroundStyle(theme.secondary)
                                                SlopNumberField("0", value: $allocation.currentAllocation, format: "%.1f")
                                                    .font(theme.font(size: 16, weight: .bold))
                                                    .foregroundStyle(theme.foreground)
                                            }
                                        }

                                        ProgressBar(
                                            progress: max(0, min(allocation.currentAllocation / max(allocation.targetAllocation, 1), 1)),
                                            fillColor: abs(allocation.currentAllocation - allocation.targetAllocation) <= 2 ? theme.accent : .orange,
                                            backgroundColor: theme.surface,
                                            height: 8
                                        )
                                    }
                                }
                            }
                        }
                    }
                )
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

