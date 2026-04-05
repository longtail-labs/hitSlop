import Foundation
import Combine

/// Observable store for sidecar file content, keyed by field key.
/// Parallel to `RawTemplateStore` but for file-backed content with different
/// persistence semantics (debounced write, no JSON roundtrip).
@MainActor
public final class SidecarStore: ObservableObject {
    @Published public private(set) var textContent: [String: String]
    @Published public private(set) var binaryContent: [String: Data]

    /// Incremented on every content change; used for view invalidation.
    public private(set) var generation: UInt64 = 0

    private var persistHandler: ((String, String) -> Void)?

    public init() {
        self.textContent = [:]
        self.binaryContent = [:]
    }

    public func setPersistHandler(_ handler: @escaping (String, String) -> Void) {
        self.persistHandler = handler
    }

    /// Set text content for a key and trigger persist.
    public func setTextContent(_ content: String, forKey key: String) {
        textContent[key] = content
        generation &+= 1
        persistHandler?(key, content)
    }

    /// Update from external source (e.g. file watcher) without triggering persist.
    public func externalTextUpdate(_ content: String, forKey key: String) {
        textContent[key] = content
        generation &+= 1
    }

    /// Set binary content for a key (no persist handler for binary yet).
    public func setBinaryContent(_ data: Data, forKey key: String) {
        binaryContent[key] = data
        generation &+= 1
    }

    /// Update binary content from external source without triggering persist.
    public func externalBinaryUpdate(_ data: Data, forKey key: String) {
        binaryContent[key] = data
        generation &+= 1
    }
}
