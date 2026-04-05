import AppKit
import Foundation

public enum SkinCatalog {
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
        public let fileURL: URL
        public let previewImage: NSImage?
    }

    public struct Group: Identifiable, Sendable {
        public let id: String
        public let displayName: String
        public let entries: [Entry]
    }

    nonisolated(unsafe) private static var cache: [Entry]?

    public static func entries() -> [Entry] {
        if let cache { return cache }

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
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        cache = sorted
        return sorted
    }

    public static func resolve(_ id: String) -> Entry? {
        entries().first { $0.id == id }
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

    public static func invalidateCache() {
        cache = nil
    }

    // MARK: - Private

    private static func loadEntries(from source: Source) -> [Entry] {
        guard let directoryURL = directoryURL(for: source) else { return [] }
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url in
            guard url.pathExtension == "png" else { return nil }
            let id = url.deletingPathExtension().lastPathComponent
            let image = NSImage(contentsOf: url)
            return Entry(
                id: id,
                displayName: prettify(id),
                group: categoryForSkin(id),
                source: source,
                fileURL: url,
                previewImage: image
            )
        }
    }

    private static func directoryURL(for source: Source) -> URL? {
        switch source {
        case .bundled:
            return SlopBundledResources.skinsDirectoryURL
        case .shared:
            return SlopSharedContainer.skinsDir
        case .user:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".hitslop/skins")
        }
    }

    private static func prettify(_ id: String) -> String {
        id.split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private static func categoryForSkin(_ id: String) -> String {
        switch id {
        case "chamfered-rect", "hexagon", "diamond":
            return "Geometric"
        case "blob", "cloud", "teardrop":
            return "Organic"
        case "notebook", "sticky-note", "ticket-stub":
            return "Retro"
        case "pill", "squircle", "notched-rect":
            return "Minimal"
        default:
            return "Custom"
        }
    }

    private static func groupRank(_ group: String) -> Int {
        switch group {
        case "Geometric": return 0
        case "Organic": return 1
        case "Retro": return 2
        case "Minimal": return 3
        case "Custom": return 4
        default: return 99
        }
    }
}
