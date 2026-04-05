import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct ContractTask: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Task") var task: String = ""
    @Field("Deadline") var deadline: Date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @Field("Status", options: ["Pending", "In Progress", "Done"]) var status: String = "Pending"
}

@SlopData
public struct ContractExpense: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Description") var description: String = ""
    @Field("Amount") var amount: Double = 0
    @Field("Reimbursable") var reimbursable: Bool = true
}

@SlopData
public struct ContractorAgreementData {
    @SlopKit.Section("Overview")
    @Field("Document Title") var title: String = "Contractor Agreement"
    @Field("Status", options: ["Draft", "Active", "Completed", "Terminated"]) var status: String = "Draft"
    @Field("Start Date") var startDate: Date = .now
    @Field("End Date") var endDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now

    @SlopKit.Section("Contractor")
    @Field("Contractor Name") var contractorName: String = "Jane Developer"
    @Field("Contractor Address") var contractorAddress: String = "456 Freelance Way"
    @Field("Tax ID") var taxID: String = ""

    @SlopKit.Section("Client")
    @Field("Client Name") var clientName: String = "TechCorp Inc"
    @Field("Client Address") var clientAddress: String = "789 Enterprise Blvd"

    @SlopKit.Section("Scope")
    @Field("Scope of Work", editor: .multiLine) var scopeOfWork: String = "Development of iOS mobile application including UI implementation, API integration, and unit testing."

    @SlopKit.Section("Tasks")
    @Field("Tasks") var tasks: [ContractTask] = ContractorAgreementData.defaultTasks

    @SlopKit.Section("Compensation")
    @Field("Rate Type", options: ["Hourly", "Fixed", "Monthly"]) var rateType: String = "Hourly"
    @Field("Rate") var rate: Double = 150
    @Field("Currency", options: ["USD", "EUR", "GBP"]) var currency: String = "USD"
    @Field("Estimated Hours") var estimatedHours: Double = 160
    @Field("Payment Schedule", options: ["Weekly", "Bi-weekly", "Monthly", "On Completion"]) var paymentSchedule: String = "Bi-weekly"

    @SlopKit.Section("Expenses")
    @Field("Expenses") var expenses: [ContractExpense] = []

    @SlopKit.Section("Legal")
    @Field("IP Ownership", options: ["Client", "Contractor", "Shared"]) var ipOwnership: String = "Client"
    @Field("Jurisdiction") var jurisdiction: String = "State of California"
    @Field("Termination Notice (Days)") var terminationNoticeDays: Double = 14

    @SlopKit.Section("Notes")
    @Field("Notes", editor: .multiLine) var notes: String = ""

    var estimatedTotal: Double {
        switch rateType {
        case "Hourly": return rate * estimatedHours
        case "Monthly": return rate * 3
        default: return rate
        }
    }

    var completedTasks: Int { tasks.filter { $0.status == "Done" }.count }
    var totalExpenses: Double { expenses.reduce(0) { $0 + $1.amount } }
    var reimbursableExpenses: Double { expenses.filter(\.reimbursable).reduce(0) { $0 + $1.amount } }
}

extension ContractorAgreementData {
    static var defaultTasks: [ContractTask] {
        func task(_ name: String, _ daysFromNow: Int, _ status: String) -> ContractTask {
            var t = ContractTask()
            t.task = name
            t.deadline = Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now) ?? .now
            t.status = status
            return t
        }
        return [
            task("Project setup & architecture", 7, "Done"),
            task("UI implementation", 30, "In Progress"),
            task("API integration", 45, "Pending"),
            task("Testing & QA", 60, "Pending"),
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.contractor-agreement",
    name: "Contractor Agreement",
    description: "Manage contractor engagements with tasks, compensation, and expenses.",
    version: "1.0.0",
    width: 440, height: 640,
    minWidth: 380, minHeight: 480,
    shape: .roundedRect(radius: 20),
    theme: "corporate-blue",
    alwaysOnTop: true,
    categories: ["legal"]
)
struct ContractorAgreementView: View {
    @TemplateData var data: ContractorAgreementData
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

                HStack(spacing: 16) {
                    dateField("Start", $data.startDate)
                    dateField("End", $data.endDate)
                }

                ThemeDivider()

                // Parties
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONTRACTOR")
                            .font(theme.mono(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Name", text: $data.contractorName)
                            .font(theme.font(size: 13, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                        SlopTextField("Address", text: $data.contractorAddress)
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                        if !data.taxID.isEmpty || renderTarget == .interactive {
                            HStack(spacing: 4) {
                                Text("Tax ID:")
                                    .font(theme.font(size: 10))
                                    .foregroundStyle(theme.secondary)
                                SlopTextField("Tax ID", text: $data.taxID)
                                    .font(theme.font(size: 10))
                                    .foregroundStyle(theme.foreground)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("CLIENT")
                            .font(theme.mono(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("Name", text: $data.clientName)
                            .font(theme.font(size: 13, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                        SlopTextField("Address", text: $data.clientAddress)
                            .font(theme.font(size: 11))
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        .frame(minHeight: 50)
                }

                // Tasks
                SectionHeader("Tasks (\(data.completedTasks)/\(data.tasks.count))")

                ProgressBar(progress: data.tasks.isEmpty ? 0 : Double(data.completedTasks) / Double(data.tasks.count), fillColor: theme.accent, backgroundColor: theme.surface)

                ForEach($data.tasks) { $task in
                    HStack(spacing: 8) {
                        if renderTarget == .interactive {
                            Picker("", selection: $task.status) {
                                Text("Pending").tag("Pending")
                                Text("In Progress").tag("In Progress")
                                Text("Done").tag("Done")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.mini)
                            .frame(width: 90)
                        } else {
                            StatusBadge(task.status)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            SlopTextField("Task", text: $task.task)
                                .font(theme.font(size: 12))
                                .foregroundStyle(task.status == "Done" ? theme.secondary : theme.foreground)
                                .strikethrough(task.status == "Done")
                            SlopEditable($task.deadline) { value in
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
                                withAnimation { data.tasks.removeAll { $0.id == task.id } }
                            }
                        }
                    }
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Task") {
                        withAnimation { data.tasks.append(ContractTask()) }
                    }
                }

                ThemeDivider()

                // Compensation
                SectionHeader("Compensation")

                HStack(spacing: 12) {
                    if renderTarget == .interactive {
                        Picker("Rate Type", selection: $data.rateType) {
                            Text("Hourly").tag("Hourly")
                            Text("Fixed").tag("Fixed")
                            Text("Monthly").tag("Monthly")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    } else {
                        StatusBadge(data.rateType)
                    }

                    HStack(spacing: 2) {
                        Text(currencySymbol(for: data.currency))
                            .font(theme.font(size: 13))
                            .foregroundStyle(theme.secondary)
                        SlopNumberField("0", value: $data.rate)
                            .font(theme.font(size: 14, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 60)
                        if data.rateType == "Hourly" {
                            Text("/hr")
                                .font(theme.font(size: 11))
                                .foregroundStyle(theme.secondary)
                        } else if data.rateType == "Monthly" {
                            Text("/mo")
                                .font(theme.font(size: 11))
                                .foregroundStyle(theme.secondary)
                        }
                    }
                }

                if data.rateType == "Hourly" {
                    HStack {
                        Text("Est. hours:")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                        SlopNumberField("0", value: $data.estimatedHours, format: "%.0f")
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 40)
                    }
                }

                SummaryRow(label: "Estimated Total", value: formatCurrency(data.estimatedTotal, code: data.currency), isBold: true)

                HStack {
                    Text("Payment schedule:")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                    if renderTarget == .interactive {
                        Picker("", selection: $data.paymentSchedule) {
                            Text("Weekly").tag("Weekly")
                            Text("Bi-weekly").tag("Bi-weekly")
                            Text("Monthly").tag("Monthly")
                            Text("On Completion").tag("On Completion")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    } else {
                        Text(data.paymentSchedule)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.foreground)
                    }
                }

                // Expenses
                if !data.expenses.isEmpty || renderTarget == .interactive {
                    ThemeDivider()
                    SectionHeader("Expenses")

                    ForEach($data.expenses) { $expense in
                        HStack(spacing: 8) {
                            SlopTextField("Description", text: $expense.description)
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.foreground)
                            Spacer()
                            Text(formatCurrency(expense.amount, code: data.currency))
                                .font(theme.font(size: 12, weight: .medium))
                                .foregroundStyle(theme.foreground)
                            if expense.reimbursable {
                                Text("R")
                                    .font(theme.font(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            SlopInteractiveOnly {
                                RemoveButton {
                                    withAnimation { data.expenses.removeAll { $0.id == expense.id } }
                                }
                            }
                        }
                    }

                    if !data.expenses.isEmpty {
                        SummaryRow(label: "Total Expenses", value: formatCurrency(data.totalExpenses, code: data.currency))
                        if data.reimbursableExpenses > 0 {
                            SummaryRow(label: "Reimbursable", value: formatCurrency(data.reimbursableExpenses, code: data.currency))
                        }
                    }

                    SlopInteractiveOnly {
                        AddItemButton("Add Expense") {
                            withAnimation { data.expenses.append(ContractExpense()) }
                        }
                    }
                }

                ThemeDivider()

                // Legal
                SectionHeader("Legal Terms")
                HStack {
                    Text("IP Ownership:")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                    if renderTarget == .interactive {
                        Picker("", selection: $data.ipOwnership) {
                            Text("Client").tag("Client")
                            Text("Contractor").tag("Contractor")
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
                    SlopNumberField("14", value: $data.terminationNoticeDays, format: "%.0f")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.foreground)
                        .frame(width: 30)
                    Text("days")
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.secondary)
                }

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
}

