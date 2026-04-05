import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct LoanCalculatorData {
    @SlopKit.Section("Loan Details")
    @Field("Loan Amount") var loanAmount: Double = 250000
    @Field("Interest Rate") var interestRate: Double = 6.5
    @Field("Term Years") var termYears: Double = 30
    @Field("Extra Payment") var extraPayment: Double = 0

    var monthlyRate: Double {
        interestRate / 100.0 / 12.0
    }

    var totalPayments: Double {
        termYears * 12
    }

    var monthlyPayment: Double {
        if monthlyRate == 0 {
            return loanAmount / totalPayments
        }
        let r = monthlyRate
        let n = totalPayments
        let numerator = loanAmount * r * pow(1 + r, n)
        let denominator = pow(1 + r, n) - 1
        return numerator / denominator
    }

    var totalCost: Double {
        monthlyPayment * totalPayments
    }

    var totalInterest: Double {
        totalCost - loanAmount
    }

    var monthsSavedWithExtra: Double? {
        guard extraPayment > 0 else { return nil }

        let totalPayment = monthlyPayment + extraPayment
        if monthlyRate == 0 {
            let months = loanAmount / totalPayment
            return totalPayments - months
        }

        // Calculate months to payoff with extra payment
        var balance = loanAmount
        var months = 0.0
        let r = monthlyRate

        while balance > 0 && months < totalPayments {
            let interest = balance * r
            let principal = min(totalPayment - interest, balance)
            balance -= principal
            months += 1
        }

        return totalPayments - months
    }

    var interestSavedWithExtra: Double? {
        guard let monthsSaved = monthsSavedWithExtra else { return nil }

        // Calculate total interest paid with extra payment
        var balance = loanAmount
        var totalInterestPaid = 0.0
        let totalPayment = monthlyPayment + extraPayment
        let r = monthlyRate

        while balance > 0 {
            let interest = balance * r
            totalInterestPaid += interest
            let principal = min(totalPayment - interest, balance)
            balance -= principal
        }

        return totalInterest - totalInterestPaid
    }

    var principalPercentage: Double {
        guard totalCost > 0 else { return 0 }
        return loanAmount / totalCost
    }

    var interestPercentage: Double {
        guard totalCost > 0 else { return 0 }
        return totalInterest / totalCost
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.loan-calculator",
    name: "Loan Calculator",
    description: "Calculate monthly payments, total interest, and payoff timelines for any loan.",
    version: "1.0.0",
    width: 400, height: 580,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["finance"]
)
struct LoanCalculatorView: View {
    @TemplateData var data: LoanCalculatorData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text("Loan Calculator")
                    .font(theme.titleFont.weight(.bold))
                    .foregroundColor(theme.foreground)

                // Input fields
                VStack(alignment: .leading, spacing: 16) {
                    inputField(
                        label: "Loan Amount",
                        value: $data.loanAmount,
                        prefix: "$"
                    )

                    inputField(
                        label: "Interest Rate",
                        value: $data.interestRate,
                        suffix: "%"
                    )

                    inputField(
                        label: "Term (Years)",
                        value: $data.termYears
                    )

                    inputField(
                        label: "Extra Monthly Payment",
                        value: $data.extraPayment,
                        prefix: "$"
                    )
                }
                .padding(16)
                .background(theme.surface)
                .cornerRadius(12)

                Divider()
                    .background(theme.divider)

                // Results section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Monthly Payment")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)

                    Text("$\(formatNumber(data.monthlyPayment))")
                        .font(theme.title(size: 36))
                        .foregroundColor(theme.accent)

                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Interest")
                                .font(theme.font(size: 12))
                                .foregroundColor(theme.secondary)
                            Text("$\(formatNumber(data.totalInterest))")
                                .font(theme.bodyFont.weight(.semibold))
                                .foregroundColor(Color.red.opacity(0.8))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Cost")
                                .font(theme.font(size: 12))
                                .foregroundColor(theme.secondary)
                            Text("$\(formatNumber(data.totalCost))")
                                .font(theme.bodyFont.weight(.semibold))
                                .foregroundColor(theme.foreground)
                        }
                    }

                    // Extra payment savings
                    if let monthsSaved = data.monthsSavedWithExtra,
                       let interestSaved = data.interestSavedWithExtra,
                       monthsSaved > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                                .background(theme.divider)

                            Text("With Extra Payment")
                                .font(theme.bodyFont.weight(.semibold))
                                .foregroundColor(theme.foreground)

                            HStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Months Saved")
                                        .font(theme.font(size: 12))
                                        .foregroundColor(theme.secondary)
                                    Text("\(Int(monthsSaved))")
                                        .font(theme.bodyFont.weight(.semibold))
                                        .foregroundColor(Color.green.opacity(0.8))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Interest Saved")
                                        .font(theme.font(size: 12))
                                        .foregroundColor(theme.secondary)
                                    Text("$\(formatNumber(interestSaved))")
                                        .font(theme.bodyFont.weight(.semibold))
                                        .foregroundColor(Color.green.opacity(0.8))
                                }
                            }
                        }
                    }
                }

                // Amortization visualization
                VStack(alignment: .leading, spacing: 8) {
                    Text("Principal vs Interest")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)

                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(theme.accent)
                                .frame(width: geometry.size.width * data.principalPercentage)

                            Rectangle()
                                .fill(Color.red.opacity(0.6))
                                .frame(width: geometry.size.width * data.interestPercentage)
                        }
                        .cornerRadius(8)
                    }
                    .frame(height: 32)

                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 8, height: 8)
                            Text("Principal \(Int(data.principalPercentage * 100))%")
                                .font(theme.font(size: 11))
                                .foregroundColor(theme.secondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red.opacity(0.6))
                                .frame(width: 8, height: 8)
                            Text("Interest \(Int(data.interestPercentage * 100))%")
                                .font(theme.font(size: 11))
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func inputField(
        label: String,
        value: Binding<Double>,
        prefix: String? = nil,
        suffix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(theme.font(size: 12, weight: .medium))
                .foregroundColor(theme.secondary)

            HStack(spacing: 4) {
                if let prefix = prefix {
                    Text(prefix)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)
                }

                if renderTarget == .interactive {
                    SlopNumberField("0", value: value)
                        .textFieldStyle(.plain)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.foreground)
                } else {
                    Text(formatNumber(value.wrappedValue))
                        .font(theme.bodyFont)
                        .foregroundColor(theme.foreground)
                }

                if let suffix = suffix {
                    Text(suffix)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background)
            .cornerRadius(6)
        }
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}
