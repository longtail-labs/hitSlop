import SwiftUI
import SlopKit
import SlopTemplates

/// Creates template body views for IPC export without a window.
@MainActor
enum SlopTemplateBodyFactory {
    static func makeBody(entry: SlopTemplateRegistry.Entry, store: RawTemplateStore) -> AnyView {
        do {
            if let builtInType = entry.builtInType {
                let instance = builtInType.init(rawStore: store)
                return instance.body()
            } else if let scriptURL = entry.scriptURL {
                let instance = try ScriptedTemplate.create(
                    scriptPath: scriptURL.path,
                    manifest: entry.manifest,
                    rawStore: store
                )
                return instance.body()
            } else if let bundleURL = entry.bundleURL {
                let loaded = try SlopTemplateBundleLoader.load(
                    bundleURL: bundleURL,
                    expectedManifest: entry.manifest
                )
                let instance = loaded.templateType.init(rawStore: store)
                return instance.body()
            }
        } catch {
            NSLog("SlopTemplateBodyFactory: failed to create body for \(entry.manifest.id): \(error)")
        }
        return AnyView(Text("Failed to load template"))
    }

    /// Resolved bundle URL for a given entry (used for skin/resource loading).
    static func bundleURL(for entry: SlopTemplateRegistry.Entry) -> URL {
        if entry.isBuiltIn {
            return BuiltInTemplateRegistry.resourceBundle.bundleURL
        }
        return entry.bundleURL ?? entry.installURL
    }
}
