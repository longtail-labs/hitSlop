import Foundation
import SlopKit

/// Bridges Lua `data.fieldName` access to the host's `RawTemplateStore`.
/// Passed to Lua `template.layout(data, theme)` as the first argument.
@MainActor
final class DataProxy {
    let store: RawTemplateStore

    init(store: RawTemplateStore) {
        self.store = store
    }

    func getValue(forKey key: String) -> FieldValue? {
        store.values[key]
    }

    func setValue(_ value: FieldValue, forKey key: String) {
        store.setValue(value, forKey: key)
    }

    /// Snapshot of current values as a plain dictionary for read-only Lua access.
    var snapshot: [String: FieldValue] {
        store.values
    }
}
