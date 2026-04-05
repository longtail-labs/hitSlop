import AppKit
import SwiftUI
import SlopKit
import SlopTemplates

/// Generates and caches PNG preview images for installed templates.
/// Previews are stored at `~/.hitslop/previews/<templateID>@<version>.png`.
@MainActor
public final class SlopTemplatePreviewCache {

    public static let previewsDir: URL = SlopSharedContainer.previewsDir

    /// Generate cached preview images for all registry entries that are missing or stale.
    public static func generatePreviews(for entries: [SlopTemplateRegistry.Entry]) {
        let fm = FileManager.default
        try? fm.createDirectory(at: previewsDir, withIntermediateDirectories: true)

        syncThemesToSharedContainer()

        for entry in entries {
            let cacheURL = previewURL(for: entry.manifest.id, version: entry.manifest.version)

            if entry.isBuiltIn {
                // Built-in: skip if cache already exists (version is baked into the app)
                if fm.fileExists(atPath: cacheURL.path) { continue }
            } else {
                // Skip if cache is fresh (artifact not modified since preview was generated)
                let artifactURL = entry.bundleURL ?? entry.scriptURL
                if fm.fileExists(atPath: cacheURL.path),
                   let cacheDate = modificationDate(cacheURL),
                   let artifactURL,
                   let bundleDate = modificationDate(artifactURL),
                   cacheDate >= bundleDate {
                    continue
                }
            }

            renderPreview(for: entry, to: cacheURL)
        }
    }

    /// Returns the cached preview image for a given template, or nil if not yet generated.
    public static func previewImage(templateID: String, version: String) -> NSImage? {
        let url = previewURL(for: templateID, version: version)
        return NSImage(contentsOf: url)
    }

    /// URL where a preview would be cached.
    public static func previewURL(for templateID: String, version: String) -> URL {
        previewsDir.appendingPathComponent("\(templateID)@\(version).png")
    }

    /// Render a preview PNG for a specific document (with its actual data and theme)
    /// and write it into the `.slop` package directory as `preview.png`.
    public static func renderDocumentPreview(
        templateBody: AnyView,
        metadata: TemplateMetadata,
        themeName: String?,
        bundleURL: URL,
        packageURL: URL,
        effectiveShape: WindowShape? = nil
    ) {
        guard let snapshot = SlopTemplateSnapshotRenderer.renderImage(
            makeTemplateBody: { templateBody },
            metadata: metadata,
            themeName: themeName,
            bundleURL: bundleURL,
            scale: 2,
            packageURL: packageURL,
            effectiveShape: effectiveShape
        ) else {
            NSLog("SlopTemplatePreviewCache: failed to render document preview for \(packageURL.lastPathComponent)")
            return
        }

        guard let pngData = snapshot.pngData() else {
            NSLog("SlopTemplatePreviewCache: failed to encode document preview PNG for \(packageURL.lastPathComponent)")
            return
        }

        let outputURL = packageURL.appendingPathComponent("preview.png")
        try? pngData.write(to: outputURL, options: .atomic)

        // Touch the package directory so Finder sees a fresh mtime and
        // re-requests the thumbnail (the earlier slop.json write may have
        // already triggered a request that cached the stale preview).
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: packageURL.path
        )
    }

    // MARK: - Private

    private static func renderPreview(for entry: SlopTemplateRegistry.Entry, to outputURL: URL) {
        do {
            let resolvedBundleURL: URL
            let templateBody: AnyView
            let metadata: TemplateMetadata

            if let builtInType = entry.builtInType {
                resolvedBundleURL = BuiltInTemplateRegistry.resourceBundle.bundleURL
                let defaults = builtInType.schema.defaultValues()
                let store = RawTemplateStore(values: defaults, persist: { _ in })
                let instance = builtInType.init(rawStore: store)
                templateBody = instance.body()
                metadata = builtInType.metadata
            } else if let scriptURL = entry.scriptURL {
                resolvedBundleURL = entry.installURL
                let defaults = entry.manifest.schema.defaultValues()
                let store = RawTemplateStore(values: defaults, persist: { _ in })
                let instance = try ScriptedTemplate.create(
                    scriptPath: scriptURL.path,
                    manifest: entry.manifest,
                    rawStore: store
                )
                templateBody = instance.body()
                metadata = entry.manifest.metadata
            } else if let bundleURL = entry.bundleURL {
                let loaded = try SlopTemplateBundleLoader.load(
                    bundleURL: bundleURL,
                    expectedManifest: entry.manifest
                )
                resolvedBundleURL = bundleURL
                let defaults = loaded.templateType.schema.defaultValues()
                let store = RawTemplateStore(values: defaults, persist: { _ in })
                let instance = loaded.templateType.init(rawStore: store)
                templateBody = instance.body()
                metadata = loaded.templateType.metadata
            } else {
                return
            }

            let themeName = metadata.theme
            guard let snapshot = SlopTemplateSnapshotRenderer.renderImage(
                makeTemplateBody: { templateBody },
                metadata: metadata,
                themeName: themeName,
                bundleURL: resolvedBundleURL,
                scale: 2
            ) else {
                NSLog("SlopTemplatePreviewCache: failed to render preview for \(entry.manifest.id)")
                return
            }

            guard let pngData = snapshot.pngData() else {
                NSLog("SlopTemplatePreviewCache: failed to encode PNG for \(entry.manifest.id)")
                return
            }

            try pngData.write(to: outputURL, options: .atomic)
        } catch {
            NSLog("SlopTemplatePreviewCache: error generating preview for \(entry.manifest.id): \(error)")
        }
    }

    /// Copy all `.theme` files from `~/.hitslop/themes/` to the shared container
    /// so sandboxed QL extensions can resolve theme colors.
    private static func syncThemesToSharedContainer() {
        let fm = FileManager.default
        let src = fm.homeDirectoryForCurrentUser.appendingPathComponent(".hitslop/themes")
        let dst = SlopSharedContainer.themesDir

        guard fm.fileExists(atPath: src.path) else { return }
        try? fm.createDirectory(at: dst, withIntermediateDirectories: true)

        guard let entries = try? fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil)
        else { return }

        for url in entries where url.pathExtension == "theme" {
            let target = dst.appendingPathComponent(url.lastPathComponent)
            try? fm.removeItem(at: target)
            try? fm.copyItem(at: url, to: target)
        }
    }

    private static func modificationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
