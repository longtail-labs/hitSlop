import Foundation

/// Simple file-backed image reference persisted in documents as a string path.
public struct TemplateImage: Codable, Sendable, Hashable {
    public let path: String

    public init(_ path: String) {
        self.path = path
    }

    /// Resolve path: absolute passes through, relative resolves against packageURL.
    public func resolved(relativeTo packageURL: URL?) -> String {
        if path.isEmpty || path.hasPrefix("/") { return path }
        guard let packageURL else { return path }
        return packageURL.appendingPathComponent(path).path
    }

    /// Copy source file into the package's `assets/` directory and return a
    /// ``TemplateImage`` with the relative path. Falls back to an absolute path
    /// when no package URL is available.
    public static func importAsset(from sourceURL: URL, into packageURL: URL?) -> TemplateImage {
        guard let packageURL else { return TemplateImage(sourceURL.path) }
        let assetsDir = packageURL.appendingPathComponent("assets")
        try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        let uuid = UUID().uuidString.prefix(8).lowercased()
        let filename = "\(uuid).\(sourceURL.pathExtension.lowercased())"
        let destURL = assetsDir.appendingPathComponent(filename)
        try? FileManager.default.copyItem(at: sourceURL, to: destURL)
        return TemplateImage("assets/\(filename)")
    }
}
