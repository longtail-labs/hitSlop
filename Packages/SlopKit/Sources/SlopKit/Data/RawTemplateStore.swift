import Foundation
import Combine

/// Generic data store bridging the host's [String: FieldValue] with the template.
/// The host creates this with a reference to its @Shared data;
/// the template reads/writes through it via @TemplateState.
@MainActor
public final class RawTemplateStore: ObservableObject {
    @Published public private(set) var values: [String: FieldValue]
    /// Incremented on every value change; used by TemplateState to invalidate its cache.
    public private(set) var generation: UInt64 = 0
    private var persistHandler: (([String: FieldValue]) -> Void)?

    public init(
        values: [String: FieldValue],
        persist: @escaping ([String: FieldValue]) -> Void
    ) {
        self.values = values
        self.persistHandler = persist
    }

    public func setPersistHandler(_ persist: @escaping ([String: FieldValue]) -> Void) {
        self.persistHandler = persist
    }

    /// Update a single field and persist.
    public func setValue(_ value: FieldValue, forKey key: String) {
        values[key] = value
        generation &+= 1
        persistHandler?(values)
    }

    /// Bulk-update all values and persist.
    public func setValues(_ newValues: [String: FieldValue]) {
        values = newValues
        generation &+= 1
        persistHandler?(values)
    }

    /// Update from external source (e.g. file watcher) without triggering persist.
    public func externalUpdate(_ newValues: [String: FieldValue]) {
        values = newValues
        generation &+= 1
    }
}
