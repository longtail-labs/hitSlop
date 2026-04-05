import Foundation

/// Represents a recently opened .slop document with rich metadata.
nonisolated struct RecentDocument: Codable, Equatable, Identifiable, Sendable {
    var id: String { path }
    let path: String
    let lastOpened: Date
    let templateID: String?
    let templateVersion: String?
    let displayName: String

    init(url: URL, templateID: String? = nil, templateVersion: String? = nil) {
        self.path = url.path
        self.lastOpened = Date()
        self.templateID = templateID
        self.templateVersion = templateVersion
        self.displayName = url.deletingPathExtension().lastPathComponent
    }
}
