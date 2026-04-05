import Foundation
import SwiftUI

/// A currency input combining a currency symbol with a number field.
///
/// Displays the appropriate currency symbol based on the currency code.
///
/// Example usage:
/// ```swift
/// CurrencyInput(
///     currency: "USD",
///     value: $data.income,
///     width: 80
/// )
/// ```
public struct CurrencyInput: View {
    let currency: String
    let binding: Binding<Double>
    let width: CGFloat
    let symbolColor: Color?
    let valueColor: Color?

    @Environment(\.slopTheme) private var theme

    /// Creates a currency input field.
    /// - Parameters:
    ///   - currency: Currency code (e.g., "USD", "EUR", "GBP")
    ///   - value: Binding to the numeric value
    ///   - width: Width of the number field (default: 80)
    ///   - symbolColor: Color for the currency symbol (default: theme accent)
    ///   - valueColor: Color for the value (default: theme foreground)
    public init(
        currency: String,
        value: Binding<Double>,
        width: CGFloat = 80,
        symbolColor: Color? = nil,
        valueColor: Color? = nil
    ) {
        self.currency = currency
        self.binding = value
        self.width = width
        self.symbolColor = symbolColor
        self.valueColor = valueColor
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text(currencySymbol(for: currency))
                .foregroundStyle(symbolColor ?? theme.accent)
            SlopNumberField("0", value: binding)
                .foregroundStyle(valueColor ?? theme.foreground)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
        }
    }
}
