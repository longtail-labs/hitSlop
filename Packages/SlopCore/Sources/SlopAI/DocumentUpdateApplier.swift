import Foundation
import SlopKit
import os

private let log = Logger(subsystem: "com.hitslop.ai", category: "applier")

/// Applies AI-generated document updates to a RawTemplateStore.
/// All changes go through the store's `setValues()` for undo support.
public struct DocumentUpdateApplier: Sendable {

    /// Apply an AI-generated update to a document's data store.
    @MainActor
    public static func apply(
        _ update: DocumentUpdate,
        to store: RawTemplateStore,
        schema: SlopKit.Schema
    ) {
        log.info("apply: store keys=\(store.values.count)")

        switch update {
        case .fullRewrite(let newData):
            let merged = schema.defaultValues().merging(newData) { _, new in new }
            log.info("apply: fullRewrite — merged \(merged.count) keys (defaults + \(newData.count) new)")
            store.setValues(merged)

        case .mergeFields(let changedFields):
            var current = store.values
            for (key, value) in changedFields {
                current[key] = value
            }
            log.info("apply: mergeFields — patched \(changedFields.count) keys into \(current.count) total")
            store.setValues(current)

        case .arrayOps(let operations):
            var current = store.values
            for op in operations {
                guard var array = current[op.field]?.asArray else {
                    log.error("apply: arrayOp field=\(op.field, privacy: .public) — not found or not an array")
                    continue
                }

                let beforeCount = array.count

                // Remove items by ID
                if !op.removeIDs.isEmpty {
                    array.removeAll { item in
                        guard case .record(let record) = item,
                              let id = record["id"]?.asString else { return false }
                        return op.removeIDs.contains(id)
                    }
                }

                // Update items by matching ID
                for updateItem in op.update {
                    guard case .record(let updateRecord) = updateItem,
                          let updateID = updateRecord["id"]?.asString else { continue }
                    if let index = array.firstIndex(where: { item in
                        guard case .record(let record) = item else { return false }
                        return record["id"]?.asString == updateID
                    }) {
                        array[index] = updateItem
                    }
                }

                // Append new items
                array.append(contentsOf: op.add)

                current[op.field] = .array(array)
                log.info("apply: arrayOp field=\(op.field, privacy: .public) — before=\(beforeCount), after=\(array.count) (add=\(op.add.count), remove=\(op.removeIDs.count), update=\(op.update.count))")
            }
            store.setValues(current)
        }

        log.info("apply: done, store now has \(store.values.count) keys")
    }
}
