import SwiftUI
import EmojiKit

/// A native emoji picker in interactive mode, static emoji text in export.
///
/// ```swift
/// SlopEmojiPicker($data.emoji)
///     .font(.system(size: 24))
/// ```
public struct SlopEmojiPicker: View {
    private let binding: Binding<String>
    private let categories: [EmojiCategory]

    @Environment(\.slopRenderTarget) private var renderTarget
    @Environment(\.slopTheme) private var theme
    @State private var showPicker = false
    @State private var searchQuery = ""
    @AppStorage("slopRecentEmojis") private var recentEmojisData = ""

    public init(
        _ binding: Binding<String>,
        categories: [EmojiCategory] = []
    ) {
        self.binding = binding
        self.categories = categories
    }

    public var body: some View {
        if renderTarget == .interactive {
            Button {
                showPicker.toggle()
            } label: {
                Text(binding.wrappedValue.isEmpty ? "🔍" : binding.wrappedValue)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .popover(isPresented: $showPicker) {
                VStack(spacing: 0) {
                    // Search field
                    TextField("Search emojis...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .padding(12)

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 32), spacing: 4)], spacing: 4) {
                            ForEach(filteredEmojis, id: \.char) { emoji in
                                Button {
                                    selectEmoji(emoji.char)
                                } label: {
                                    Text(emoji.char)
                                        .font(.system(size: 24))
                                }
                                .buttonStyle(.plain)
                                .frame(width: 32, height: 32)
                                .help(emoji.localizedName)
                            }
                        }
                        .padding(8)
                    }
                    .frame(width: 320, height: 300)
                }
                .background(theme.background)
            }
        } else {
            Text(binding.wrappedValue)
        }
    }

    private var filteredEmojis: [Emoji] {
        // Get base emoji list from categories or all emojis
        let baseEmojis: [Emoji]
        if categories.isEmpty {
            baseEmojis = Emoji.all
        } else {
            baseEmojis = categories.flatMap { $0.emojis }
        }

        // Apply search filter
        let searchFiltered = searchQuery.isEmpty
            ? baseEmojis
            : baseEmojis.filter { emoji in
                emoji.localizedName.localizedCaseInsensitiveContains(searchQuery)
            }

        // Combine recent emojis with search results (avoid duplicates)
        if searchQuery.isEmpty && !recentEmojis.isEmpty {
            let recentChars = Set(recentEmojis.map(\.char))
            let remaining = searchFiltered.filter { !recentChars.contains($0.char) }
            return recentEmojis + remaining
        }

        return searchFiltered
    }

    private var recentEmojis: [Emoji] {
        let chars = recentEmojisData.split(separator: ",").map(String.init)
        return chars.compactMap { char in
            Emoji.all.first { $0.char == char }
        }
    }

    private func selectEmoji(_ char: String) {
        binding.wrappedValue = char
        showPicker = false

        // Update recent emojis
        var recent = recentEmojisData.split(separator: ",").map(String.init)
        recent.removeAll { $0 == char }
        recent.insert(char, at: 0)
        recentEmojisData = recent.prefix(20).joined(separator: ",")
    }
}

// MARK: - Convenience: Category presets

public extension SlopEmojiPicker {
    /// Filter to travel-related emojis
    func travelEmojis() -> Self {
        SlopEmojiPicker(
            binding,
            categories: [.travelAndPlaces]
        )
    }

    /// Filter to food-related emojis
    func foodEmojis() -> Self {
        SlopEmojiPicker(
            binding,
            categories: [.foodAndDrink]
        )
    }

    /// Filter to activity-related emojis
    func activityEmojis() -> Self {
        SlopEmojiPicker(
            binding,
            categories: [.activity]
        )
    }

    /// Filter to object-related emojis
    func objectEmojis() -> Self {
        SlopEmojiPicker(
            binding,
            categories: [.objects]
        )
    }

    /// Filter to smiley and people emojis
    func smileysAndPeople() -> Self {
        SlopEmojiPicker(
            binding,
            categories: [.smileysAndPeople]
        )
    }
}
