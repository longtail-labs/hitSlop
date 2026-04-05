import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct EstateBeneficiary: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Relationship") var relationship: String = ""
    @Field("Share Percentage") var sharePercentage: Double = 0
    @Field("Specific Bequests") var specificBequests: String = ""
}

@SlopData
public struct EstateAsset: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Category", options: ["Real Estate", "Financial", "Vehicle", "Personal Property", "Business", "Other"]) var category: String = "Other"
    @Field("Estimated Value") var estimatedValue: Double = 0
    @Field("Assigned To") var assignedTo: String = ""
}

@SlopData
public struct EstateWitness: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Address") var address: String = ""
}

@SlopData
public struct EstateWillData {
    @SlopKit.Section("Overview")
    @Field("Document Title") var title: String = "Last Will and Testament"
    @Field("Status", options: ["Draft", "Under Review", "Finalized"]) var status: String = "Draft"
    @Field("Date Created") var dateCreated: Date = .now
    @Field("Last Updated") var lastUpdated: Date = .now

    @SlopKit.Section("Testator")
    @Field("Testator Name") var testatorName: String = "John Smith"
    @Field("Testator Address") var testatorAddress: String = "123 Elm Street, Springfield, IL 62701"
    @Field("Date of Birth") var dateOfBirth: Date = Calendar.current.date(from: DateComponents(year: 1975, month: 6, day: 15)) ?? .now

    @SlopKit.Section("Executor")
    @Field("Executor Name") var executorName: String = "Sarah Smith"
    @Field("Executor Contact") var executorContact: String = "sarah@email.com"
    @Field("Alternate Executor") var alternateExecutor: String = ""

    @SlopKit.Section("Beneficiaries")
    @Field("Beneficiaries") var beneficiaries: [EstateBeneficiary] = EstateWillData.defaultBeneficiaries

    @SlopKit.Section("Assets")
    @Field("Assets") var assets: [EstateAsset] = EstateWillData.defaultAssets

    @SlopKit.Section("Wishes")
    @Field("Guardian for Minors") var guardianForMinors: String = ""
    @Field("Funeral Wishes", editor: .multiLine) var funeralWishes: String = ""
    @Field("Charitable Donations") var charitableDonations: String = ""
    @Field("Personal Message", editor: .multiLine) var personalMessage: String = ""

    @SlopKit.Section("Witnesses")
    @Field("Witnesses") var witnesses: [EstateWitness] = []

    var totalEstateValue: Double { assets.reduce(0) { $0 + $1.estimatedValue } }
    var totalShareAllocated: Double { beneficiaries.reduce(0) { $0 + $1.sharePercentage } }
    var unallocatedPercentage: Double { max(0, 100 - totalShareAllocated) }
}

extension EstateWillData {
    static var defaultBeneficiaries: [EstateBeneficiary] {
        func beneficiary(_ name: String, _ relationship: String, _ share: Double, _ bequests: String = "") -> EstateBeneficiary {
            var b = EstateBeneficiary()
            b.name = name
            b.relationship = relationship
            b.sharePercentage = share
            b.specificBequests = bequests
            return b
        }
        return [
            beneficiary("Sarah Smith", "Spouse", 50),
            beneficiary("James Smith", "Son", 25, "Family home"),
            beneficiary("Emily Smith", "Daughter", 25),
        ]
    }

    static var defaultAssets: [EstateAsset] {
        func asset(_ name: String, _ category: String, _ value: Double, _ assignedTo: String = "") -> EstateAsset {
            var a = EstateAsset()
            a.name = name
            a.category = category
            a.estimatedValue = value
            a.assignedTo = assignedTo
            return a
        }
        return [
            asset("Family Home", "Real Estate", 450000, "James Smith"),
            asset("Investment Portfolio", "Financial", 200000),
            asset("Savings Account", "Financial", 75000),
            asset("2023 SUV", "Vehicle", 35000),
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.estate-will",
    name: "Estate Will",
    description: "Draft a will with beneficiaries, assets, executor details, and final wishes.",
    version: "1.0.0",
    width: 440, height: 660,
    minWidth: 380, minHeight: 480,
    shape: .roundedRect(radius: 20),
    theme: "paper-ledger",
    alwaysOnTop: true,
    categories: ["legal"]
)
struct EstateWillView: View {
    @TemplateData var data: EstateWillData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    private var assetsByCategory: [(category: String, total: Double)] {
        let categories = Set(data.assets.map(\.category))
        return categories.sorted().compactMap { cat in
            let total = data.assets.filter { $0.category == cat }.reduce(0) { $0 + $1.estimatedValue }
            return total > 0 ? (category: cat, total: total) : nil
        }
    }

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        SlopTextField("Title", text: $data.title)
                            .font(theme.title(size: 20))
                            .foregroundStyle(theme.foreground)
                    }
                    Spacer()
                    if renderTarget == .interactive {
                        Picker("Status", selection: $data.status) {
                            Text("Draft").tag("Draft")
                            Text("Under Review").tag("Under Review")
                            Text("Finalized").tag("Finalized")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    } else {
                        StatusBadge(data.status)
                    }
                }

                ThemeDivider()

                // Testator
                SectionHeader("Testator")
                VStack(alignment: .leading, spacing: 6) {
                    SlopTextField("Full Name", text: $data.testatorName)
                        .font(theme.font(size: 14, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                    SlopTextField("Address", text: $data.testatorAddress)
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                    HStack(spacing: 4) {
                        Text("DOB:")
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                        SlopEditable($data.dateOfBirth) { value in
                            Text(value, style: .date)
                                .font(theme.font(size: 11))
                                .foregroundStyle(theme.foreground)
                        } editor: { $value in
                            DatePicker("", selection: $value, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }
                .padding(12)
                .background(theme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Executor
                SectionHeader("Executor")
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRIMARY")
                            .font(theme.mono(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Name", text: $data.executorName)
                            .font(theme.font(size: 13, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                        SlopTextField("Contact", text: $data.executorContact)
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ALTERNATE")
                            .font(theme.mono(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Name", text: $data.alternateExecutor)
                            .font(theme.font(size: 13, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                ThemeDivider()

                // Beneficiaries
                SectionHeader("Beneficiaries")

                if data.totalShareAllocated != 100 && !data.beneficiaries.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: data.totalShareAllocated > 100 ? "exclamationmark.triangle.fill" : "info.circle")
                            .font(theme.font(size: 11))
                            .foregroundStyle(data.totalShareAllocated > 100 ? .red : .orange)
                        Text(data.totalShareAllocated > 100
                             ? "Total exceeds 100% (\(String(format: "%.0f%%", data.totalShareAllocated)))"
                             : "\(String(format: "%.0f%%", data.unallocatedPercentage)) unallocated")
                            .font(theme.font(size: 11))
                            .foregroundStyle(data.totalShareAllocated > 100 ? .red : .orange)
                    }
                }

                ForEach($data.beneficiaries) { $beneficiary in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            SlopTextField("Name", text: $beneficiary.name)
                                .font(theme.font(size: 13, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                            SlopTextField("Relationship", text: $beneficiary.relationship)
                                .font(theme.font(size: 11))
                                .foregroundStyle(theme.secondary)
                            if !beneficiary.specificBequests.isEmpty || renderTarget == .interactive {
                                SlopTextField("Specific bequests", text: $beneficiary.specificBequests)
                                    .font(theme.font(size: 11))
                                    .foregroundStyle(theme.secondary.opacity(0.8))
                            }
                        }

                        Spacer()

                        HStack(spacing: 2) {
                            SlopNumberField("0", value: $beneficiary.sharePercentage, format: "%.0f")
                                .font(theme.font(size: 16, weight: .bold))
                                .foregroundStyle(theme.accent)
                                .frame(width: 36)
                                .multilineTextAlignment(.trailing)
                            Text("%")
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.secondary)
                        }

                        SlopInteractiveOnly {
                            RemoveButton {
                                withAnimation { data.beneficiaries.removeAll { $0.id == beneficiary.id } }
                            }
                        }
                    }
                    .padding(10)
                    .background(theme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Beneficiary") {
                        withAnimation { data.beneficiaries.append(EstateBeneficiary()) }
                    }
                }

                ThemeDivider()

                // Assets
                SectionHeader("Assets")

                SummaryRow(label: "Total Estate Value", value: "$\(String(format: "%.0f", data.totalEstateValue))", valueColor: theme.accent, isBold: true)

                // Category breakdown chart
                if !assetsByCategory.isEmpty && data.totalEstateValue > 0 {
                    DonutChart(
                        segments: assetsByCategory.map { seg in
                            DonutSegment(
                                color: categoryColor(seg.category),
                                fraction: seg.total / data.totalEstateValue,
                                label: seg.category
                            )
                        },
                        backgroundColor: theme.surface
                    )
                    .frame(height: 120)
                }

                ForEach($data.assets) { $asset in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(categoryColor(asset.category))
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            SlopTextField("Asset", text: $asset.name)
                                .font(theme.font(size: 12, weight: .medium))
                                .foregroundStyle(theme.foreground)
                            HStack(spacing: 8) {
                                if renderTarget == .interactive {
                                    Picker("", selection: $asset.category) {
                                        Text("Real Estate").tag("Real Estate")
                                        Text("Financial").tag("Financial")
                                        Text("Vehicle").tag("Vehicle")
                                        Text("Personal Property").tag("Personal Property")
                                        Text("Business").tag("Business")
                                        Text("Other").tag("Other")
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .controlSize(.mini)
                                } else {
                                    Text(asset.category)
                                        .font(theme.font(size: 10))
                                        .foregroundStyle(theme.secondary)
                                }
                                if !asset.assignedTo.isEmpty {
                                    Text("→ \(asset.assignedTo)")
                                        .font(theme.font(size: 10))
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }

                        Spacer()

                        HStack(spacing: 2) {
                            Text("$")
                                .font(theme.font(size: 11))
                                .foregroundStyle(theme.secondary)
                            SlopNumberField("0", value: $asset.estimatedValue, format: "%.0f")
                                .font(theme.font(size: 12, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }

                        SlopInteractiveOnly {
                            RemoveButton {
                                withAnimation { data.assets.removeAll { $0.id == asset.id } }
                            }
                        }
                    }
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Asset") {
                        withAnimation { data.assets.append(EstateAsset()) }
                    }
                }

                ThemeDivider()

                // Wishes
                SectionHeader("Wishes & Directives")

                if !data.guardianForMinors.isEmpty || renderTarget == .interactive {
                    HStack(spacing: 4) {
                        Text("Guardian for minors:")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Name", text: $data.guardianForMinors)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)
                    }
                }

                if !data.charitableDonations.isEmpty || renderTarget == .interactive {
                    HStack(spacing: 4) {
                        Text("Charitable donations:")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Organization", text: $data.charitableDonations)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)
                    }
                }

                if !data.funeralWishes.isEmpty || renderTarget == .interactive {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Funeral wishes")
                            .font(theme.font(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondary)
                        SlopEditable($data.funeralWishes) { value in
                            Text(value)
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                        } editor: { $value in
                            TextEditor(text: $value)
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.foreground)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 40)
                        }
                    }
                }

                if !data.personalMessage.isEmpty || renderTarget == .interactive {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Personal message")
                            .font(theme.font(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondary)
                        SlopEditable($data.personalMessage) { value in
                            Text(value)
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                        } editor: { $value in
                            TextEditor(text: $value)
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.foreground)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 40)
                        }
                    }
                }

                // Witnesses
                if !data.witnesses.isEmpty || renderTarget == .interactive {
                    ThemeDivider()
                    SectionHeader("Witnesses")

                    if data.witnesses.isEmpty {
                        EmptyState(icon: "person.2", title: "No witnesses added", subtitle: "Add at least two witnesses")
                    }

                    ForEach($data.witnesses) { $witness in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                SlopTextField("Name", text: $witness.name)
                                    .font(theme.font(size: 12, weight: .medium))
                                    .foregroundStyle(theme.foreground)
                                SlopTextField("Address", text: $witness.address)
                                    .font(theme.font(size: 11))
                                    .foregroundStyle(theme.secondary)
                            }
                            Spacer()
                            SlopInteractiveOnly {
                                RemoveButton {
                                    withAnimation { data.witnesses.removeAll { $0.id == witness.id } }
                                }
                            }
                        }
                    }

                    SlopInteractiveOnly {
                        AddItemButton("Add Witness") {
                            withAnimation { data.witnesses.append(EstateWitness()) }
                        }
                    }
                }
            }
            .padding(26)
        }
        .background(theme.background)
    }

    // MARK: - Helpers

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "Real Estate": return Color(red: 0.3, green: 0.6, blue: 0.9)
        case "Financial": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "Vehicle": return Color(red: 0.9, green: 0.6, blue: 0.3)
        case "Personal Property": return Color(red: 0.7, green: 0.5, blue: 0.8)
        case "Business": return Color(red: 0.9, green: 0.4, blue: 0.4)
        default: return Color(red: 0.6, green: 0.6, blue: 0.6)
        }
    }
}

