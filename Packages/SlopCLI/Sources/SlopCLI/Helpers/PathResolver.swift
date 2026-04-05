import Foundation

/// Resolve a potentially relative path to an absolute path.
func resolvePath(_ path: String) -> String {
    if path.hasPrefix("/") || path.hasPrefix("~") {
        return (path as NSString).expandingTildeInPath
    }
    let cwd = FileManager.default.currentDirectoryPath
    return (cwd as NSString).appendingPathComponent(path)
}
