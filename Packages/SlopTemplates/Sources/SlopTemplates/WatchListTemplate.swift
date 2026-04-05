import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct WatchListItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Title") var title: String = ""
    @Field("Type", options: ["Movie", "TV Show", "Documentary", "Anime"]) var type: String = "Movie"
    @Field("Poster") var poster: TemplateImage = TemplateImage("")
    @Field("Status", options: ["Want to Watch", "Watching", "Finished", "Dropped"]) var status: String = "Want to Watch"
    @Field("Season") var season: Double = 1
    @Field("Episode") var episode: Double = 1
    @Field("Rating") var rating: Double = 0
    @Field("Notes") var notes: String = ""
}

@SlopData
public struct WatchListData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Watch List"
    @Field("Subtitle") var subtitle: String = ""

    @SlopKit.Section("Items")
    @Field("Items") var items: [WatchListItem] = WatchListData.defaultItems

    var watchingCount: Int { items.filter { $0.status == "Watching" }.count }
    var finishedCount: Int { items.filter { $0.status == "Finished" }.count }
    var wantToWatchCount: Int { items.filter { $0.status == "Want to Watch" }.count }

    var sortedItems: [WatchListItem] {
        let order: [String: Int] = ["Watching": 0, "Want to Watch": 1, "Finished": 2, "Dropped": 3]
        return items.sorted { (order[$0.status] ?? 4) < (order[$1.status] ?? 4) }
    }
}

extension WatchListData {
    static var defaultItems: [WatchListItem] {
        func item(_ title: String, _ type: String, _ status: String, _ rating: Double = 0, season: Double = 1, episode: Double = 1) -> WatchListItem {
            var i = WatchListItem()
            i.title = title
            i.type = type
            i.status = status
            i.rating = rating
            i.season = season
            i.episode = episode
            return i
        }
        return [
            item("Severance", "TV Show", "Watching", season: 2, episode: 6),
            item("Shogun", "TV Show", "Finished", 5),
            item("Dune: Part Two", "Movie", "Finished", 5),
            item("Frieren", "Anime", "Watching", season: 1, episode: 18),
            item("The Brutalist", "Movie", "Want to Watch"),
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.watch-list",
    name: "Watch List",
    description: "Track movies, TV shows, documentaries, and anime with status and ratings.",
    version: "1.0.0",
    width: 400, height: 600,
    minWidth: 340, minHeight: 420,
    shape: .roundedRect(radius: 16),
    theme: "midnight-ink",
    alwaysOnTop: true,
    categories: ["media"]
)
struct WatchListView: View {
    @TemplateData var data: WatchListData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    @State private var statusFilter: String = "All"
    @State private var typeFilter: String = "All"

    private static let allStatuses = ["All", "Watching", "Want to Watch", "Finished", "Dropped"]
    private static let allTypes = ["All", "Movie", "TV Show", "Documentary", "Anime"]
    private static let statusCycle = ["Want to Watch", "Watching", "Finished", "Dropped"]

    private var filteredItems: [WatchListItem] {
        data.items.filter { item in
            (statusFilter == "All" || item.status == statusFilter) &&
            (typeFilter == "All" || item.type == typeFilter)
        }
    }

    private func nextStatus(_ current: String) -> String {
        let cycle = Self.statusCycle
        guard let idx = cycle.firstIndex(of: current) else { return cycle[0] }
        return cycle[(idx + 1) % cycle.count]
    }

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SlopTextField("Title", text: $data.title)
                            .font(theme.title(size: 22))
                            .foregroundStyle(theme.foreground)
                        if !data.subtitle.isEmpty || renderTarget == .interactive {
                            SlopTextField("Subtitle", text: $data.subtitle)
                                .font(theme.font(size: 13))
                                .foregroundStyle(theme.secondary)
                        }
                    }
                    Spacer()
                }

                // Stats
                HStack(spacing: 8) {
                    StatBadge(count: data.watchingCount, label: "Watching", tint: .blue)
                    StatBadge(count: data.wantToWatchCount, label: "Queued", tint: .orange)
                    StatBadge(count: data.finishedCount, label: "Done", tint: .green)
                }

                ThemeDivider()

                // Filter chips
                SlopInteractiveOnly {
                    VStack(alignment: .leading, spacing: 6) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Self.allStatuses, id: \.self) { status in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            statusFilter = status
                                        }
                                    } label: {
                                        Text(status)
                                            .font(.caption2)
                                            .fontWeight(statusFilter == status ? .semibold : .regular)
                                            .foregroundStyle(statusFilter == status ? .white : theme.foreground)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(statusFilter == status ? theme.accent : theme.surface)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
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
                }

                // Items
                if data.items.isEmpty {
                    EmptyState(icon: "tv", title: "Nothing here yet", subtitle: "Add something to watch")
                }

                ForEach(filteredItems.map(\.id), id: \.self) { itemId in
                    if let idx = data.items.firstIndex(where: { $0.id == itemId }) {
                        watchCard(item: $data.items[idx])
                    }
                }

                SlopInteractiveOnly {
                    AddItemButton("Add Item") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.items.append(WatchListItem())
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    private func watchCard(item: Binding<WatchListItem>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Poster
            Group {
                if item.wrappedValue.poster.path.isEmpty {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.surface)
                        .frame(width: 48, height: 68)
                        .overlay(
                            Image(systemName: item.wrappedValue.type == "Movie" ? "film" : "tv")
                                .font(theme.font(size: 16))
                                .foregroundStyle(theme.secondary.opacity(0.4))
                        )
                        .overlay {
                            if renderTarget == .interactive {
                                SlopImage(image: item.poster, placeholder: "")
                                    .frame(width: 48, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .opacity(0.01)
                            }
                        }
                } else {
                    SlopImage(image: item.poster, placeholder: "Poster")
                        .frame(width: 48, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    SlopTextField("Title", text: item.title)
                        .font(theme.font(size: 14, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    SlopInteractiveOnly {
                        RemoveButton {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.items.removeAll { $0.id == item.id }
                            }
                        }
                    }
                }

                HStack(spacing: 6) {
                    if renderTarget == .interactive {
                        Picker("", selection: item.type) {
                            Text("Movie").tag("Movie")
                            Text("TV Show").tag("TV Show")
                            Text("Documentary").tag("Documentary")
                            Text("Anime").tag("Anime")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.mini)
                    } else {
                        StatusBadge(item.wrappedValue.type)
                    }

                    SlopInteractiveOnly {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                item.wrappedValue.status = nextStatus(item.wrappedValue.status)
                            }
                        } label: {
                            StatusBadge(item.wrappedValue.status)
                        }
                        .buttonStyle(.plain)
                    }
                    if renderTarget != .interactive {
                        StatusBadge(item.wrappedValue.status)
                    }
                }

                // Season/Episode for TV Show and Anime when Watching
                if (item.wrappedValue.type == "TV Show" || item.wrappedValue.type == "Anime") && item.wrappedValue.status == "Watching" {
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Text("S")
                                .font(theme.font(size: 10))
                                .foregroundStyle(theme.secondary)
                            SlopNumberField("1", value: item.season, format: "%.0f")
                                .font(theme.font(size: 11, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 24)
                        }
                        HStack(spacing: 2) {
                            Text("E")
                                .font(theme.font(size: 10))
                                .foregroundStyle(theme.secondary)
                            SlopNumberField("1", value: item.episode, format: "%.0f")
                                .font(theme.font(size: 11, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 24)
                        }
                    }
                }

                // Star rating
                HStack(spacing: 2) {
                    SlopInteractiveOnly {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    item.wrappedValue.rating = Double(star)
                                }
                            } label: {
                                Image(systemName: star <= Int(item.wrappedValue.rating) ? "star.fill" : "star")
                                    .font(theme.font(size: 11))
                                    .foregroundStyle(star <= Int(item.wrappedValue.rating) ? Color.yellow : theme.secondary.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if renderTarget != .interactive {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(item.wrappedValue.rating) ? "star.fill" : "star")
                                .font(theme.font(size: 11))
                                .foregroundStyle(star <= Int(item.wrappedValue.rating) ? Color.yellow : theme.secondary.opacity(0.3))
                        }
                    }
                }

                if !item.wrappedValue.notes.isEmpty || renderTarget == .interactive {
                    SlopTextField("Notes...", text: item.notes)
                        .font(theme.font(size: 11))
                        .foregroundStyle(theme.secondary.opacity(0.8))
                }
            }
        }
        .padding(10)
        .background(theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

