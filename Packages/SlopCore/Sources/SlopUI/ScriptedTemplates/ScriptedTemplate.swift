import SwiftUI
import SlopKit
import os

private let log = Logger(subsystem: "ca.long.tail.labs.slop", category: "ScriptedTemplate")

/// A scripted (Lua) template that conforms to `AnySlopTemplate`.
/// Wraps `LuaTemplateEngine` for script execution and
/// `ScriptedTemplateRenderer` for SwiftUI rendering.
@MainActor
final class ScriptedTemplate: AnySlopTemplate {
    // Static properties — unused at runtime for scripted templates
    // (the host reads schema/metadata from the manifest, not from the type).
    // Required by AnySlopTemplate protocol.
    nonisolated static let templateID: String = "scripted"
    nonisolated static let name: String = "Scripted Template"
    nonisolated static let templateDescription: String? = nil
    nonisolated static let version: String = "1.0.0"
    nonisolated static let minimumHostVersion: String = "1.0.0"
    nonisolated static let schema: Schema = Schema(sections: [])
    nonisolated static let metadata: TemplateMetadata = TemplateMetadata()

    private let engine: LuaTemplateEngine
    private let store: RawTemplateStore

    required init(rawStore: RawTemplateStore) {
        self.store = rawStore
        self.engine = LuaTemplateEngine(scriptPath: "")
    }

    /// Full initializer used by the factory method.
    private init(rawStore: RawTemplateStore, engine: LuaTemplateEngine) {
        self.store = rawStore
        self.engine = engine
    }

    func body() -> AnyView {
        AnyView(
            ScriptedTemplateBody(
                store: store,
                engine: engine
            )
        )
    }

    /// Create a ScriptedTemplate by loading a Lua script from disk.
    static func create(
        scriptPath: String,
        manifest: TemplateManifest,
        rawStore: RawTemplateStore
    ) throws -> ScriptedTemplate {
        let engine = LuaTemplateEngine(scriptPath: scriptPath)
        try engine.load()
        return ScriptedTemplate(rawStore: rawStore, engine: engine)
    }
}

/// Internal SwiftUI view that re-renders the layout tree on each store change.
@MainActor
private struct ScriptedTemplateBody: View {
    @ObservedObject var store: RawTemplateStore
    let engine: LuaTemplateEngine
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        let result = buildLayout()
        switch result {
        case .success(let root):
            ScriptedTemplateRenderer(
                root: root,
                store: store,
                theme: theme,
                renderTarget: renderTarget,
                onAction: { action in handleAction(action) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failure(let error):
            errorView(error.localizedDescription)
        }
    }

    private func buildLayout() -> Result<LayoutNode, Error> {
        do {
            let root = try engine.callLayout(store: store, theme: theme, renderTarget: renderTarget)
            return .success(root)
        } catch {
            log.error("Layout build error: \(error)")
            return .failure(error)
        }
    }

    private func handleAction(_ actionName: String) {
        do {
            if let updatedData = try engine.callOnAction(name: actionName, store: store) {
                store.setValues(updatedData)
            }
        } catch {
            log.error("Action '\(actionName)' error: \(error)")
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text("Script Error")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
