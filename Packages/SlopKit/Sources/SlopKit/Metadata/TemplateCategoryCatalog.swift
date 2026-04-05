import Foundation

public enum TemplateCategoryCatalog {
    public struct Entry: Identifiable, Sendable, Hashable {
        public let id: String
        public let label: String
        public let icon: String
        public let summary: String
        public let sortOrder: Int
        public let aliases: Set<String>

        public init(
            id: String,
            label: String,
            icon: String,
            summary: String,
            sortOrder: Int,
            aliases: Set<String> = []
        ) {
            self.id = id
            self.label = label
            self.icon = icon
            self.summary = summary
            self.sortOrder = sortOrder
            self.aliases = aliases
        }
    }

    public static let allEntries: [Entry] = [
        Entry(
            id: "popular",
            label: "Popular",
            icon: "star.fill",
            summary: "Most commonly used templates.",
            sortOrder: -1,
            aliases: ["popular", "favorites"]
        ),
        Entry(
            id: "personal",
            label: "Personal",
            icon: "sun.max",
            summary: "Daily life, planning, home, and self-management.",
            sortOrder: 0,
            aliases: ["life", "personal"]
        ),
        Entry(
            id: "work",
            label: "Work",
            icon: "briefcase",
            summary: "Projects, planning, meetings, operations, and execution.",
            sortOrder: 1,
            aliases: ["business", "productivity", "work"]
        ),
        Entry(
            id: "finance",
            label: "Finance",
            icon: "chart.line.uptrend.xyaxis",
            summary: "Budgets, net worth, portfolios, debt, and cash flow.",
            sortOrder: 2,
            aliases: ["finance", "money"]
        ),
        Entry(
            id: "health",
            label: "Health",
            icon: "heart.text.square",
            summary: "Symptoms, fitness, habits, medication, and recovery.",
            sortOrder: 3,
            aliases: ["fitness", "health", "wellness"]
        ),
        Entry(
            id: "learning",
            label: "Learning",
            icon: "graduationcap",
            summary: "Study systems, classes, notes, and repetition.",
            sortOrder: 4,
            aliases: ["education", "learning", "study"]
        ),
        Entry(
            id: "creative",
            label: "Creative",
            icon: "sparkles",
            summary: "Writing, design, storytelling, visuals, and ideation.",
            sortOrder: 5,
            aliases: ["creative", "design", "marketing", "presentations", "writing"]
        ),
        Entry(
            id: "ai-content",
            label: "AI Content",
            icon: "wand.and.sparkles",
            summary: "Review, organize, and prepare AI-generated photos and videos.",
            sortOrder: 6,
            aliases: ["ai", "ai-content", "content", "generation"]
        ),
        Entry(
            id: "media",
            label: "Media",
            icon: "play.rectangle",
            summary: "Playback, playlists, screenshots, and media control.",
            sortOrder: 7,
            aliases: ["media"]
        ),
        Entry(
            id: "legal",
            label: "Legal",
            icon: "doc.text.magnifyingglass",
            summary: "Contracts, agreements, NDAs, and legal documents.",
            sortOrder: 8,
            aliases: ["legal", "contracts"]
        ),
        Entry(
            id: "travel",
            label: "Travel",
            icon: "airplane.departure",
            summary: "Trip planning, packing, and travel logistics.",
            sortOrder: 9,
            aliases: ["travel", "trips"]
        ),
        Entry(
            id: "events",
            label: "Events",
            icon: "party.popper",
            summary: "Weddings, parties, and event coordination.",
            sortOrder: 10,
            aliases: ["events", "social"]
        ),
    ]

    private static let entriesByID: [String: Entry] = Dictionary(
        uniqueKeysWithValues: allEntries.map { ($0.id, $0) }
    )

    private static let aliasToID: [String: String] = {
        var aliases: [String: String] = [:]
        for entry in allEntries {
            aliases[entry.id] = entry.id
            for alias in entry.aliases {
                aliases[alias] = entry.id
            }
        }
        return aliases
    }()

    public static func canonicalID(for rawValue: String?) -> String? {
        guard let normalized = normalize(rawValue), !normalized.isEmpty else {
            return nil
        }
        return aliasToID[normalized] ?? normalized
    }

    public static func entry(for rawValue: String?) -> Entry {
        guard let id = canonicalID(for: rawValue) else {
            return fallbackEntry(id: "other", rawValue: "other")
        }
        return entriesByID[id] ?? fallbackEntry(id: id, rawValue: rawValue ?? id)
    }

    public static func sorted(_ rawValues: some Sequence<String>) -> [Entry] {
        let unique = Set(rawValues.compactMap(canonicalID(for:)))
        return unique
            .map { entriesByID[$0] ?? fallbackEntry(id: $0, rawValue: $0) }
            .sorted { lhs, rhs in
                categorySort(lhs: lhs, rhs: rhs)
            }
    }

    public static func categorySort(lhs: Entry, rhs: Entry) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        if lhs.label != rhs.label {
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
        return lhs.id < rhs.id
    }

    private static func fallbackEntry(id: String, rawValue: String) -> Entry {
        Entry(
            id: id,
            label: prettify(rawValue),
            icon: "folder",
            summary: "Miscellaneous templates.",
            sortOrder: 99
        )
    }

    private static func normalize(_ rawValue: String?) -> String? {
        rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func prettify(_ value: String) -> String {
        value
            .split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " })
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
