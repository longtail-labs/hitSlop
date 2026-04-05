import Foundation

public enum SlopThemeLoader {
    nonisolated(unsafe) private static var cache: [String: SlopTheme]?

    /// Compatibility shim for callers that still want only user-provided themes.
    public static func loadExternalThemes() -> [String: SlopTheme] {
        if let cache {
            return cache
        }

        let themes = Dictionary(
            uniqueKeysWithValues: ThemeCatalog.entries()
                .filter { $0.source == .user }
                .map { ($0.id, $0.theme) }
        )
        cache = themes
        return themes
    }

    public static func invalidateCache() {
        cache = nil
        ThemeCatalog.invalidateCache()
    }
}
