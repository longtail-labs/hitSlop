import Foundation
import SlopKit
import SlopTemplates

/// Central registry of installed Slop template bundles.
/// Scans `~/.hitslop/templates/<template-id>/<version>/template.json`
/// without loading executable bundles until needed.
@MainActor
public class SlopTemplateRegistry {

    /// A discovered installed template.
    public struct Entry: @unchecked Sendable, Identifiable {
        public let installURL: URL
        /// Bundle URL for compiled (Tier 1) templates. Nil for scripted or built-in templates.
        public let bundleURL: URL?
        /// Script file URL for Lua (Tier 2) templates. Nil for compiled templates.
        public let scriptURL: URL?
        public let previewURL: URL?
        public let manifest: TemplateManifest
        /// Non-nil for built-in templates compiled directly into the app.
        public let builtInType: (any AnySlopTemplate.Type)?

        public var id: String {
            "\(manifest.id)@\(manifest.version)"
        }

        /// True if this is a built-in template compiled into the app.
        public var isBuiltIn: Bool { builtInType != nil }
        /// True if this is a Lua-scripted (Tier 2) template.
        public var isScripted: Bool { manifest.isScripted }
    }

    /// All discovered template entries.
    public private(set) var entries: [Entry] = []

    public static let defaultTemplatesDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".hitslop/templates")
    private let templatesDir: URL

    public init(templatesDirectory: URL = SlopTemplateRegistry.defaultTemplatesDir) {
        self.templatesDir = templatesDirectory
    }

    /// Scan the templates directory for installed template manifests.
    public func scan() {
        var results: [Entry] = []

        // 1. Register all built-in templates
        for type in BuiltInTemplateRegistry.all {
            let manifest = BuiltInTemplateRegistry.manifest(for: type)
            results.append(Entry(
                installURL: Bundle.main.bundleURL,
                bundleURL: nil,
                scriptURL: nil,
                previewURL: nil,
                manifest: manifest,
                builtInType: type
            ))
        }

        // 2. Scan external templates from ~/.hitslop/templates/
        let builtInIDs = Set(results.map { $0.manifest.id })
        let fm = FileManager.default
        let dir = templatesDir

        if let templateDirectories = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for templateDirectory in templateDirectories where isDirectory(templateDirectory) {
                guard let versionDirectories = try? fm.contentsOfDirectory(
                    at: templateDirectory,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for versionDirectory in versionDirectories where isDirectory(versionDirectory) {
                    if let entry = readEntry(fromInstallURL: versionDirectory) {
                        // External templates with same ID override built-in
                        if builtInIDs.contains(entry.manifest.id) {
                            results.removeAll { $0.manifest.id == entry.manifest.id }
                        }
                        results.append(entry)
                    }
                }
            }
        }

        entries = results.sorted {
            if $0.manifest.name == $1.manifest.name {
                return $0.manifest.version < $1.manifest.version
            }
            return $0.manifest.name < $1.manifest.name
        }
    }

    /// Resolve an exact installed template version.
    public func resolve(templateID: String, version: String) -> Entry? {
        entries.first { $0.manifest.id == templateID && $0.manifest.version == version }
    }

    // MARK: - Private

    private func readEntry(fromInstallURL installURL: URL) -> Entry? {
        let manifestURL = installURL.appendingPathComponent("template.json")

        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(TemplateManifest.self, from: data)
        else {
            return nil
        }

        let previewURL = manifest.previewFile.map { installURL.appendingPathComponent($0) }

        // Scripted (Tier 2) template — requires scriptFile
        if let scriptFile = manifest.scriptFile {
            let scriptURL = installURL.appendingPathComponent(scriptFile)
            guard FileManager.default.fileExists(atPath: scriptURL.path) else {
                NSLog("SlopTemplateRegistry: missing script '\(scriptFile)' at \(installURL.path)")
                return nil
            }
            return Entry(
                installURL: installURL,
                bundleURL: nil,
                scriptURL: scriptURL,
                previewURL: previewURL,
                manifest: manifest,
                builtInType: nil
            )
        }

        // Compiled (Tier 1) template — requires bundleFile
        guard let bundleFile = manifest.bundleFile else {
            NSLog("SlopTemplateRegistry: manifest has neither bundleFile nor scriptFile at \(manifestURL.path)")
            return nil
        }
        let bundleURL = installURL.appendingPathComponent(bundleFile)
        guard FileManager.default.fileExists(atPath: bundleURL.path) else {
            NSLog("SlopTemplateRegistry: missing bundle for manifest at \(manifestURL.path)")
            return nil
        }

        return Entry(
            installURL: installURL,
            bundleURL: bundleURL,
            scriptURL: nil,
            previewURL: previewURL,
            manifest: manifest,
            builtInType: nil
        )
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
