import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct ServiceDeliverable: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Description") var description: String = ""
    @Field("Due Date") var dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @Field("Completed") var completed: Bool = false
}

@SlopData
public struct PaymentMilestone: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Description") var description: String = ""
    @Field("Amount") var amount: Double = 0
    @Field("Due Date") var dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @Field("Paid") var paid: Bool = false
}

@SlopData
public struct ServiceAgreementData {
    @SlopKit.Section("Overview")
    @Field("Document Title") var title: String = "Service Agreement"
    @Field("Status", options: ["Draft", "Active", "Completed", "Terminated"]) var status: String = "Draft"
    @Field("Effective Date") var effectiveDate: Date = .now
    @Field("End Date") var endDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now

    @SlopKit.Section("Provider")
    @Field("Provider Name") var providerName: String = "Creative Services LLC"
    @Field("Provider Address") var providerAddress: String = "789 Design Blvd"
    @Field("Provider Contact") var providerContact: String = "hello@creative.co"

    @SlopKit.Section("Client")
    @Field("Client Name") var clientName: String = "TechStart Inc"
    @Field("Client Address") var clientAddress: String = "321 Startup Lane"
    @Field("Client Contact") var clientContact: String = "ops@techstart.io"

    @SlopKit.Section("Scope")
    @Field("Scope of Work", editor: .multiLine) var scopeOfWork: String = "Design and development of brand identity system including logo, color palette, typography, and brand guidelines document."

    @SlopKit.Section("Deliverables")
    @Field("Deliverables") var deliverables: [ServiceDeliverable] = ServiceAgreementData.defaultDeliverables

    @SlopKit.Section("Payment")
    @Field("Currency", options: ["USD", "EUR", "GBP"]) var currency: String = "USD"
    @Field("Total Value") var totalValue: Double = 15000
    @Field("Payment Terms") var paymentTerms: String = "Net 30"
    @Field("Milestones") var milestones: [PaymentMilestone] = ServiceAgreementData.defaultMilestones

    @SlopKit.Section("Legal")
    @Field("Termination Notice (Days)") var terminationNoticeDays: Double = 30
    @Field("Jurisdiction") var jurisdiction: String = "State of New York"
    @Field("IP Ownership", options: ["Client", "Provider", "Shared"]) var ipOwnership: String = "Client"
    @Field("Confidentiality") var confidentiality: Bool = true

    @SlopKit.Section("Notes")
    @Field("Notes", editor: .multiLine) var notes: String = ""

    var totalPaid: Double { milestones.filter(\.paid).reduce(0) { $0 + $1.amount } }
    var completedDeliverables: Int { deliverables.filter(\.completed).count }
    var paymentProgress: Double { totalValue > 0 ? totalPaid / totalValue : 0 }
}

extension ServiceAgreementData {
    static var defaultDeliverables: [ServiceDeliverable] {
        func deliverable(_ desc: String, _ daysFromNow: Int) -> ServiceDeliverable {
            var d = ServiceDeliverable()
            d.description = desc
            d.dueDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now) ?? .now
            return d
        }
        return [
            deliverable("Brand research & mood boards", 14),
            deliverable("Logo concepts (3 options)", 30),
            deliverable("Color palette & typography", 45),
            deliverable("Brand guidelines document", 60),
        ]
    }

    static var defaultMilestones: [PaymentMilestone] {
        func milestone(_ desc: String, _ amount: Double, _ daysFromNow: Int) -> PaymentMilestone {
            var m = PaymentMilestone()
            m.description = desc
            m.amount = amount
            m.dueDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now) ?? .now
            return m
        }
        return [
            milestone("Deposit (upon signing)", 5000, 0),
            milestone("Mid-project milestone", 5000, 30),
            milestone("Final delivery", 5000, 60),
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.service-agreement",
    name: "Service Agreement",
    description: "Track deliverables, payment milestones, and terms for service contracts.",
    version: "1.0.0",
    width: 440, height: 640,
    minWidth: 380, minHeight: 480,
    shape: .roundedRect(radius: 20),
    theme: "slate-gray",
    alwaysOnTop: true,
    categories: ["legal"]
)
struct ServiceAgreementView: View {
    @TemplateData var data: ServiceAgreementData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    SlopTextField("Title", text: $data.title)
                        .font(theme.title(size: 20))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    if renderTarget == .interactive {
                        Picker("Status", selection: $data.status) {
                            Text("Draft").tag("Draft")
                            Text("Active").tag("Active")
                            Text("Completed").tag("Completed")
                            Text("Terminated").tag("Terminated")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    } else {
                        StatusBadge(data.status)
                    }
                }

                // Dates
                HStack(spacing: 16) {
                    dateField("Effective", $data.effectiveDate)
                    dateField("End Date", $data.endDate)
                }

                ThemeDivider()

                // Parties
                HStack(alignment: .top, spacing: 12) {
                    partyCard(label: "Provider", name: $data.providerName, address: $data.providerAddress, contact: $data.providerContact)
                    partyCard(label: "Client", name: $data.clientName, address: $data.clientAddress, contact: $data.clientContact)
                }

                ThemeDivider()

                // Scope
                SectionHeader("Scope of Work")
                SlopEditable($data.scopeOfWork) { value in
                    Text(value)
                        .font(theme.font(size: 13))
                        .foregroundStyle(theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                } editor: { $value in
                    TextEditor(text: $value)
                        .font(theme.font(size: 13))
                        .foregroundStyle(theme.foreground)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                }

                // Deliverables
                SectionHeader("Deliverables (\(data.completedDeliverables)/\(data.deliverables.count))")

                ForEach($data.deliverables) { $deliverable in
                    HStack(spacing: 8) {
                        CheckmarkIndicator(isChecked: $deliverable.completed, tint: .green)

                        VStack(alignment: .leading, spacing: 2) {
                            SlopTextField("Deliverable", text: $deliverable.description)
                                .font(theme.font(size: 12))
                                .foregroundStyle(deliverable.completed ? theme.secondary : theme.foreground)
                                .strikethrough(deliverable.completed)
                            SlopEditable($deliverable.dueDate) { value in
                                Text("Due: \(dateStringAbbreviated(value))")
                                    .font(theme.font(size: 10))
                                    .foregroundStyle(theme.secondary)
                            } editor: { $value in
                                DatePicker("", selection: $value, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }

                        Spacer()

                        SlopInteractiveOnly {
                            RemoveButton {
                                withAnimation { data.deliverables.removeAll { $0.id == deliverable.id } }
                            }
                        }
                    }
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Deliverable") {
                        withAnimation { data.deliverables.append(ServiceDeliverable()) }
                    }
                }

                ThemeDivider()

                // Payment
                SectionHeader("Payment")

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("Total:")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        Text(formatCurrency(data.totalValue, code: data.currency))
                            .font(theme.font(size: 14, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                    }
                    Spacer()
                    Text("Paid: \(formatCurrency(data.totalPaid, code: data.currency))")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.accent)
                }

                ProgressBar(progress: data.paymentProgress, fillColor: theme.accent, backgroundColor: theme.surface)

                ForEach($data.milestones) { $milestone in
                    HStack(spacing: 8) {
                        CheckmarkIndicator(isChecked: $milestone.paid, tint: .green)

                        VStack(alignment: .leading, spacing: 2) {
                            SlopTextField("Milestone", text: $milestone.description)
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.foreground)
                            SlopEditable($milestone.dueDate) { value in
                                Text("Due: \(dateStringAbbreviated(value))")
                                    .font(theme.font(size: 10))
                                    .foregroundStyle(theme.secondary)
                            } editor: { $value in
                                DatePicker("", selection: $value, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }

                        Spacer()

                        Text(formatCurrency(milestone.amount, code: data.currency))
                            .font(theme.font(size: 12, weight: .semibold))
                            .foregroundStyle(milestone.paid ? theme.secondary : theme.foreground)

                        SlopInteractiveOnly {
                            RemoveButton {
                                withAnimation { data.milestones.removeAll { $0.id == milestone.id } }
                            }
                        }
                    }
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Milestone") {
                        withAnimation { data.milestones.append(PaymentMilestone()) }
                    }
                }

                ThemeDivider()

                // Legal terms
                SectionHeader("Legal Terms")
                HStack {
                    Text("IP Ownership:")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                    if renderTarget == .interactive {
                        Picker("", selection: $data.ipOwnership) {
                            Text("Client").tag("Client")
                            Text("Provider").tag("Provider")
                            Text("Shared").tag("Shared")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    } else {
                        Text(data.ipOwnership)
                            .font(theme.font(size: 12, weight: .medium))
                            .foregroundStyle(theme.foreground)
                    }
                }
                HStack {
                    Text("Jurisdiction:")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                    SlopTextField("Jurisdiction", text: $data.jurisdiction)
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.foreground)
                }
                HStack {
                    Text("Termination notice:")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                    SlopNumberField("30", value: $data.terminationNoticeDays, format: "%.0f")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.foreground)
                        .frame(width: 30)
                    Text("days")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                }

                // Notes
                if !data.notes.isEmpty || renderTarget == .interactive {
                    ThemeDivider()
                    SectionHeader("Notes")
                    SlopEditable($data.notes) { value in
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

    private func partyCard(label: String, name: Binding<String>, address: Binding<String>, contact: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(theme.mono(size: 9, weight: .bold))
                .foregroundStyle(theme.secondary)
            SlopTextField("Name", text: name)
                .font(theme.font(size: 13, weight: .semibold))
                .foregroundStyle(theme.foreground)
            SlopTextField("Address", text: address)
                .font(theme.font(size: 11))
                .foregroundStyle(theme.secondary)
            SlopTextField("Contact", text: contact)
                .font(theme.font(size: 11))
                .foregroundStyle(theme.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

