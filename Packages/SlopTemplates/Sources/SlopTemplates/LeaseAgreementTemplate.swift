import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct LeaseCondition: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Condition") var condition: String = ""
    @Field("Acknowledged") var acknowledged: Bool = false
}

@SlopData
public struct LeaseAgreementData {
    @SlopKit.Section("Overview")
    @Field("Document Title") var title: String = "Lease Agreement"
    @Field("Status", options: ["Draft", "Active", "Expired", "Terminated"]) var status: String = "Draft"
    @Field("Lease Type", options: ["Fixed", "Month-to-Month"]) var leaseType: String = "Fixed"
    @Field("Start Date") var startDate: Date = .now
    @Field("End Date") var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now

    @SlopKit.Section("Property")
    @Field("Property Address") var propertyAddress: String = "100 Main Street, Apt 4B"
    @Field("City") var propertyCity: String = "New York, NY 10001"
    @Field("Property Type", options: ["Apartment", "House", "Condo", "Townhouse", "Studio", "Commercial"]) var propertyType: String = "Apartment"
    @Field("Bedrooms") var bedrooms: Double = 2
    @Field("Bathrooms") var bathrooms: Double = 1
    @Field("Square Feet") var sqft: Double = 850
    @Field("Parking", options: ["Included", "Additional Fee", "None"]) var parking: String = "None"

    @SlopKit.Section("Landlord")
    @Field("Landlord Name") var landlordName: String = "Property Mgmt Co."
    @Field("Landlord Contact") var landlordContact: String = "office@propmgmt.com"

    @SlopKit.Section("Tenant")
    @Field("Tenant Name") var tenantName: String = "Alex Johnson"
    @Field("Tenant Contact") var tenantContact: String = "alex.j@email.com"

    @SlopKit.Section("Financial")
    @Field("Monthly Rent") var monthlyRent: Double = 2500
    @Field("Security Deposit") var securityDeposit: Double = 5000
    @Field("Late Fee") var lateFee: Double = 75
    @Field("Grace Days") var graceDays: Double = 5
    @Field("Rent Due Day") var rentDueDay: Double = 1
    @Field("Utilities Included", options: ["All", "Water Only", "None"]) var utilities: String = "Water Only"

    @SlopKit.Section("Conditions")
    @Field("Conditions") var conditions: [LeaseCondition] = LeaseAgreementData.defaultConditions

    @SlopKit.Section("Notes")
    @Field("Additional Terms", editor: .multiLine) var additionalTerms: String = ""

    var totalLeaseCost: Double {
        let months = leaseMonths
        return monthlyRent * Double(months) + securityDeposit
    }

    var leaseMonths: Int {
        let components = Calendar.current.dateComponents([.month], from: startDate, to: endDate)
        return max(components.month ?? 12, 1)
    }

    var acknowledgedConditions: Int {
        conditions.filter(\.acknowledged).count
    }
}

extension LeaseAgreementData {
    static var defaultConditions: [LeaseCondition] {
        func condition(_ text: String) -> LeaseCondition {
            var c = LeaseCondition()
            c.condition = text
            return c
        }
        return [
            condition("No smoking on premises"),
            condition("Pets require written approval and additional deposit"),
            condition("Tenant responsible for minor repairs under $100"),
            condition("24-hour notice required for landlord entry"),
            condition("No alterations without written consent"),
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.lease-agreement",
    name: "Lease Agreement",
    description: "Manage lease terms, property details, financials, and conditions.",
    version: "1.0.0",
    width: 440, height: 660,
    minWidth: 380, minHeight: 480,
    shape: .roundedRect(radius: 20),
    theme: "paper-ledger",
    alwaysOnTop: true,
    categories: ["legal"]
)
struct LeaseAgreementView: View {
    @TemplateData var data: LeaseAgreementData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        SlopTextField("Title", text: $data.title)
                            .font(theme.title(size: 20))
                            .foregroundStyle(theme.foreground)
                        if renderTarget == .interactive {
                            Picker("Lease Type", selection: $data.leaseType) {
                                Text("Fixed").tag("Fixed")
                                Text("Month-to-Month").tag("Month-to-Month")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.small)
                        } else {
                            StatusBadge(data.leaseType)
                        }
                    }
                    Spacer()
                    if renderTarget == .interactive {
                        Picker("Status", selection: $data.status) {
                            Text("Draft").tag("Draft")
                            Text("Active").tag("Active")
                            Text("Expired").tag("Expired")
                            Text("Terminated").tag("Terminated")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    } else {
                        StatusBadge(data.status)
                    }
                }

                HStack(spacing: 16) {
                    dateField("Start", $data.startDate)
                    dateField("End", $data.endDate)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(theme.font(size: 10, weight: .medium))
                            .foregroundStyle(theme.secondary)
                        Text("\(data.leaseMonths) months")
                            .font(theme.font(size: 12, weight: .medium))
                            .foregroundStyle(theme.accent)
                    }
                }

                ThemeDivider()

                // Property Details
                SectionHeader("Property")
                VStack(alignment: .leading, spacing: 8) {
                    SlopTextField("Address", text: $data.propertyAddress)
                        .font(theme.font(size: 14, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                    SlopTextField("City", text: $data.propertyCity)
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)

                    HStack(spacing: 12) {
                        if renderTarget == .interactive {
                            Picker("Type", selection: $data.propertyType) {
                                Text("Apartment").tag("Apartment")
                                Text("House").tag("House")
                                Text("Condo").tag("Condo")
                                Text("Townhouse").tag("Townhouse")
                                Text("Studio").tag("Studio")
                                Text("Commercial").tag("Commercial")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.small)
                        } else {
                            StatusBadge(data.propertyType)
                        }

                        detailPill("bed", "\(Int(data.bedrooms)) BD")
                        detailPill("shower", "\(Int(data.bathrooms)) BA")
                        detailPill("ruler", "\(Int(data.sqft)) sqft")
                    }
                }
                .padding(12)
                .background(theme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Parties
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LANDLORD")
                            .font(theme.mono(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Name", text: $data.landlordName)
                            .font(theme.font(size: 13, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                        SlopTextField("Contact", text: $data.landlordContact)
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("TENANT")
                            .font(theme.mono(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Name", text: $data.tenantName)
                            .font(theme.font(size: 13, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                        SlopTextField("Contact", text: $data.tenantContact)
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                ThemeDivider()

                // Financial
                SectionHeader("Financial")

                SummaryRow(label: "Monthly Rent", value: "$\(String(format: "%.2f", data.monthlyRent))", valueColor: theme.accent, isBold: true)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("Rent:")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        Text("$")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        SlopNumberField("0", value: $data.monthlyRent)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 55)
                    }
                    HStack(spacing: 4) {
                        Text("Deposit:")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        Text("$")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        SlopNumberField("0", value: $data.securityDeposit)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 55)
                    }
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("Late fee:")
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                        Text("$")
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                        SlopNumberField("0", value: $data.lateFee)
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 40)
                    }
                    HStack(spacing: 4) {
                        Text("Grace:")
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                        SlopNumberField("5", value: $data.graceDays, format: "%.0f")
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 24)
                        Text("days")
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("Due day:")
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                        SlopNumberField("1", value: $data.rentDueDay, format: "%.0f")
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 24)
                    }
                }

                HStack {
                    Text("Utilities:")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                    if renderTarget == .interactive {
                        Picker("", selection: $data.utilities) {
                            Text("All").tag("All")
                            Text("Water Only").tag("Water Only")
                            Text("None").tag("None")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    } else {
                        Text(data.utilities)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)
                    }
                }

                SummaryRow(label: "Total Lease Cost", value: "$\(String(format: "%.2f", data.totalLeaseCost))")

                ThemeDivider()

                // Conditions
                SectionHeader("Conditions (\(data.acknowledgedConditions)/\(data.conditions.count))")

                ForEach($data.conditions) { $condition in
                    HStack(spacing: 8) {
                        CheckmarkIndicator(isChecked: $condition.acknowledged)

                        SlopTextField("Condition", text: $condition.condition)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)

                        Spacer()

                        SlopInteractiveOnly {
                            RemoveButton {
                                withAnimation { data.conditions.removeAll { $0.id == condition.id } }
                            }
                        }
                    }
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Condition") {
                        withAnimation { data.conditions.append(LeaseCondition()) }
                    }
                }

                // Additional terms
                if !data.additionalTerms.isEmpty || renderTarget == .interactive {
                    ThemeDivider()
                    SectionHeader("Additional Terms")
                    SlopEditable($data.additionalTerms) { value in
                        Text(value)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    } editor: { $value in
                        TextEditor(text: $value)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground.opacity(0.85))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 40)
                    }
                }
            }
            .padding(26)
        }
        .background(theme.background)
    }

    // MARK: - Helpers

    private func dateField(_ label: String, _ date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(theme.font(size: 10, weight: .medium))
                .foregroundStyle(theme.secondary)
            SlopEditable(date) { value in
                Text(value, style: .date)
                    .font(theme.font(size: 12))
                    .foregroundStyle(theme.foreground)
            } editor: { $value in
                DatePicker("", selection: $value, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }

    private func detailPill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(theme.font(size: 10))
            Text(text)
                .font(theme.font(size: 10, weight: .medium))
        }
        .foregroundStyle(theme.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(theme.surface)
        .clipShape(Capsule())
    }
}

