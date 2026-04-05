import Foundation
import SwiftUI
import SlopKit

public enum ThemeCatalog {
    public enum Source: String, Sendable {
        case bundled
        case shared
        case user
    }

    public struct Entry: Identifiable, Sendable {
        public let id: String
        public let displayName: String
        public let group: String
        public let source: Source
        public let theme: SlopTheme
    }

    public struct Group: Identifiable, Sendable {
        public let id: String
        public let displayName: String
        public let entries: [Entry]
    }

    nonisolated(unsafe) private static var cache: [Entry]?

    public static func entries() -> [Entry] {
        if let cache {
            return cache
        }

        var merged: [String: Entry] = [:]
        for source in [Source.bundled, .shared, .user] {
            for entry in loadEntries(from: source) {
                merged[entry.id] = entry
            }
        }

        let sorted = merged.values.sorted { lhs, rhs in
            let leftGroup = groupRank(lhs.group)
            let rightGroup = groupRank(rhs.group)
            if leftGroup != rightGroup {
                return leftGroup < rightGroup
            }
            if lhs.displayName != rhs.displayName {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.id < rhs.id
        }
        cache = sorted
        return sorted
    }

    public static func resolve(_ id: String?) -> Entry? {
        let normalized = normalizedThemeID(id)
        return entries().first { $0.id == normalized }
    }

    public static func groups() -> [Group] {
        let grouped = Dictionary(grouping: entries(), by: \.group)
        return grouped.keys
            .sorted { lhs, rhs in groupRank(lhs) < groupRank(rhs) }
            .map { groupName in
                Group(
                    id: groupName.lowercased().replacingOccurrences(of: " ", with: "-"),
                    displayName: groupName,
                    entries: grouped[groupName] ?? []
                )
            }
    }

    public static func resolveTheme(_ id: String?) -> SlopTheme {
        resolve(id)?.theme ?? defaultTheme
    }

    /// Resolve a theme with package-local override support.
    /// Checks for a `.theme` file inside the package directory first,
    /// then falls back to the global catalog.
    public static func resolveTheme(_ id: String?, packageURL: URL?) -> SlopTheme {
        if let id, let packageURL,
           let theme = loadPackageTheme(named: id, from: packageURL) {
            return theme
        }
        return resolveTheme(id)
    }

    /// Load all `.theme` files from a package directory as picker entries.
    public static func packageEntries(from packageURL: URL?) -> [Entry] {
        guard let packageURL else { return [] }
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: packageURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url in
            guard url.pathExtension == "theme",
                  let data = try? Data(contentsOf: url),
                  let def = try? JSONDecoder().decode(ThemeFile.self, from: data),
                  let theme = def.toSlopTheme()
            else { return nil }
            let id = url.deletingPathExtension().lastPathComponent
            return Entry(
                id: id,
                displayName: def.displayName ?? prettify(id),
                group: "Document",
                source: .user,
                theme: theme
            )
        }
    }

    private static func loadPackageTheme(named id: String, from packageURL: URL) -> SlopTheme? {
        let url = packageURL.appendingPathComponent("\(id).theme")
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ThemeFile.self, from: data)
        else { return nil }
        return file.toSlopTheme()
    }

    public static func invalidateCache() {
        cache = nil
    }

    /// Save a theme to ~/.hitslop/themes/{id}.theme and invalidate cache.
    public static func saveUserTheme(_ file: ThemeFile, id: String) throws {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hitslop/themes")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(id).theme")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: url, options: .atomic)
        invalidateCache()
    }

    /// Delete a user theme by ID and invalidate cache.
    public static func deleteUserTheme(id: String) throws {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hitslop/themes/\(id).theme")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ThemeError.notFound(id)
        }
        try FileManager.default.removeItem(at: url)
        invalidateCache()
    }

    public enum ThemeError: LocalizedError {
        case notFound(String)

        public var errorDescription: String? {
            switch self {
            case .notFound(let id): "Theme not found: \(id)"
            }
        }
    }

    private static var defaultTheme: SlopTheme {
        SlopTheme(
            background: Color(red: 0.08, green: 0.09, blue: 0.12),
            foreground: Color(red: 0.95, green: 0.95, blue: 0.97),
            secondary: Color(red: 0.58, green: 0.61, blue: 0.67),
            accent: Color(red: 0.93, green: 0.72, blue: 0.30),
            surface: Color(red: 0.13, green: 0.15, blue: 0.20),
            divider: Color(red: 0.21, green: 0.24, blue: 0.31),
            titleFont: .custom("Didot", size: 24).weight(.bold),
            bodyFont: .custom("Avenir Next", size: 14),
            monoFont: .custom("Menlo", size: 12),
            bodyFontFamily: "Avenir Next",
            titleFontFamily: "Didot",
            monoFontFamily: "Menlo",
            cornerRadius: 16
        )
    }

    private static func loadEntries(from source: Source) -> [Entry] {
        guard let directoryURL = directoryURL(for: source) else {
            return []
        }

        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard url.pathExtension == "theme",
                  let data = try? Data(contentsOf: url),
                  let definition = try? JSONDecoder().decode(ThemeFile.self, from: data),
                  definition.isSupported(for: source),
                  let theme = definition.toSlopTheme()
            else {
                return nil
            }

            let id = url.deletingPathExtension().lastPathComponent
            return Entry(
                id: id,
                displayName: definition.displayName ?? prettify(id),
                group: definition.group ?? defaultGroup(for: id),
                source: source,
                theme: theme
            )
        }
    }

    private static func directoryURL(for source: Source) -> URL? {
        switch source {
        case .bundled:
            return SlopBundledResources.themesDirectoryURL
        case .shared:
            return SlopSharedContainer.themesDir
        case .user:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".hitslop/themes")
        }
    }

    private static func prettify(_ id: String) -> String {
        id.split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private static func defaultGroup(for id: String) -> String {
        switch id {
        case "studio-noir", "signal-grid", "terminal-core", "midnight-ink":
            return "Dark"
        case "paper-ledger":
            return "Light"
        case "playroom", "candy-shop":
            return "Playful"
        case "forest-club":
            return "Nature"
        case "ocean-glass", "arctic-frost", "lavender-haze":
            return "Cool"
        case "sunset-poster", "ember-glow", "rose-garden":
            return "Warm"
        case "neon-nights", "frutiger-aero", "xbox-dashboard":
            return "Vibrant"
        case "retro-terminal":
            return "Retro"
        case "minimal-mono", "slate-gray":
            return "Minimal"
        case "corporate-blue":
            return "Professional"
        case "high-contrast":
            return "Accessibility"
        default:
            return "Other"
        }
    }

    private static func groupRank(_ group: String) -> Int {
        switch group {
        case "Dark":
            return 0
        case "Light":
            return 1
        case "Minimal":
            return 2
        case "Professional":
            return 3
        case "Cool":
            return 4
        case "Warm":
            return 5
        case "Nature":
            return 6
        case "Vibrant":
            return 7
        case "Playful":
            return 8
        case "Retro":
            return 9
        case "Accessibility":
            return 10
        default:
            return 99
        }
    }

    private static func normalizedThemeID(_ id: String?) -> String? {
        guard let id else { return nil }
        switch id {
        case "cool":
            return "studio-noir"
        case "warm":
            return "paper-ledger"
        case "acid-green", "terminal":
            return "terminal-core"
        case "midnight", "mono":
            return "signal-grid"
        case "forest":
            return "forest-club"
        case "ocean":
            return "ocean-glass"
        case "sunset":
            return "sunset-poster"
        case "rose":
            return "rose-garden"
        case "lavender":
            return "lavender-haze"
        case "paper":
            return "paper-ledger"
        case "slate":
            return "slate-gray"
        case "xbox":
            return "xbox-dashboard"
        case "midnight-dark":
            return "midnight-ink"
        default:
            return id
        }
    }
}

