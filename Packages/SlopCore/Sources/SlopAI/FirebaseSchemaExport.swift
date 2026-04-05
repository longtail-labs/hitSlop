import Foundation
import SlopKit
import FirebaseAILogic

// MARK: - Schema → Firebase AI Logic Schema

extension SlopKit.Schema {
    /// Convert to a Firebase AI Logic Schema (`.object`) for use with `responseSchema`.
    /// - Parameter allOptional: If true, all fields become optional (for merge patches).
    public func toFirebaseSchema(allOptional: Bool = false) -> FirebaseAILogic.Schema {
        var properties: [String: FirebaseAILogic.Schema] = [:]
        var optionalProperties: [String] = []

        for field in allFields {
            // Skip image and file fields — LLMs can't generate image paths or sidecar filenames
            guard field.kind != .image && field.kind != .file else { continue }
            properties[field.key] = field.toFirebaseSchemaProperty()
            if allOptional || !field.required {
                optionalProperties.append(field.key)
            }
        }

        return .object(
            properties: properties,
            optionalProperties: optionalProperties
        )
    }

    /// Returns properties dictionary for `FunctionDeclaration` parameters.
    public func toFirebaseProperties(allOptional: Bool = false) -> [String: FirebaseAILogic.Schema] {
        var properties: [String: FirebaseAILogic.Schema] = [:]
        for field in allFields where field.kind != .image && field.kind != .file {
            properties[field.key] = field.toFirebaseSchemaProperty()
        }
        return properties
    }

    /// Returns keys of required fields for `FunctionDeclaration`.
    public func firebaseRequiredKeys(allOptional: Bool = false) -> [String] {
        guard !allOptional else { return [] }
        return allFields
            .filter { $0.kind != .image && $0.kind != .file && $0.required }
            .map(\.key)
    }
}

// MARK: - FieldDescriptor → Firebase Schema Property

extension SlopKit.FieldDescriptor {
    /// Convert a single field descriptor to a Firebase AI Logic Schema property.
    public func toFirebaseSchemaProperty() -> FirebaseAILogic.Schema {
        let desc = hint ?? label

        switch kind {
        case .string:
            return .string(description: desc)

        case .richText:
            return .string(description: "\(desc) (rich text content)")

        case .number:
            return .double(description: desc)

        case .bool:
            return .boolean(description: desc)

        case .color:
            return .string(description: "\(desc) \u{2014} hex color #RRGGBB, e.g. #FF6B6B")

        case .date:
            return .string(description: "\(desc) \u{2014} ISO 8601 date-time string")

        case .image:
            // Shouldn't be called for image fields (filtered above), but handle gracefully
            return .string(description: desc)

        case .enumeration:
            let values = options?.map(\.value) ?? []
            return .enumeration(values: values, description: desc)

        case .array:
            if let itemSchema {
                return .array(items: itemSchema.toFirebaseSchema(), description: desc)
            }
            return .array(items: .string(), description: desc)

        case .record:
            if let recordSchema {
                return recordSchema.toFirebaseSchema()
            }
            return .object(properties: [:], description: desc)

        case .file:
            // Shouldn't be called for file fields (filtered above), but handle gracefully
            return .string(description: "\(desc) (sidecar file — not AI-editable)")
        }
    }
}
