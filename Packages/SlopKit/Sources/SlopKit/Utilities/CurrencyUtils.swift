import Foundation

/// Returns the currency symbol for a given ISO 4217 currency code.
public func currencySymbol(for code: String) -> String {
    switch code {
    case "EUR": return "\u{20AC}"
    case "GBP": return "\u{00A3}"
    case "JPY": return "\u{00A5}"
    default: return "$"
    }
}

/// Formats a numeric value as currency with the given ISO 4217 code.
///
/// ```swift
/// formatCurrency(1234.56, code: "USD")  // "$1,235"
/// formatCurrency(1234.56, code: "EUR", decimals: 2)  // "€1,234.56"
/// ```
public func formatCurrency(_ value: Double, code: String, decimals: Int = 0) -> String {
    let symbol = currencySymbol(for: code)
    let formatted = String(format: "%.\(decimals)f", value)
    // Add thousand separators for readability
    if decimals == 0, let intVal = Int(exactly: value.rounded()) {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        if let str = nf.string(from: NSNumber(value: intVal)) {
            return "\(symbol)\(str)"
        }
    }
    return "\(symbol)\(formatted)"
}
