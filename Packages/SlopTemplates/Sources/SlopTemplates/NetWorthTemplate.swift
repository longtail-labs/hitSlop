import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct AssetEntry: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Value") var value: Double = 0
    @Field("Category", options: ["Cash", "Investment", "Property", "Other"]) var category: String = "Cash"
}

@SlopData
public struct LiabilityEntry: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Value") var value: Double = 0
    @Field("Category", options: ["Mortgage", "Loan", "Credit", "Other"]) var category: String = "Loan"
}

@SlopData
public struct NetWorthData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Net Worth"
    @Field("Currency", options: ["USD", "EUR", "GBP"]) var currency: String = "USD"

    @SlopKit.Section("Assets")
    @Field("Assets") var assets: [AssetEntry] = defaultAssets

    @SlopKit.Section("Liabilities")
    @Field("Liabilities") var liabilities: [LiabilityEntry] = defaultLiabilities

    var totalAssets: Double {
        assets.reduce(0) { $0 + $1.value }
    }

    var totalLiabilities: Double {
        liabilities.reduce(0) { $0 + $1.value }
    }

    var netWorth: Double {
        totalAssets - totalLiabilities
    }
}

extension NetWorthData {
    static var defaultAssets: [AssetEntry] {
        func asset(_ name: String, _ value: Double, _ category: String) -> AssetEntry {
            var a = AssetEntry()
            a.name = name
            a.value = value
            a.category = category
            return a
        }
        return [
            asset("Checking", 15000, "Cash"),
            asset("401k", 85000, "Investment"),
            asset("Home", 350000, "Property")
        ]
    }

    static var defaultLiabilities: [LiabilityEntry] {
        func liability(_ name: String, _ value: Double, _ category: String) -> LiabilityEntry {
            var l = LiabilityEntry()
            l.name = name
            l.value = value
            l.category = category
            return l
        }
        return [
            liability("Mortgage", 280000, "Mortgage"),
            liability("Student Loan", 25000, "Loan")
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.net-worth",
    name: "Net Worth",
    description: "Track assets and liabilities to see your total net worth at a glance.",
    version: "1.0.0",
    width: 420, height: 600,
    shape: .roundedRect(radius: 16),
    theme: "paper-ledger",
    alwaysOnTop: true,
    categories: ["finance"]
)
struct NetWorthView: View {
    @TemplateData var data: NetWorthData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    private var sign: String {
        currencySymbol(for: data.currency)
    }

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 20) {
                SlopTemplateHeader(
                    titlePlaceholder: "Net worth",
                    title: $data.title
                ) {
                    SlopSurfaceCard(padding: 10) {
                        SlopEnumField(selection: $data.currency, options: ["USD", "EUR", "GBP"])
                    }
                }

                // Hero Net Worth Number
                VStack(alignment: .center, spacing: 4) {
                    Text(sign + String(format: "%.0f", data.netWorth))
                        .font(theme.title(size: 48))
                        .foregroundColor(data.netWorth >= 0 ? theme.accent : Color.red)
                    Text("Net Worth")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                // Visualization Bar
                GeometryReader { geometry in
                    let total = data.totalAssets + data.totalLiabilities
                    let assetWidth = total > 0 ? (data.totalAssets / total) * geometry.size.width : 0
                    let liabilityWidth = total > 0 ? (data.totalLiabilities / total) * geometry.size.width : 0

                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: assetWidth)
                        Rectangle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: liabilityWidth)
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                }
                .frame(height: 8)

                Divider()
                    .background(theme.divider)

                // Assets Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Assets")
                            .font(theme.titleFont.weight(.semibold))
                            .foregroundColor(theme.foreground)
                        Spacer()
                        Text(sign + String(format: "%.0f", data.totalAssets))
                            .font(theme.bodyFont.weight(.medium))
                            .foregroundColor(Color.green)
                    }

                    ForEach(Array(data.assets.enumerated()), id: \.element.id) { index, asset in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                SlopTextField("Asset name", text: Binding(
                                    get: { data.assets[index].name },
                                    set: { data.assets[index].name = $0 }
                                ))
                                .font(theme.bodyFont)
                                .foregroundColor(theme.foreground)

                                SlopEnumField(
                                    selection: Binding(
                                        get: { data.assets[index].category },
                                        set: { data.assets[index].category = $0 }
                                    ),
                                    options: ["Cash", "Investment", "Property", "Other"]
                                )
                                .font(.caption)
                            }

                            Spacer()

                            SlopCurrencyField(
                                currency: data.currency,
                                value: Binding(
                                    get: { data.assets[index].value },
                                    set: { data.assets[index].value = $0 }
                                )
                            )

                            SlopInteractiveOnly {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        data.assets.removeAll { $0.id == asset.id }
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(theme.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    SlopInteractiveOnly {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.assets.append(AssetEntry())
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Asset")
                            }
                            .font(theme.bodyFont)
                            .foregroundColor(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .background(theme.divider)

                // Liabilities Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Liabilities")
                            .font(theme.titleFont.weight(.semibold))
                            .foregroundColor(theme.foreground)
                        Spacer()
                        Text(sign + String(format: "%.0f", data.totalLiabilities))
                            .font(theme.bodyFont.weight(.medium))
                            .foregroundColor(Color.red)
                    }

                    ForEach(Array(data.liabilities.enumerated()), id: \.element.id) { index, liability in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                SlopTextField("Liability name", text: Binding(
                                    get: { data.liabilities[index].name },
                                    set: { data.liabilities[index].name = $0 }
                                ))
                                .font(theme.bodyFont)
                                .foregroundColor(theme.foreground)

                                SlopEnumField(
                                    selection: Binding(
                                        get: { data.liabilities[index].category },
                                        set: { data.liabilities[index].category = $0 }
                                    ),
                                    options: ["Mortgage", "Loan", "Credit", "Other"]
                                )
                                .font(.caption)
                            }

                            Spacer()

                            SlopCurrencyField(
                                currency: data.currency,
                                value: Binding(
                                    get: { data.liabilities[index].value },
                                    set: { data.liabilities[index].value = $0 }
                                )
                            )

                            SlopInteractiveOnly {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        data.liabilities.removeAll { $0.id == liability.id }
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(theme.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    SlopInteractiveOnly {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.liabilities.append(LiabilityEntry())
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Liability")
                            }
                            .font(theme.bodyFont)
                            .foregroundColor(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}
