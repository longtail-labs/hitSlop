import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct MediaReviewEntry: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Title") var title: String = ""
    @Field("Media Type", options: ["Movie", "TV", "Book", "Music", "Game", "Podcast"]) var mediaType: String = "Movie"
    @Field("Icon") var icon: String = ""
    @Field("Date Consumed") var dateConsumed: Date = .now
    @Field("Rating") var rating: Double = 0
    @Field("Short Note") var shortNote: String = ""
    @Field("Poster") var poster: TemplateImage = TemplateImage("")
}

@SlopData
public struct MediaReviewData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Media Log"

    @SlopKit.Section("Entries")
    @Field("Entries") var entries: [MediaReviewEntry] = MediaReviewData.defaultEntries

    var averageRating: Double {
        let rated = entries.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return rated.reduce(0) { $0 + $1.rating } / Double(rated.count)
    }

    var totalEntries: Int { entries.count }

    var sortedEntries: [MediaReviewEntry] {
        entries.sorted { $0.dateConsumed > $1.dateConsumed }
    }
}

extension MediaReviewData {
    static var defaultEntries: [MediaReviewEntry] {
        func entry(_ title: String, _ type: String, _ daysAgo: Int, _ rating: Double, _ note: String) -> MediaReviewEntry {
            var e = MediaReviewEntry()
            e.title = title
            e.mediaType = type
            e.dateConsumed = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            e.rating = rating
            e.shortNote = note
            return e
        }
        return [
            entry("Dune: Part Two", "Movie", 3, 5, "Stunning visuals and faithful adaptation"),
            entry("Severance S2", "TV", 7, 4, "Mind-bending as ever"),
            entry("Shogun", "TV", 14, 5, "Best historical drama in years"),
            entry("Hades II", "Game", 5, 4, "Early access but already polished"),
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.media-review",
    name: "Media Review",
    description: "Log and rate movies, TV, books, music, games, and podcasts.",
    version: "1.0.0",
    width: 380, height: 560,
    minWidth: 320, minHeight: 400,
    shape: .roundedRect(radius: 16),
    theme: "studio-noir",
    alwaysOnTop: true,
    categories: ["media"]
)
struct MediaReviewView: View {
    @TemplateData var data: MediaReviewData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    @State private var typeFilter: String = "All"

    private static let allTypes = ["All", "Movie", "TV", "Book", "Music", "Game", "Podcast"]

    private var filteredEntries: [MediaReviewEntry] {
        if typeFilter == "All" { return data.entries }
        return data.entries.filter { $0.mediaType == typeFilter }
    }

    private func typeIcon(for type: String) -> String {
        switch type {
        case "Movie": return "film"
        case "TV": return "tv"
        case "Book": return "book"
        case "Music": return "music.note"
        case "Game": return "gamecontroller"
        case "Podcast": return "mic"
        default: return "star"
        }
    }

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    SlopTextField("Title", text: $data.title)
                        .font(theme.title(size: 22))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    StatBadge(count: data.totalEntries, label: "Logged", tint: theme.accent)
                }

                if data.averageRating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(theme.font(size: 12))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f avg", data.averageRating))
                            .font(theme.font(size: 12, weight: .medium))
                            .foregroundStyle(theme.secondary)
                    }
                }

                ThemeDivider()

                // Filter chips
                SlopInteractiveOnly {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Self.allTypes, id: \.self) { type in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        typeFilter = type
                                    }
                                } label: {
                                    Text(type)
                                        .font(.caption2)
                                        .fontWeight(typeFilter == type ? .semibold : .regular)
                                        .foregroundStyle(typeFilter == type ? .white : theme.foreground)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(typeFilter == type ? theme.accent : theme.surface)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Entries
                if data.entries.isEmpty {
                    EmptyState(icon: "film.stack", title: "No entries yet", subtitle: "Add your first media review")
                }

                ForEach(filteredEntries.map(\.id), id: \.self) { entryId in
                    if let idx = data.entries.firstIndex(where: { $0.id == entryId }) {
                        mediaRow(entry: $data.entries[idx])
                    }
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Entry") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.entries.append(MediaReviewEntry())
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    private func mediaRow(entry: Binding<MediaReviewEntry>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Poster thumbnail
            Group {
                if entry.wrappedValue.poster.path.isEmpty {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.surface)
                        .frame(width: 44, height: 62)
                        .overlay(
                            Group {
                                if !entry.wrappedValue.icon.isEmpty {
                                    Text(entry.wrappedValue.icon)
                                        .font(.system(size: 24))
                                } else {
                                    Image(systemName: typeIcon(for: entry.wrappedValue.mediaType))
                                        .font(theme.font(size: 14))
                                        .foregroundStyle(theme.secondary.opacity(0.4))
                                }
                            }
                        )
                        .overlay {
                            if renderTarget == .interactive {
                                SlopImage(image: entry.poster, placeholder: "")
                                    .frame(width: 44, height: 62)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .opacity(0.01)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if renderTarget == .interactive && entry.wrappedValue.poster.path.isEmpty {
                                SlopEmojiPicker(entry.icon)
                                    .font(.system(size: 12))
                                    .offset(x: 12, y: -12)
                            }
                        }
                } else {
                    SlopImage(image: entry.poster, placeholder: "Poster")
                        .frame(width: 44, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    SlopTextField("Title", text: entry.title)
                        .font(theme.font(size: 13, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    SlopInteractiveOnly {
                        RemoveButton {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.entries.removeAll { $0.id == entry.id }
                            }
                        }
                    }
                }

                HStack(spacing: 6) {
                    if renderTarget == .interactive {
                        Picker("", selection: entry.mediaType) {
                            Text("Movie").tag("Movie")
                            Text("TV").tag("TV")
                            Text("Book").tag("Book")
                            Text("Music").tag("Music")
                            Text("Game").tag("Game")
                            Text("Podcast").tag("Podcast")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.mini)
                    } else {
                        StatusBadge(entry.wrappedValue.mediaType)
                    }

                    SlopEditable(entry.dateConsumed) { value in
                        Text(value, style: .date)
                            .font(theme.font(size: 10))
                            .foregroundStyle(theme.secondary)
                    } editor: { $value in
                        DatePicker("", selection: $value, displayedComponents: .date)
                            .labelsHidden()
                    }
                }

                // Star rating
                HStack(spacing: 2) {
                    SlopInteractiveOnly {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    entry.wrappedValue.rating = Double(star)
                                }
                            } label: {
                                Image(systemName: star <= Int(entry.wrappedValue.rating) ? "star.fill" : "star")
                                    .font(theme.font(size: 11))
                                    .foregroundStyle(star <= Int(entry.wrappedValue.rating) ? Color.yellow : theme.secondary.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if renderTarget != .interactive {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(entry.wrappedValue.rating) ? "star.fill" : "star")
                                .font(theme.font(size: 11))
                                .foregroundStyle(star <= Int(entry.wrappedValue.rating) ? Color.yellow : theme.secondary.opacity(0.3))
                        }
                    }
                }

                if !entry.wrappedValue.shortNote.isEmpty || renderTarget == .interactive {
                    SlopTextField("Quick note...", text: entry.shortNote)
                        .font(theme.font(size: 11))
                        .foregroundStyle(theme.secondary.opacity(0.8))
                }
            }
        }
        .padding(10)
        .background(theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

