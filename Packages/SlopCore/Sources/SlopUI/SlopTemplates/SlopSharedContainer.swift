import Foundation

public enum SlopSharedContainer {
    public static let appGroupID = "78UAXU8QG8.ca.long.tail.labs.hitSlop"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    public static var previewsDir: URL {
        guard let container = containerURL else {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".hitslop/previews")
        }
        return container.appendingPathComponent("previews")
    }

    /// Theme JSON files synced from ~/.hitslop/themes/ for sandboxed extensions.
    public static var themesDir: URL {
        guard let container = containerURL else {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".hitslop/themes")
        }
        return container.appendingPathComponent("themes")
    }

    /// Skin PNG files for custom window shapes.
    public static var skinsDir: URL {
        guard let container = containerURL else {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".hitslop/skins")
        }
        return container.appendingPathComponent("skins")
    }
}
