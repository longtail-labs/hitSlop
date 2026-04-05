import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct PromptEntry: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Prompt") var prompt: String = ""
    @Field("Result") var output: TemplateImage = TemplateImage("")
    @Field("Model") var model: String = "gemini-2.5-flash"
    @Field("Rating") var rating: Double = 0
    @Field("Notes") var notes: String = ""
}

@SlopData
public struct PromptLabData {
    @Field("Title") var title: String = "Prompt Lab"
    @Field("Entries") var entries: [PromptEntry] = PromptLabData.defaultEntries

    var averageRating: Double {
        let rated = entries.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return rated.reduce(0) { $0 + $1.rating } / Double(rated.count)
    }
}

extension PromptLabData {
    static var defaultEntries: [PromptEntry] {
        func entry(_ prompt: String, _ model: String) -> PromptEntry {
            var e = PromptEntry()
            e.prompt = prompt
            e.model = model
            return e
        }
        return [
            entry("A cozy reading nook with warm lighting, watercolor style", "gemini-2.5-flash"),
            entry("Product photo of a ceramic mug, studio lighting, minimal", "dall-e-3"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.prompt-lab",
    name: "Prompt Lab",
    description: "Track prompts paired with their AI-generated results, ratings, and model info.",
    version: "1.0.0",
    width: 580, height: 650,
    minWidth: 460, minHeight: 500,
    shape: .roundedRect(radius: 18),
    alwaysOnTop: true,
    categories: ["ai-content"]
)
struct PromptLabView: View {
    @TemplateData var data: PromptLabData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SlopTextField("Lab Title", text: $data.title)
                        .font(theme.title(size: 24))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    StatBadge(count: data.entries.count, label: "prompts", tint: theme.accent)
                }

                if data.averageRating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.accent)
                        Text(String(format: "%.1f avg", data.averageRating))
                            .font(theme.mono(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondary)
                    }
                }

                ThemeDivider()

                ForEach($data.entries) { $entry in
                    promptCard(entry: $entry)
                }

                AddItemButton("Add Prompt") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.entries.append(PromptEntry())
                    }
                }
            }
            .padding(20)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func promptCard(entry: Binding<PromptEntry>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Prompt text side
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROMPT")
                        .font(theme.mono(size: 9, weight: .bold))
                        .foregroundStyle(theme.secondary)

                    SlopTextField("Describe what to generate…", text: entry.prompt)
                        .font(theme.font(size: 12))
                        .foregroundStyle(theme.foreground)

                    HStack(spacing: 4) {
                        Text("MODEL")
                            .font(theme.mono(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondary)
                        SlopTextField("model", text: entry.model)
                            .font(theme.mono(size: 11))
                            .foregroundStyle(theme.accent.opacity(0.8))
                    }

                    starRating(value: entry.rating)

                    SlopTextField("Notes…", text: entry.notes)
                        .font(theme.font(size: 10))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Result image side
                VStack {
                    SlopImage(image: entry.output, placeholder: "Drop result")
                        .frame(width: 160, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack {
                Spacer()
                RemoveButton {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.entries.removeAll { $0.id == entry.wrappedValue.id }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surface)
        )
    }

    @ViewBuilder
    private func starRating(value: Binding<Double>) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                SlopInteractiveOnly {
                    Button {
                        value.wrappedValue = Double(star)
                    } label: {
                        Image(systemName: Double(star) <= value.wrappedValue ? "star.fill" : "star")
                            .font(theme.font(size: 10))
                            .foregroundStyle(Double(star) <= value.wrappedValue ? theme.accent : theme.secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
