import SwiftUI

/// A color wrapper that stores as a hex string for JSON serialization.
public struct HexColor: Codable, Sendable, Hashable {
    public let hex: String

    public init(_ hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !h.hasPrefix("#") { h = "#\(h)" }
        self.hex = h
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    /// Convert to SwiftUI Color.
    public var color: Color {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let rgb = UInt64(h, radix: 16) else {
            return .gray
        }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

extension HexColor: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

/// Convert a hex string (e.g. "#4a90d9") to a SwiftUI Color.
/// Convenience for templates — delegates to `HexColor.color`.
public func colorFromHex(_ hex: String) -> Color {
    HexColor(hex).color
}
