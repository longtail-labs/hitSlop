import Foundation

/// JSON-RPC 2.0 request envelope.
public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: Int
    public let method: String
    public let params: JSONRPCParams?

    public init(id: Int, method: String, params: JSONRPCParams? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 response envelope.
public struct JSONRPCResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: Int
    public let result: JSONRPCParams?
    public let error: JSONRPCError?

    public init(id: Int, result: JSONRPCParams) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: Int, error: JSONRPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }
}

/// JSON-RPC 2.0 error object.
public struct JSONRPCError: Codable, Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    public static let methodNotFound = JSONRPCError(code: -32601, message: "Method not found")
    public static let invalidParams = JSONRPCError(code: -32602, message: "Invalid params")
    public static func internalError(_ message: String) -> JSONRPCError {
        JSONRPCError(code: -32603, message: message)
    }
}

/// Type-erased JSON params/result container using `[String: AnyCodable]`.
public struct JSONRPCParams: Codable, Sendable {
    public let values: [String: AnyCodable]

    public init(_ values: [String: AnyCodable]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = try container.decode([String: AnyCodable].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    public func string(_ key: String) -> String? {
        values[key]?.stringValue
    }

    public func int(_ key: String) -> Int? {
        values[key]?.intValue
    }

    public func double(_ key: String) -> Double? {
        values[key]?.doubleValue
    }

    public func bool(_ key: String) -> Bool? {
        values[key]?.boolValue
    }

    public static let empty = JSONRPCParams([:])
}

/// A type-erased Codable value for JSON interchange.
public enum AnyCodable: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodable])
    case object([String: AnyCodable])
    case null

    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    public var intValue: Int? {
        if case .int(let v) = self { return v }
        if case .double(let v) = self { return Int(exactly: v) }
        return nil
    }

    public var doubleValue: Double? {
        if case .double(let v) = self { return v }
        if case .int(let v) = self { return Double(v) }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    public var arrayValue: [AnyCodable]? {
        if case .array(let v) = self { return v }
        return nil
    }

    public var objectValue: [String: AnyCodable]? {
        if case .object(let v) = self { return v }
        return nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([AnyCodable].self) {
            self = .array(v)
        } else if let v = try? container.decode([String: AnyCodable].self) {
            self = .object(v)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}
