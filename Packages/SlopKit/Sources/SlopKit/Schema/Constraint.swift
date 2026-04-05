import Foundation

/// Validation constraints for template fields.
public enum Constraint: Codable, Sendable, Hashable {
    case min(Double)
    case max(Double)
    case minLength(Int)
    case maxLength(Int)
    case minItems(Int)
    case maxItems(Int)
    case regex(String)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    private enum ConstraintType: String, Codable {
        case min, max, minLength, maxLength, minItems, maxItems, regex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConstraintType.self, forKey: .type)
        switch type {
        case .min: self = .min(try container.decode(Double.self, forKey: .value))
        case .max: self = .max(try container.decode(Double.self, forKey: .value))
        case .minLength: self = .minLength(try container.decode(Int.self, forKey: .value))
        case .maxLength: self = .maxLength(try container.decode(Int.self, forKey: .value))
        case .minItems: self = .minItems(try container.decode(Int.self, forKey: .value))
        case .maxItems: self = .maxItems(try container.decode(Int.self, forKey: .value))
        case .regex: self = .regex(try container.decode(String.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .min(let v):
            try container.encode(ConstraintType.min, forKey: .type)
            try container.encode(v, forKey: .value)
        case .max(let v):
            try container.encode(ConstraintType.max, forKey: .type)
            try container.encode(v, forKey: .value)
        case .minLength(let v):
            try container.encode(ConstraintType.minLength, forKey: .type)
            try container.encode(v, forKey: .value)
        case .maxLength(let v):
            try container.encode(ConstraintType.maxLength, forKey: .type)
            try container.encode(v, forKey: .value)
        case .minItems(let v):
            try container.encode(ConstraintType.minItems, forKey: .type)
            try container.encode(v, forKey: .value)
        case .maxItems(let v):
            try container.encode(ConstraintType.maxItems, forKey: .type)
            try container.encode(v, forKey: .value)
        case .regex(let v):
            try container.encode(ConstraintType.regex, forKey: .type)
            try container.encode(v, forKey: .value)
        }
    }
}
