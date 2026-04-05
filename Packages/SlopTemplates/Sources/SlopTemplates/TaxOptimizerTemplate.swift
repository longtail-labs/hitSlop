import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct DeductibleItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Description") var description: String = ""
    @Field("Amount") var amount: Double = 0
}

@SlopData
public struct TaxCategory: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Color") var color: String = "#4a90d9"
    @Field("Items") var items: [DeductibleItem] = []

    var total: Double { items.reduce(0) { $0 + $1.amount } }
}

@SlopData
public struct TaxOptimizerData {
    @SlopKit.Section("Overview") @Field("Title") var title: String = "Tax Optimizer"
    @Field("Tax Year") var taxYear: String = String(Calendar.current.component(.year, from: Date()))
    @Field("Currency", options: ["USD", "EUR", "GBP", "JPY"]) var currency: String = "USD"
    @Field("Estimated Tax Rate") var estimatedTaxRate: Double = 25.0
    @SlopKit.Section("Deductions") @Field("Categories") var categories: [TaxCategory] = TaxOptimizerData.defaultCategories

    var totalDeductions: Double { categories.reduce(0) { $0 + $1.total } }
    var estimatedSavings: Double { totalDeductions * (estimatedTaxRate / 100) }
}

extension TaxOptimizerData {
    static var defaultCategories: [TaxCategory] {
        func item(_ desc: String, _ amount: Double) -> DeductibleItem {
            var i = DeductibleItem()
            i.description = desc
            i.amount = amount
            return i
        }

        func category(_ name: String, _ color: String, _ items: [DeductibleItem]) -> TaxCategory {
            var c = TaxCategory()
            c.name = name
            c.color = color
            c.items = items
            return c
        }

        return [
            category("Business Expenses", "#4a90d9", [
                item("Office Supplies", 450),
                item("Software Licenses", 600),
            ]),
            category("Home Office", "#50c878", [
                item("Internet", 360),
                item("Utilities", 240),
            ]),
            category("Professional Development", "#f5a623", [
                item("Conferences", 800),
                item("Books & Courses", 300),
            ]),
            category("Charitable Donations", "#e8608a", [
                item("Local Charity", 500),
            ]),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.tax-optimizer",
    name: "Tax Optimizer",
    description: "Track deductible expenses by category and estimate tax savings.",
    version: "1.0.0",
    width: 380, height: 720,
    minWidth: 340, minHeight: 560,
    shape: .roundedRect(radius: 16),
    theme: "terminal",
    alwaysOnTop: false,
    categories: ["finance"]
)
struct TaxOptimizerView: View {
    @TemplateData var data: TaxOptimizerData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    SlopTextField("Title", text: $data.title)
                        .font(theme.title(size: 22))
                        .foregroundStyle(theme.foreground)
                    SlopTextField("Tax Year", text: $data.taxYear)
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                }

                // Key metrics
                HStack(spacing: 10) {
                    MetricPill(
                        formatted(data.totalDeductions),
                        tint: theme.accent
                    )
                    MetricPill(
                        "Save " + formatted(data.estimatedSavings),
                        tint: .green
                    )
                    Spacer()
                }

                // Tax rate input
                HStack {
                    Text("Estimated Tax Rate:")
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    SlopNumberField("25", value: $data.estimatedTaxRate, format: "%.1f")
                        .font(theme.font(size: 13))
                        .frame(width: 40)
                        .multilineTextAlignment(.trailing)
                    Text("%")
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                }

                Divider().background(theme.divider)

                // Category breakdown donut
                if !data.categories.isEmpty && data.totalDeductions > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Category Allocation")

                        HStack {
                            Spacer()
                            DonutChart(
                                segments: data.categories.map { cat in
                                    DonutSegment(
                                        color: colorFromHex(cat.color),
                                        fraction: data.totalDeductions > 0 ? cat.total / data.totalDeductions : 0,
                                        label: cat.name
                                    )
                                },
                                centerLabel: formatted(data.totalDeductions),
                                size: 120,
                                lineWidth: 18,
                                backgroundColor: theme.surface
                            )
                            Spacer()
                        }
                    }

                    Divider().background(theme.divider)
                }

                // Category breakdown chart
                if !data.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Category Breakdown")

                        ColumnBarChart(
                            items: data.categories.map { cat in
                                BarChartItem(
                                    name: cat.name,
                                    value: cat.total,
                                    color: colorFromHex(cat.color),
                                    formattedValue: formatted(cat.total)
                                )
                            }
                        )
                    }

                    Divider().background(theme.divider)
                }

                // Categories and items
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach($data.categories) { $category in
                            VStack(alignment: .leading, spacing: 8) {
                                // Category header
                                HStack {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(colorFromHex(category.color))
                                        .frame(width: 4, height: 16)
                                    SlopTextField("Category", text: $category.name)
                                        .font(theme.font(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.foreground)
                                    Spacer()
                                    Text(formatted(category.total))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(theme.accent)
                                    RemoveButton {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            data.categories.removeAll { $0.id == category.id }
                                        }
                                    }
                                }

                                SlopInteractiveOnly {
                                    SlopColorField(hex: $category.color)
                                }

                                // Items in category
                                ForEach($category.items) { $item in
                                    HStack(spacing: 8) {
                                        SlopTextField("Description", text: $item.description)
                                            .font(theme.font(size: 12))
                                            .foregroundStyle(theme.foreground.opacity(0.8))
                                        Spacer()
                                        CurrencyInput(
                                            currency: data.currency,
                                            value: $item.amount,
                                            width: 70,
                                            symbolColor: theme.secondary,
                                            valueColor: theme.foreground
                                        )
                                        RemoveButton {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                $category.wrappedValue.items.removeAll {
                                                    $0.id == item.id
                                                }
                                            }
                                        }
                                    }
                                    .padding(.leading, 8)
                                }

                                AddItemButton("Add Item") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        $category.wrappedValue.items.append(DeductibleItem())
                                    }
                                }
                            }
                            .padding(10)
                            .background(theme.surface.opacity(0.3))
                            .cornerRadius(8)
                        }

                        AddItemButton("Add Category") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                var cat = TaxCategory()
                                cat.name = "New Category"
                                data.categories.append(cat)
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)

                Divider().background(theme.divider)

                // Summary
                SummaryRow(
                    label: "Total Deductions",
                    value: formatted(data.totalDeductions),
                    valueColor: theme.accent,
                    isBold: true
                )

                SummaryRow(
                    label: "Tax Rate",
                    value: "\(String(format: "%.1f", data.estimatedTaxRate))%",
                    valueColor: theme.secondary
                )

                SummaryRow(
                    label: "Estimated Savings",
                    value: formatted(data.estimatedSavings),
                    valueColor: .green,
                    isBold: true
                )
                .font(.title3)
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

