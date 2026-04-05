import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct CRMContact: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Company") var company: String = ""
    @Field("Email") var email: String = ""
    @Field("Phone") var phone: String = ""
    @Field("Status", options: ["Lead", "Active", "Closed", "Churned"]) var status: String = "Lead"
    @Field("Last Contact") var lastContact: Date = .now
    @Field("Notes") var notes: String = ""
    @Field("Value") var value: Double = 0
}

@SlopData
public struct ContactCRMData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Sales Pipeline"
    @Field("Currency", options: ["USD", "EUR", "GBP"]) var currency: String = "USD"

    @SlopKit.Section("Contacts")
    @Field("Contacts") var contacts: [CRMContact] = ContactCRMData.defaultContacts

    var totalPipelineValue: Double {
        contacts.filter { $0.status == "Lead" || $0.status == "Active" }.reduce(0) { $0 + $1.value }
    }

    var leadCount: Int {
        contacts.filter { $0.status == "Lead" }.count
    }

    var activeCount: Int {
        contacts.filter { $0.status == "Active" }.count
    }

    var closedCount: Int {
        contacts.filter { $0.status == "Closed" }.count
    }

    var churnedCount: Int {
        contacts.filter { $0.status == "Churned" }.count
    }
}

extension ContactCRMData {
    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }

    static var defaultContacts: [CRMContact] {
        func contact(_ name: String, _ company: String, _ email: String, _ phone: String, _ status: String, _ lastContact: Date, _ notes: String, _ value: Double) -> CRMContact {
            var c = CRMContact()
            c.name = name
            c.company = company
            c.email = email
            c.phone = phone
            c.status = status
            c.lastContact = lastContact
            c.notes = notes
            c.value = value
            return c
        }

        return [
            contact("Jane Smith", "Acme Corp", "jane@acme.com", "(555) 123-4567", "Lead", makeDate(2026, 3, 28), "Interested in enterprise plan", 50000),
            contact("John Doe", "TechStart Inc", "john@techstart.io", "(555) 234-5678", "Active", makeDate(2026, 3, 30), "Onboarding in progress", 25000),
            contact("Sarah Johnson", "Global Solutions", "sarah@global.com", "(555) 345-6789", "Closed", makeDate(2026, 2, 15), "Deal completed", 75000),
            contact("Mike Chen", "StartupXYZ", "mike@startupxyz.com", "(555) 456-7890", "Lead", makeDate(2026, 3, 25), "Following up next week", 15000),
            contact("Emily Davis", "OldClient Co", "emily@oldclient.com", "(555) 567-8901", "Churned", makeDate(2026, 1, 10), "Switched to competitor", 0)
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.contact-crm",
    name: "Contact CRM",
    description: "Manage contacts, track deal status, and monitor your sales pipeline.",
    version: "1.0.0",
    width: 460, height: 620,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["business"]
)
struct ContactCRMView: View {
    @TemplateData var data: ContactCRMData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                SlopTextField("Title", text: $data.title)
                    .font(theme.titleFont)
                    .foregroundColor(theme.foreground)

                // Pipeline value hero number
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pipeline Value")
                        .font(.caption)
                        .foregroundColor(theme.secondary)

                    Text("\(currencySymbol(for: data.currency))\(Int(data.totalPipelineValue).formatted())")
                        .font(theme.title(size: 36))
                        .foregroundColor(theme.accent)
                }

                // Status summary badges
                HStack(spacing: 8) {
                    StatBadge(count: data.leadCount, label: "Lead", tint: .blue)
                    StatBadge(count: data.activeCount, label: "Active", tint: .green)
                    StatBadge(count: data.closedCount, label: "Closed", tint: .gray)
                    StatBadge(count: data.churnedCount, label: "Churned", tint: .red)
                }

                Divider()
                    .background(theme.divider)

                // Contact list
                VStack(alignment: .leading, spacing: 12) {
                    ForEach($data.contacts) { $contact in
                        ContactCard(contact: $contact, currency: data.currency, theme: theme, renderTarget: renderTarget)
                    }
                }

                // Add contact button
                SlopInteractiveOnly {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.contacts.append(CRMContact())
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Contact")
                        }
                        .font(.subheadline)
                        .foregroundColor(theme.accent)
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

struct ContactCard: View {
    @Binding var contact: CRMContact
    let currency: String
    let theme: SlopTheme
    let renderTarget: SlopRenderTarget

    var statusColor: Color {
        switch contact.status {
        case "Lead": return .blue
        case "Active": return .green
        case "Closed": return .gray
        case "Churned": return .red
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name and company
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    SlopTextField("Name", text: $contact.name)
                        .font(.body.bold())
                        .foregroundColor(theme.foreground)

                    SlopTextField("Company", text: $contact.company)
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                }

                Spacer()

                // Status badge
                Text(contact.status)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .cornerRadius(8)
            }

            // Contact info
            VStack(alignment: .leading, spacing: 4) {
                if !contact.email.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                            .font(.caption2)
                        SlopTextField("Email", text: $contact.email)
                            .font(.caption)
                    }
                    .foregroundColor(theme.secondary)
                }

                if !contact.phone.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.caption2)
                        SlopTextField("Phone", text: $contact.phone)
                            .font(.caption)
                    }
                    .foregroundColor(theme.secondary)
                }
            }

            // Value and last contact
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption2)
                    Text("\(currencySymbol(for: currency))\(Int(contact.value).formatted())")
                        .font(.caption.bold())
                }
                .foregroundColor(theme.accent)

                Spacer()

                SlopEditable($contact.lastContact) { value in
                    Text("Last: ") + Text(value, style: .date)
                        .font(.caption2)
                        .foregroundColor(theme.secondary)
                } editor: { $value in
                    DatePicker("", selection: $value, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            // Notes
            if !contact.notes.isEmpty {
                SlopTextField("Notes", text: $contact.notes)
                    .font(.caption)
                    .foregroundColor(theme.secondary)
                    .italic()
                    .padding(.top, 2)
            }

            // Interactive controls
            SlopInteractiveOnly {
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            let statuses = ["Lead", "Active", "Closed", "Churned"]
                            if let currentIndex = statuses.firstIndex(of: contact.status) {
                                let nextIndex = (currentIndex + 1) % statuses.count
                                contact.status = statuses[nextIndex]
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Cycle Status")
                        }
                        .font(.caption)
                        .foregroundColor(theme.accent)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(8)
    }
}
