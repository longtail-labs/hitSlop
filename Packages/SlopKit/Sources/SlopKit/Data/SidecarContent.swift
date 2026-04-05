import SwiftUI

/// Property wrapper for template views to access sidecar file content.
/// Bridges between `SidecarStore` (host-managed file content) and the template view.
///
/// Usage:
/// ```swift
/// struct MarkdownEditorView: View {
///     @SidecarContent(key: "content") var content: String
///     var body: some View {
///         TextEditor(text: $content)
///     }
/// }
/// ```
@MainActor
@propertyWrapper
public struct SidecarContent: DynamicProperty {
    @ObservedObject private var store: SidecarStore
    private let key: String

    public init(key: String, store: SidecarStore) {
        self.key = key
        self._store = ObservedObject(wrappedValue: store)
    }

    public var wrappedValue: String {
        get { store.textContent[key] ?? "" }
        nonmutating set { store.setTextContent(newValue, forKey: key) }
    }

    public var projectedValue: Binding<String> {
        let store = self.store
        let key = self.key
        return Binding(
            get: { store.textContent[key] ?? "" },
            set: { newValue in store.setTextContent(newValue, forKey: key) }
        )
    }
}
