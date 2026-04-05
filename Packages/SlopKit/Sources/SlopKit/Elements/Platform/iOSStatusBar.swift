import SwiftUI

/// A realistic iOS status bar mock component.
///
/// Displays time, cellular signal, WiFi, and battery indicators in the iOS style.
/// Use this at the top of iPhone mockup templates.
///
/// ```swift
/// VStack(spacing: 0) {
///     iOSStatusBar(time: "9:41", style: .dark)
///     // ... rest of content
/// }
/// ```
public struct iOSStatusBar: View {
    private let time: String
    private let style: Style

    public enum Style {
        case light
        case dark
    }

    public init(time: String = "9:41", style: Style = .dark) {
        self.time = time
        self.style = style
    }

    public var body: some View {
        HStack {
            Text(time)
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Image(systemName: "cellularbars")
                .font(.system(size: 15, weight: .semibold))
            Image(systemName: "wifi")
                .font(.system(size: 15, weight: .semibold))
            Image(systemName: "battery.100")
                .font(.system(size: 22))
        }
        .foregroundStyle(style == .dark ? .black : .white)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(height: 44)
    }
}
