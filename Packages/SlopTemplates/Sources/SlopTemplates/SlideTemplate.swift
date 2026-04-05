import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct SlideData {
    @SlopKit.Section("Content")
    @Field("Title") var title: String = "Slide Title"
    @Field("Subtitle") var subtitle: String = ""
    @Field("Body") var body: String = ""
    @Field("Layout", options: ["titleOnly", "titleBody", "titleImage", "quote", "blank", "twoColumn", "bigNumber", "sectionHeader", "agenda", "statsDashboard", "imageBackground", "comparison", "contact"])
    var layout: String = "titleBody"

    @SlopKit.Section("Style")
    @Field("Accent Color") var accentColor: String = "#4A90D9"

}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.slide",
    name: "Slide",
    description: "Build a single presentation slide with a title, body, and strong visual layout.",
    version: "1.0.0",
    width: 960, height: 540,
    minWidth: 640, minHeight: 360,
    shape: .roundedRect(radius: 12),
    alwaysOnTop: true,
    categories: ["presentations"]
)
struct SlideView: View {
    @TemplateData var data: SlideData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        ZStack {
            theme.background

            Group {
                switch data.layout {
                case "titleOnly": titleOnlyLayout
                case "titleImage": titleImageLayout
                case "quote": quoteLayout
                case "blank": blankLayout
                case "twoColumn": twoColumnLayout
                case "bigNumber": bigNumberLayout
                case "sectionHeader": sectionHeaderLayout
                case "agenda": agendaLayout
                case "statsDashboard": statsDashboardLayout
                case "imageBackground": imageBackgroundLayout
                case "comparison": comparisonLayout
                case "contact": contactLayout
                default: titleBodyLayout
                }
            }
            .padding(40)

            // Top accent band
            if ["titleBody", "titleOnly", "twoColumn", "agenda", "comparison"].contains(data.layout) {
                VStack {
                    Rectangle()
                        .fill(colorFromHex(data.accentColor))
                        .frame(height: 6)
                    Spacer()
                }
            }

            // Bottom accent bar
            if data.layout != "blank" && data.layout != "quote" && data.layout != "imageBackground" {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(colorFromHex(data.accentColor))
                        .frame(height: 5)
                }
            }
        }
    }

    // MARK: - Layouts

    private var titleOnlyLayout: some View {
        VStack(spacing: 8) {
            Spacer()
            SlopTextField("Title", text: $data.title)
                .font(theme.titleFont)
                .foregroundStyle(theme.foreground)
                .multilineTextAlignment(.center)
            SlopTextField("Subtitle", text: $data.subtitle)
                .font(theme.font(size: 20))
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var titleBodyLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            SlopTextField("Title", text: $data.title)
                .font(theme.titleFont)
                .foregroundStyle(theme.foreground)
            SlopTextField("Subtitle", text: $data.subtitle)
                .font(theme.font(size: 16))
                .foregroundStyle(theme.secondary)

            Rectangle()
                .fill(colorFromHex(data.accentColor))
                .frame(height: 1.5)
                .padding(.vertical, 4)

            SlopEditable($data.body) { value in
                Text(value)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.foreground.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            } editor: { binding in
                TextEditor(text: binding)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.foreground.opacity(0.9))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 40)
            }
            Spacer(minLength: 0)
        }
    }

    private var titleImageLayout: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                SlopTextField("Title", text: $data.title)
                    .font(theme.titleFont)
                    .foregroundStyle(theme.foreground)
                SlopEditable($data.body) { value in
                    Text(value)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                } editor: { binding in
                    TextEditor(text: binding)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 40)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            RoundedRectangle(cornerRadius: 8)
                .fill(theme.surface)
                .overlay(
                    Image(systemName: "photo")
                        .font(theme.font(size: 24))
                        .foregroundStyle(theme.secondary.opacity(0.4))
                )
                .frame(maxWidth: .infinity)
        }
    }

    private var quoteLayout: some View {
        VStack(spacing: 16) {
            Spacer()
            SlopEditable($data.body) { value in
                Text("\u{201C}\(value)\u{201D}")
                    .font(theme.font(size: 28, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } editor: { binding in
                TextEditor(text: binding)
                    .font(theme.font(size: 28, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .multilineTextAlignment(.center)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 40)
            }
            SlopTextField("Attribution", text: $data.subtitle)
                .font(theme.font(size: 16, weight: .semibold))
                .foregroundStyle(colorFromHex(data.accentColor))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var blankLayout: some View {
        VStack {
            Spacer()
            SlopEditable($data.body) { value in
                Text(value)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.foreground.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            } editor: { binding in
                TextEditor(text: binding)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.foreground.opacity(0.9))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 40)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var twoColumnLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            SlopTextField("Title", text: $data.title)
                .font(theme.titleFont)
                .foregroundStyle(theme.foreground)

            Rectangle()
                .fill(colorFromHex(data.accentColor))
                .frame(height: 1.5)
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 0) {
                SlopEditable($data.subtitle) { value in
                    Text(value)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                } editor: { binding in
                    TextEditor(text: binding)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 40)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(colorFromHex(data.accentColor))
                    .frame(width: 2)
                    .padding(.horizontal, 12)

                SlopEditable($data.body) { value in
                    Text(value)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                } editor: { binding in
                    TextEditor(text: binding)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 40)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
    }

    private var bigNumberLayout: some View {
        VStack(spacing: 8) {
            Spacer()
            SlopTextField("0", text: $data.title)
                .font(theme.title(size: 72))
                .foregroundStyle(colorFromHex(data.accentColor))
                .multilineTextAlignment(.center)
            SlopTextField("Subtitle", text: $data.subtitle)
                .font(theme.font(size: 20))
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var sectionHeaderLayout: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 16) {
                Rectangle()
                    .fill(colorFromHex(data.accentColor))
                    .frame(height: 2)
                SlopTextField("Section Title", text: $data.title)
                    .font(theme.titleFont)
                    .foregroundStyle(theme.foreground)
                    .fixedSize(horizontal: true, vertical: false)
                Rectangle()
                    .fill(colorFromHex(data.accentColor))
                    .frame(height: 2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var agendaLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            SlopTextField("Title", text: $data.title)
                .font(theme.titleFont)
                .foregroundStyle(theme.foreground)

            Rectangle()
                .fill(colorFromHex(data.accentColor))
                .frame(height: 1.5)
                .padding(.vertical, 4)

            let lines = data.body.split(separator: "\n", omittingEmptySubsequences: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(theme.font(size: 16, weight: .bold))
                            .foregroundStyle(colorFromHex(data.accentColor))
                            .frame(width: 24)
                        Text(String(line))
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.foreground.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var statsDashboardLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            SlopTextField("Title", text: $data.title)
                .font(theme.titleFont)
                .foregroundStyle(theme.foreground)

            Rectangle()
                .fill(colorFromHex(data.accentColor))
                .frame(height: 1.5)
                .padding(.vertical, 4)

            let stats = parseStats()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(stats.indices, id: \.self) { index in
                    VStack(spacing: 4) {
                        Text(stats[index].value)
                            .font(theme.title(size: 36))
                            .foregroundStyle(colorFromHex(data.accentColor))
                        Text(stats[index].label)
                            .font(theme.font(size: 14))
                            .foregroundStyle(theme.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.surface)
                    .cornerRadius(8)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var imageBackgroundLayout: some View {
        ZStack {
            LinearGradient(
                colors: [colorFromHex(data.accentColor).opacity(0.7), colorFromHex(data.accentColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                SlopTextField("Title", text: $data.title)
                    .font(theme.titleFont)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                SlopTextField("Subtitle", text: $data.subtitle)
                    .font(theme.font(size: 20))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            }
            .padding(.horizontal, 40)
        }
    }

    private var comparisonLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            SlopTextField("Title", text: $data.title)
                .font(theme.titleFont)
                .foregroundStyle(theme.foreground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(colorFromHex(data.accentColor))
                .frame(height: 1.5)
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 0) {
                SlopEditable($data.subtitle) { value in
                    Text(value)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                } editor: { binding in
                    TextEditor(text: binding)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 40)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("VS")
                        .font(theme.title(size: 24))
                        .foregroundStyle(colorFromHex(data.accentColor))
                }
                .frame(width: 60)

                SlopEditable($data.body) { value in
                    Text(value)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                } editor: { binding in
                    TextEditor(text: binding)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.foreground.opacity(0.9))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 40)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
    }

    private var contactLayout: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 4) {
                Rectangle()
                    .fill(colorFromHex(data.accentColor))
                    .frame(width: 60, height: 3)

                SlopTextField("Name", text: $data.title)
                    .font(theme.title(size: 32, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                SlopTextField("Role / Position", text: $data.subtitle)
                    .font(theme.font(size: 18))
                    .foregroundStyle(theme.secondary)
                    .multilineTextAlignment(.center)
            }

            SlopEditable($data.body) { value in
                Text(value)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.foreground.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } editor: { binding in
                TextEditor(text: binding)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.foreground.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 40)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func parseStats() -> [(value: String, label: String)] {
        let fields = [data.title, data.subtitle, data.body]
        var stats: [(value: String, label: String)] = []

        for field in fields {
            let parts = field.split(separator: "|", maxSplits: 1)
            if parts.count == 2 {
                stats.append((value: String(parts[0]).trimmingCharacters(in: .whitespaces),
                             label: String(parts[1]).trimmingCharacters(in: .whitespaces)))
            }
        }

        // Fill with defaults if needed
        while stats.count < 4 {
            stats.append((value: "0", label: "Stat \(stats.count + 1)"))
        }

        return Array(stats.prefix(4))
    }

}
