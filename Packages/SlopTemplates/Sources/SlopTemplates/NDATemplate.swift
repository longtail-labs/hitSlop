import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct NDAException: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Description") var description: String = ""
}

@SlopData
public struct NDAData {
    @SlopKit.Section("Overview")
    @Field("Document Title") var title: String = "Non-Disclosure Agreement"
    @Field("NDA Type", options: ["Mutual", "One-Way"]) var ndaType: String = "Mutual"
    @Field("Status", options: ["Draft", "Pending Signature", "Executed", "Expired"]) var status: String = "Draft"
    @Field("Effective Date") var effectiveDate: Date = .now
    @Field("Expiration Date") var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now

    @SlopKit.Section("Disclosing Party")
    @Field("Disclosing Party Name") var disclosingName: String = "Acme Corp"
    @Field("Disclosing Address") var disclosingAddress: String = "123 Business Ave, Suite 100"
    @Field("Disclosing Contact") var disclosingContact: String = "legal@acme.com"

    @SlopKit.Section("Receiving Party")
    @Field("Receiving Party Name") var receivingName: String = "Beta LLC"
    @Field("Receiving Address") var receivingAddress: String = "456 Innovation Dr"
    @Field("Receiving Contact") var receivingContact: String = "counsel@beta.io"

    @SlopKit.Section("Terms")
    @Field("Jurisdiction") var jurisdiction: String = "State of California"
    @Field("Confidentiality Term (Months)") var confidentialityTermMonths: Double = 24
    @Field("Purpose") var purpose: String = "Evaluating a potential business partnership"

    @SlopKit.Section("Exceptions")
    @Field("Exceptions") var exceptions: [NDAException] = NDAData.defaultExceptions

    @SlopKit.Section("Notes")
    @Field("Additional Terms", editor: .multiLine) var additionalTerms: String = ""
}

extension NDAData {
    static var defaultExceptions: [NDAException] {
        func exception(_ desc: String) -> NDAException {
            var e = NDAException()
            e.description = desc
            return e
        }
        return [
            exception("Information already in the public domain"),
            exception("Information independently developed by the receiving party"),
            exception("Information disclosed pursuant to a court order"),
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.nda",
    name: "NDA",
    description: "Draft a non-disclosure agreement with party details, terms, and exceptions.",
    version: "1.0.0",
    width: 440, height: 620,
    minWidth: 380, minHeight: 460,
    shape: .roundedRect(radius: 20),
    theme: "corporate-blue",
    alwaysOnTop: true,
    categories: ["legal"]
)
struct NDAView: View {
    @TemplateData var data: NDAData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        SlopTextField("Title", text: $data.title)
                            .font(theme.title(size: 20))
                            .foregroundStyle(theme.foreground)

                        HStack(spacing: 8) {
                            if renderTarget == .interactive {
                                Picker("Type", selection: $data.ndaType) {
                                    Text("Mutual").tag("Mutual")
                                    Text("One-Way").tag("One-Way")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .controlSize(.small)
                            } else {
                                StatusBadge(data.ndaType)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if renderTarget == .interactive {
                            Picker("Status", selection: $data.status) {
                                Text("Draft").tag("Draft")
                                Text("Pending Signature").tag("Pending Signature")
                                Text("Executed").tag("Executed")
                                Text("Expired").tag("Expired")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.small)
                        } else {
                            StatusBadge(data.status)
                        }
                    }
                }

                // Dates
                HStack(spacing: 16) {
                    dateField("Effective", $data.effectiveDate)
                    dateField("Expires", $data.expirationDate)
                }

                ThemeDivider()

                // Parties side by side
                HStack(alignment: .top, spacing: 12) {
                    partyCard(
                        label: data.ndaType == "Mutual" ? "Party A" : "Disclosing Party",
                        name: $data.disclosingName,
                        address: $data.disclosingAddress,
                        contact: $data.disclosingContact
                    )
                    partyCard(
                        label: data.ndaType == "Mutual" ? "Party B" : "Receiving Party",
                        name: $data.receivingName,
                        address: $data.receivingAddress,
                        contact: $data.receivingContact
                    )
                }

                ThemeDivider()

                // Terms
                SectionHeader("Terms")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Jurisdiction:")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Jurisdiction", text: $data.jurisdiction)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)
                    }

                    HStack {
                        Text("Confidentiality:")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        SlopNumberField("24", value: $data.confidentialityTermMonths, format: "%.0f")
                            .font(theme.font(size: 12, weight: .medium))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 36)
                        Text("months")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Purpose of Disclosure")
                        .font(theme.font(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondary)
                    SlopEditable($data.purpose) { value in
                        Text(value)
                            .font(theme.font(size: 13))
                            .foregroundStyle(theme.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    } editor: { $value in
                        TextEditor(text: $value)
                            .font(theme.font(size: 13))
                            .foregroundStyle(theme.foreground)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 40)
                    }
                }

                ThemeDivider()

                // Exceptions
                SectionHeader("Exceptions to Confidentiality")

                ForEach($data.exceptions) { $exception in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.accent)
                        SlopTextField("Exception description", text: $exception.description)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)
                        Spacer()
                        SlopInteractiveOnly {
                            RemoveButton {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    data.exceptions.removeAll { $0.id == exception.id }
                                }
                            }
                        }
                    }
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Exception") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.exceptions.append(NDAException())
                        }
                    }
                }

                // Additional Terms
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

