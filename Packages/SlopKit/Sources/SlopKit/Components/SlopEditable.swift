import SwiftUI
import AppKit

/// Switches between a display view (export) and an editor view (interactive)
/// based on the current `slopRenderTarget`.
///
/// ```swift
/// SlopEditable($data.title) { value in
///     Text(value).font(.title)
/// } editor: { binding in
///     TextField("Title", text: binding).font(.title)
/// }
/// ```
public struct SlopEditable<Value, Display: View, Editor: View>: View {
    private let value: Binding<Value>
    private let display: (Value) -> Display
    private let editor: (Binding<Value>) -> Editor

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(
        _ value: Binding<Value>,
        @ViewBuilder display: @escaping (Value) -> Display,
        @ViewBuilder editor: @escaping (Binding<Value>) -> Editor
    ) {
        self.value = value
        self.display = display
        self.editor = editor
    }

    public var body: some View {
        if renderTarget == .interactive {
            editor(value)
        } else {
            display(value.wrappedValue)
        }
    }
}

// MARK: - Convenience: SlopTextField

/// A text field in interactive mode, plain `Text` in export.
///
/// ```swift
/// SlopTextField("Title", text: $data.title)
///     .font(.title)
/// ```
public struct SlopTextField: View {
    private let placeholder: String
    private let binding: Binding<String>

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(_ placeholder: String = "", text: Binding<String>) {
        self.placeholder = placeholder
        self.binding = text
    }

    public var body: some View {
        if renderTarget == .interactive {
            TextField(placeholder, text: binding, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
        } else {
            Text(binding.wrappedValue)
                .lineLimit(1...6)
                .truncationMode(.tail)
                .frame(minWidth: 0, alignment: .leading)
        }
    }
}

// MARK: - Convenience: SlopNumberField

/// A numeric text field in interactive mode, formatted `Text` in export.
///
/// ```swift
/// SlopNumberField("0", value: $data.amount, format: "%.2f")
/// ```
public struct SlopNumberField: View {
    private let placeholder: String
    private let binding: Binding<Double>
    private let formatString: String

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(_ placeholder: String = "0", value: Binding<Double>, format: String = "%.0f") {
        self.placeholder = placeholder
        self.binding = value
        self.formatString = format
    }

    public var body: some View {
        if renderTarget == .interactive {
            TextField(placeholder, value: binding, format: .number)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            Text(String(format: formatString, binding.wrappedValue))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .truncationMode(.tail)
        }
    }
}

// MARK: - Convenience: SlopColorField

/// A native `ColorPicker` in interactive mode, a filled `Circle` in export.
///
/// ```swift
/// SlopColorField(hex: $category.color)
/// ```
public struct SlopColorField: View {
    private let binding: Binding<String>

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(hex: Binding<String>) {
        self.binding = hex
    }

    public var body: some View {
        if renderTarget == .interactive {
            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
        } else {
            Circle()
                .fill(colorFromHex(binding.wrappedValue))
                .frame(width: 16, height: 16)
        }
    }

    private var colorBinding: Binding<Color> {
        Binding<Color>(
            get: { colorFromHex(binding.wrappedValue) },
            set: { newColor in
                binding.wrappedValue = hexFromColor(newColor)
            }
        )
    }

    private func hexFromColor(_ color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = Int((nsColor.redComponent * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Convenience: SlopTimeZonePicker

/// A menu `Picker` of common timezones in interactive mode, abbreviation `Text` in export.
///
/// ```swift
/// SlopTimeZonePicker(identifier: $clock.timezoneID)
/// ```
public struct SlopTimeZonePicker: View {
    private let binding: Binding<String>

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(identifier: Binding<String>) {
        self.binding = identifier
    }

    public var body: some View {
        if renderTarget == .interactive {
            Picker("Timezone", selection: binding) {
                ForEach(Self.commonTimezones, id: \.id) { tz in
                    Text(tz.label).tag(tz.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
        } else {
            let tz = TimeZone(identifier: binding.wrappedValue) ?? TimeZone(identifier: "UTC")!
            Text(tz.abbreviation() ?? binding.wrappedValue)
                .font(.caption)
        }
    }

    // MARK: - Timezone List

    private struct TZEntry: Identifiable {
        let id: String
        let label: String
    }

    private static let commonTimezones: [TZEntry] = [
        // UTC
        TZEntry(id: "UTC", label: "UTC"),
        // Americas
        TZEntry(id: "America/New_York", label: "New York (ET)"),
        TZEntry(id: "America/Chicago", label: "Chicago (CT)"),
        TZEntry(id: "America/Denver", label: "Denver (MT)"),
        TZEntry(id: "America/Los_Angeles", label: "Los Angeles (PT)"),
        TZEntry(id: "America/Anchorage", label: "Anchorage (AKT)"),
        TZEntry(id: "Pacific/Honolulu", label: "Honolulu (HT)"),
        TZEntry(id: "America/Toronto", label: "Toronto (ET)"),
        TZEntry(id: "America/Vancouver", label: "Vancouver (PT)"),
        TZEntry(id: "America/Mexico_City", label: "Mexico City (CST)"),
        TZEntry(id: "America/Sao_Paulo", label: "S\u{e3}o Paulo (BRT)"),
        TZEntry(id: "America/Argentina/Buenos_Aires", label: "Buenos Aires (ART)"),
        TZEntry(id: "America/Bogota", label: "Bogot\u{e1} (COT)"),
        TZEntry(id: "America/Lima", label: "Lima (PET)"),
        TZEntry(id: "America/Santiago", label: "Santiago (CLT)"),
        // Europe
        TZEntry(id: "Europe/London", label: "London (GMT/BST)"),
        TZEntry(id: "Europe/Paris", label: "Paris (CET)"),
        TZEntry(id: "Europe/Berlin", label: "Berlin (CET)"),
        TZEntry(id: "Europe/Madrid", label: "Madrid (CET)"),
        TZEntry(id: "Europe/Rome", label: "Rome (CET)"),
        TZEntry(id: "Europe/Amsterdam", label: "Amsterdam (CET)"),
        TZEntry(id: "Europe/Zurich", label: "Zurich (CET)"),
        TZEntry(id: "Europe/Moscow", label: "Moscow (MSK)"),
        TZEntry(id: "Europe/Istanbul", label: "Istanbul (TRT)"),
        TZEntry(id: "Europe/Athens", label: "Athens (EET)"),
        TZEntry(id: "Europe/Warsaw", label: "Warsaw (CET)"),
        // Middle East / Africa
        TZEntry(id: "Asia/Dubai", label: "Dubai (GST)"),
        TZEntry(id: "Asia/Jerusalem", label: "Jerusalem (IST)"),
        TZEntry(id: "Africa/Cairo", label: "Cairo (EET)"),
        TZEntry(id: "Africa/Johannesburg", label: "Johannesburg (SAST)"),
        TZEntry(id: "Africa/Lagos", label: "Lagos (WAT)"),
        // Asia
        TZEntry(id: "Asia/Kolkata", label: "Mumbai (IST)"),
        TZEntry(id: "Asia/Karachi", label: "Karachi (PKT)"),
        TZEntry(id: "Asia/Dhaka", label: "Dhaka (BDT)"),
        TZEntry(id: "Asia/Bangkok", label: "Bangkok (ICT)"),
        TZEntry(id: "Asia/Jakarta", label: "Jakarta (WIB)"),
        TZEntry(id: "Asia/Shanghai", label: "Shanghai (CST)"),
        TZEntry(id: "Asia/Hong_Kong", label: "Hong Kong (HKT)"),
        TZEntry(id: "Asia/Taipei", label: "Taipei (CST)"),
        TZEntry(id: "Asia/Tokyo", label: "Tokyo (JST)"),
        TZEntry(id: "Asia/Seoul", label: "Seoul (KST)"),
        TZEntry(id: "Asia/Singapore", label: "Singapore (SGT)"),
        TZEntry(id: "Asia/Manila", label: "Manila (PHT)"),
        // Oceania
        TZEntry(id: "Australia/Sydney", label: "Sydney (AEST)"),
        TZEntry(id: "Australia/Melbourne", label: "Melbourne (AEST)"),
        TZEntry(id: "Australia/Perth", label: "Perth (AWST)"),
        TZEntry(id: "Pacific/Auckland", label: "Auckland (NZST)"),
        TZEntry(id: "Pacific/Fiji", label: "Fiji (FJT)"),
    ]
}
