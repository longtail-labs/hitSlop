import Foundation
import os

private let fieldValueLog = Logger(subsystem: "ca.long.tail.labs.slop", category: "FieldValue")

/// JSON-compatible value union for template data exchange between host and template.
/// Maps 1:1 with JSON. Schema-guided decoding disambiguates strings vs colors vs dates.
public enum FieldValue: Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case color(String)
    case date(Date)
    case image(String)
    case array([FieldValue])
    case record([String: FieldValue])
    case null
}

// MARK: - Convenience Accessors

extension FieldValue {
    public var asString: String? {
        if case .string(let v) = self { return v }
        if case .color(let v) = self { return v }
        if case .image(let v) = self { return v }
        return nil
    }

    public var asNumber: Double? {
        if case .number(let v) = self { return v }
        return nil
    }

    public var asBool: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    public var asDate: Date? {
        if case .date(let v) = self { return v }
        return nil
    }

    public var asArray: [FieldValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    public var asRecord: [String: FieldValue]? {
        if case .record(let v) = self { return v }
        return nil
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

// MARK: - Codable

extension FieldValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    private enum ValueType: String, Codable {
        case string, number, bool, color, date, image, array, record, null
    }

    public init(from decoder: Decoder) throws {
        // Try unkeyed first for JSON-native values
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        // For schema-guided decoding, use the keyed format
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
           let type = try? keyed.decode(ValueType.self, forKey: .type) {
            switch type {
            case .string:
                self = .string(try keyed.decode(String.self, forKey: .value))
            case .number:
                self = .number(try keyed.decode(Double.self, forKey: .value))
            case .bool:
                self = .bool(try keyed.decode(Bool.self, forKey: .value))
            case .color:
                self = .color(try keyed.decode(String.self, forKey: .value))
            case .date:
                self = .date(try keyed.decode(Date.self, forKey: .value))
            case .image:
                self = .image(try keyed.decode(String.self, forKey: .value))
            case .array:
                self = .array(try keyed.decode([FieldValue].self, forKey: .value))
            case .record:
                self = .record(try keyed.decode([String: FieldValue].self, forKey: .value))
            case .null:
                self = .null
            }
            return
        }

        // Fallback: infer type from JSON value
        if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Double.self) {
            self = .number(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([FieldValue].self) {
            self = .array(v)
        } else if let v = try? container.decode([String: FieldValue].self) {
            self = .record(v)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let v):
            try container.encode(ValueType.string, forKey: .type)
            try container.encode(v, forKey: .value)
        case .number(let v):
            try container.encode(ValueType.number, forKey: .type)
            try container.encode(v, forKey: .value)
        case .bool(let v):
            try container.encode(ValueType.bool, forKey: .type)
            try container.encode(v, forKey: .value)
        case .color(let v):
            try container.encode(ValueType.color, forKey: .type)
            try container.encode(v, forKey: .value)
        case .date(let v):
            try container.encode(ValueType.date, forKey: .type)
            try container.encode(v, forKey: .value)
        case .image(let v):
            try container.encode(ValueType.image, forKey: .type)
            try container.encode(v, forKey: .value)
        case .array(let v):
            try container.encode(ValueType.array, forKey: .type)
            try container.encode(v, forKey: .value)
        case .record(let v):
            try container.encode(ValueType.record, forKey: .type)
            try container.encode(v, forKey: .value)
        case .null:
            try container.encode(ValueType.null, forKey: .type)
        }
    }
}

// MARK: - Schema Guided JSON Conversion

extension FieldValue {
    private static func makeISO8601Formatter() -> ISO8601DateFormatter {
        ISO8601DateFormatter()
    }

    public static func decodeRecord(
        _ rawObject: [String: JSONValue],
        schema: Schema
    ) -> [String: FieldValue] {
        var result = schema.defaultValues()

        for (key, rawValue) in rawObject {
            let descriptor = schema.field(forKey: key)
            result[key] = decode(rawValue, descriptor: descriptor)
        }

        return result
    }

    public static func encodeRecord(
        _ values: [String: FieldValue],
        schema: Schema
    ) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]

        for field in schema.allFields {
            // File fields are sidecar references stored in the schema, not in JSON data
            guard field.kind != .file else { continue }
            let value = values[field.key] ?? field.defaultValue
            result[field.key] = encode(value, descriptor: field)
        }

        for (key, value) in values where result[key] == nil {
            result[key] = fallbackEncode(value)
        }

        return result
    }

    public static func decode(_ raw: JSONValue, descriptor: FieldDescriptor?) -> FieldValue {
        guard let descriptor else {
            return fallbackDecode(raw)
        }

        switch descriptor.kind {
        case .string, .richText, .enumeration:
            if case .null = raw { return descriptor.defaultValue }
            guard let v = raw.stringValue else {
                fieldValueLog.warning("Field '\(descriptor.key)': expected string, got \(raw.typeName) — using default")
                return .string(descriptor.defaultValue.asString ?? "")
            }
            return .string(v)

        case .number:
            if case .null = raw { return descriptor.defaultValue }
            guard let v = raw.numberValue else {
                fieldValueLog.warning("Field '\(descriptor.key)': expected number, got \(raw.typeName) — using default")
                return .number(descriptor.defaultValue.asNumber ?? 0)
            }
            return .number(v)

        case .bool:
            if case .null = raw { return descriptor.defaultValue }
            guard let v = raw.boolValue else {
                fieldValueLog.warning("Field '\(descriptor.key)': expected bool, got \(raw.typeName) — using default")
                return .bool(descriptor.defaultValue.asBool ?? false)
            }
            return .bool(v)

        case .color:
            if case .null = raw { return descriptor.defaultValue }
            guard let v = raw.stringValue else {
                fieldValueLog.warning("Field '\(descriptor.key)': expected color string, got \(raw.typeName) — using default")
                return .color(descriptor.defaultValue.asString ?? "#808080")
            }
            return .color(v)

        case .date:
            if case .null = raw { return descriptor.defaultValue }
            if let rawString = raw.stringValue,
               let date = makeISO8601Formatter().date(from: rawString) {
                return .date(date)
            }
            fieldValueLog.warning("Field '\(descriptor.key)': expected ISO8601 date string, got \(raw.typeName) — using default")
            return descriptor.defaultValue

        case .image:
            if case .null = raw { return descriptor.defaultValue }
            guard let v = raw.stringValue else {
                fieldValueLog.warning("Field '\(descriptor.key)': expected image path string, got \(raw.typeName) — using default")
                return .image(descriptor.defaultValue.asString ?? "")
            }
            return .image(v)

        case .array:
            guard case .array(let rawItems) = raw else {
                if case .null = raw { return descriptor.defaultValue }
                fieldValueLog.warning("Field '\(descriptor.key)': expected array, got \(raw.typeName) — using default")
                return descriptor.defaultValue
            }
            let itemSchema = descriptor.itemSchema
            let itemKind = descriptor.arrayItemKind
            let items = rawItems.map { item -> FieldValue in
                if let itemSchema {
                    guard case .object(let rawRecord) = item else { return .record(itemSchema.defaultValues()) }
                    return .record(decodeRecord(rawRecord, schema: itemSchema))
                }
                if let itemKind {
                    return decodePrimitiveArrayItem(item, kind: itemKind)
                }
                return fallbackDecode(item)
            }
            return .array(items)

        case .record:
            guard case .object(let rawRecord) = raw else {
                if case .null = raw { return descriptor.defaultValue }
                fieldValueLog.warning("Field '\(descriptor.key)': expected object, got \(raw.typeName) — using default")
                return descriptor.defaultValue
            }
            let recordSchema = descriptor.recordSchema ?? Schema(sections: [])
            return .record(decodeRecord(rawRecord, schema: recordSchema))

        case .file:
            // File fields are sidecar references — the filename lives in the schema's
            // FileFieldDescriptor.defaultFilename, not in JSON data. Always return default.
            return descriptor.defaultValue
        }
    }

    public static func encode(_ value: FieldValue, descriptor: FieldDescriptor?) -> JSONValue {
        guard let descriptor else {
            return fallbackEncode(value)
        }

        switch descriptor.kind {
        case .string, .richText, .enumeration:
            return value.asString.map(JSONValue.string) ?? .null

        case .number:
            return value.asNumber.map(JSONValue.number) ?? .null

        case .bool:
            return value.asBool.map(JSONValue.bool) ?? .null

        case .color:
            return value.asString.map(JSONValue.string) ?? .null

        case .date:
            return value.asDate.map { .string(makeISO8601Formatter().string(from: $0)) } ?? .null

        case .image:
            return value.asString.map(JSONValue.string) ?? .null

        case .array:
            let itemSchema = descriptor.itemSchema
            let itemKind = descriptor.arrayItemKind
            let rawItems = value.asArray?.map { item -> JSONValue in
                if let itemSchema {
                    guard case .record(let recordValues) = item else { return .object(itemSchema.defaultValues().mapValues(fallbackEncode)) }
                    return .object(encodeRecord(recordValues, schema: itemSchema))
                }
                if let itemKind {
                    return encodePrimitiveArrayItem(item, kind: itemKind)
                }
                return fallbackEncode(item)
            } ?? []
            return .array(rawItems)

        case .record:
            let recordSchema = descriptor.recordSchema
            guard case .record(let recordValues) = value else { return .null }
            if let recordSchema {
                return .object(encodeRecord(recordValues, schema: recordSchema))
            }
            return .object(recordValues.mapValues(fallbackEncode))

        case .file:
            // File fields are sidecar references — the filename lives in the schema's
            // FileFieldDescriptor.defaultFilename, not in JSON data. Skip encoding.
            return .null
        }
    }

    public static func fallbackDecode(_ raw: JSONValue) -> FieldValue {
        switch raw {
        case .string(let value):
            return .string(value)
        case .number(let value):
            return .number(value)
        case .bool(let value):
            return .bool(value)
        case .object(let value):
            return .record(value.mapValues(fallbackDecode))
        case .array(let value):
            return .array(value.map(fallbackDecode))
        case .null:
            return .null
        }
    }

    public static func fallbackEncode(_ value: FieldValue) -> JSONValue {
        switch value {
        case .string(let raw):
            return .string(raw)
        case .number(let raw):
            return .number(raw)
        case .bool(let raw):
            return .bool(raw)
        case .color(let raw):
            return .string(raw)
        case .date(let raw):
            return .string(makeISO8601Formatter().string(from: raw))
        case .image(let raw):
            return .string(raw)
        case .array(let raw):
            return .array(raw.map(fallbackEncode))
        case .record(let raw):
            return .object(raw.mapValues(fallbackEncode))
        case .null:
            return .null
        }
    }

    private static func decodePrimitiveArrayItem(_ raw: JSONValue, kind: FieldKind) -> FieldValue {
        switch kind {
        case .string, .richText, .enumeration:
            return raw.stringValue.map(FieldValue.string) ?? fallbackDecode(raw)
        case .number:
            return raw.numberValue.map(FieldValue.number) ?? fallbackDecode(raw)
        case .bool:
            return raw.boolValue.map(FieldValue.bool) ?? fallbackDecode(raw)
        case .color:
            return raw.stringValue.map(FieldValue.color) ?? fallbackDecode(raw)
        case .date:
            if let rawString = raw.stringValue,
               let date = makeISO8601Formatter().date(from: rawString) {
                return .date(date)
            }
            return fallbackDecode(raw)
        case .image:
            return raw.stringValue.map(FieldValue.image) ?? fallbackDecode(raw)
        case .array, .record, .file:
            return fallbackDecode(raw)
        }
    }

    private static func encodePrimitiveArrayItem(_ value: FieldValue, kind: FieldKind) -> JSONValue {
        switch kind {
        case .string, .richText, .enumeration:
            return value.asString.map(JSONValue.string) ?? fallbackEncode(value)
        case .number:
            return value.asNumber.map(JSONValue.number) ?? fallbackEncode(value)
        case .bool:
            return value.asBool.map(JSONValue.bool) ?? fallbackEncode(value)
        case .color:
            return value.asString.map(JSONValue.string) ?? fallbackEncode(value)
        case .date:
            return value.asDate.map { .string(makeISO8601Formatter().string(from: $0)) } ?? fallbackEncode(value)
        case .image:
            return value.asString.map(JSONValue.string) ?? fallbackEncode(value)
        case .array, .record, .file:
            return fallbackEncode(value)
        }
    }
}

extension JSONValue {
    var typeName: String {
        switch self {
        case .string: "string"
        case .number: "number"
        case .bool: "bool"
        case .object: "object"
        case .array: "array"
        case .null: "null"
        }
    }
}

private extension JSONValue {
    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
}

// MARK: - ExpressibleBy Literals

extension FieldValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension FieldValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .number(value) }
}

extension FieldValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension FieldValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension FieldValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: FieldValue...) { self = .array(elements) }
}
