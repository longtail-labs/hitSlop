import Foundation
import SlopKit
import FirebaseAILogic
import os

private let log = Logger(subsystem: "com.hitslop.ai", category: "parser")

/// Converts Firebase AI Logic function call arguments to SlopKit field values.
public struct ResponseParser: Sendable {

    /// Convert Firebase function call args to SlopKit FieldValues using schema-guided decoding.
    public static func parseFirebaseArgs(
        _ args: [String: FirebaseAILogic.JSONValue],
        schema: SlopKit.Schema
    ) -> [String: SlopKit.FieldValue] {
        log.info("parseFirebaseArgs: input keys=\(args.keys.sorted().joined(separator: ", "), privacy: .public)")
        let slopJSON = args.mapValues { toSlopJSON($0) }
        let result = SlopKit.FieldValue.decodeRecord(slopJSON, schema: schema)
        log.info("parseFirebaseArgs: output keys=\(result.keys.sorted().joined(separator: ", "), privacy: .public) (count=\(result.count))")
        return result
    }

    /// Parse array operation arguments from a function call.
    public static func parseArrayOps(
        _ args: [String: FirebaseAILogic.JSONValue],
        field: String,
        schema: SlopKit.Schema
    ) -> [ArrayOperation] {
        log.info("parseArrayOps: field=\(field, privacy: .public), arg keys=\(args.keys.sorted().joined(separator: ", "), privacy: .public)")
        let fieldDescriptor = schema.field(forKey: field)
        let itemSchema = fieldDescriptor?.itemSchema ?? SlopKit.Schema(sections: [])

        var add: [SlopKit.FieldValue] = []
        var removeIDs: [String] = []
        var update: [SlopKit.FieldValue] = []

        if case .array(let addItems) = args["add"] {
            for item in addItems {
                if case .object(let obj) = toSlopJSON(item) {
                    add.append(.record(SlopKit.FieldValue.decodeRecord(obj, schema: itemSchema)))
                }
            }
        }

        if case .array(let removeArr) = args["remove_ids"] {
            for item in removeArr {
                if case .string(let id) = toSlopJSON(item) {
                    removeIDs.append(id)
                }
            }
        }

        if case .array(let updateItems) = args["update"] {
            for item in updateItems {
                if case .object(let obj) = toSlopJSON(item) {
                    update.append(.record(SlopKit.FieldValue.decodeRecord(obj, schema: itemSchema)))
                }
            }
        }

        log.info("parseArrayOps: field=\(field, privacy: .public) — add=\(add.count), remove=\(removeIDs.count), update=\(update.count)")
        return [ArrayOperation(field: field, add: add, removeIDs: removeIDs, update: update)]
    }

    // MARK: - Firebase JSONValue → SlopKit JSONValue

    /// Recursively convert a Firebase AI Logic JSONValue to a SlopKit JSONValue.
    public static func toSlopJSON(_ value: FirebaseAILogic.JSONValue) -> SlopKit.JSONValue {
        switch value {
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .bool(let b): return .bool(b)
        case .object(let obj): return .object(obj.mapValues { toSlopJSON($0) })
        case .array(let arr): return .array(arr.map { toSlopJSON($0) })
        case .null: return .null
        }
    }
}
