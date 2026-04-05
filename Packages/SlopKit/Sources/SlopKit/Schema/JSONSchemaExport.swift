import Foundation

extension Schema {
    /// Convert to a JSON Schema dictionary.
    /// - Parameter title: Optional title for the root schema.
    public func toJSONSchema(title: String? = nil) -> [String: Any] {
        var schema: [String: Any] = ["type": "object"]
        if let title { schema["title"] = title }

        var properties: [String: Any] = [:]
        var required: [String] = []

        for field in allFields {
            properties[field.key] = field.toJSONSchemaProperty()
            if field.required {
                required.append(field.key)
            }
        }

        schema["properties"] = properties
        if !required.isEmpty {
            schema["required"] = required
        }

        return schema
    }

    /// Convert to JSON Schema as encoded Data.
    public func toJSONSchemaData(title: String? = nil) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: toJSONSchema(title: title),
            options: [.prettyPrinted, .sortedKeys]
        )
    }
}

extension FieldDescriptor {
    /// Convert a single field to a JSON Schema property dictionary.
    public func toJSONSchemaProperty() -> [String: Any] {
        var prop: [String: Any] = [:]
        let desc = hint ?? label
        prop["description"] = desc

        switch kind {
        case .string, .richText:
            prop["type"] = "string"

        case .number:
            prop["type"] = "number"

        case .bool:
            prop["type"] = "boolean"

        case .color:
            prop["type"] = "string"
            prop["pattern"] = "^#[0-9A-Fa-f]{6}$"

        case .date:
            prop["type"] = "string"
            prop["format"] = "date-time"

        case .image:
            prop["type"] = "string"

        case .enumeration:
            prop["type"] = "string"
            if let options {
                prop["enum"] = options.map(\.value)
            }

        case .array:
            prop["type"] = "array"
            if let itemSchema {
                prop["items"] = itemSchema.toJSONSchema()
            } else if let arrayItemKind {
                prop["items"] = jsonSchemaItems(for: arrayItemKind)
            }

        case .record:
            if let recordSchema {
                prop = recordSchema.toJSONSchema()
                prop["description"] = desc
            } else {
                prop["type"] = "object"
            }

        case .file:
            prop["type"] = "string"
            prop["description"] = desc + " (sidecar filename)"
        }

        if editor != .automatic {
            prop["x-hitslop-editor"] = editor.schemaValue
            if case .currency(let codeField) = editor, let codeField {
                prop["x-hitslop-editorCodeField"] = codeField
            }
        }

        // Apply constraints
        for constraint in constraints {
            switch constraint {
            case .min(let v): prop["minimum"] = v
            case .max(let v): prop["maximum"] = v
            case .minLength(let v): prop["minLength"] = v
            case .maxLength(let v): prop["maxLength"] = v
            case .minItems(let v): prop["minItems"] = v
            case .maxItems(let v): prop["maxItems"] = v
            case .regex(let v): prop["pattern"] = v
            }
        }

        return prop
    }

    private func jsonSchemaItems(for kind: FieldKind) -> [String: Any] {
        switch kind {
        case .string, .richText, .enumeration, .image:
            return ["type": "string"]
        case .number:
            return ["type": "number"]
        case .bool:
            return ["type": "boolean"]
        case .color:
            return [
                "type": "string",
                "pattern": "^#[0-9A-Fa-f]{6}$",
            ]
        case .date:
            return [
                "type": "string",
                "format": "date-time",
            ]
        case .array, .record, .file:
            return [:]
        }
    }
}

private extension FieldEditor {
    var schemaValue: String {
        switch self {
        case .automatic:
            return "automatic"
        case .singleLine:
            return "singleLine"
        case .multiLine:
            return "multiLine"
        case .date:
            return "date"
        case .enumeration:
            return "enumeration"
        case .color:
            return "color"
        case .currency:
            return "currency"
        case .stringList:
            return "stringList"
        }
    }
}
