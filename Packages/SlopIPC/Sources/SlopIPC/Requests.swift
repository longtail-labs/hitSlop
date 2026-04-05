import Foundation

// MARK: - Request Param Builders

/// Helpers to build JSONRPCParams for each method.
public enum SlopRequest {
    public static func templateSchema(templateID: String) -> JSONRPCParams {
        JSONRPCParams(["templateID": .string(templateID)])
    }

    public static func documentCreate(
        templateID: String,
        outputPath: String?,
        data: String?,
        theme: String?,
        open: Bool
    ) -> JSONRPCParams {
        var values: [String: AnyCodable] = ["templateID": .string(templateID)]
        if let outputPath { values["outputPath"] = .string(outputPath) }
        if let data { values["data"] = .string(data) }
        if let theme { values["theme"] = .string(theme) }
        values["open"] = .bool(open)
        return JSONRPCParams(values)
    }

    public static func documentRead(path: String, raw: Bool, field: String?) -> JSONRPCParams {
        var values: [String: AnyCodable] = ["path": .string(path), "raw": .bool(raw)]
        if let field { values["field"] = .string(field) }
        return JSONRPCParams(values)
    }

    public static func documentWrite(
        path: String,
        fields: [String],
        data: String?,
        theme: String?
    ) -> JSONRPCParams {
        var values: [String: AnyCodable] = ["path": .string(path)]
        if !fields.isEmpty {
            values["fields"] = .array(fields.map { .string($0) })
        }
        if let data { values["data"] = .string(data) }
        if let theme { values["theme"] = .string(theme) }
        return JSONRPCParams(values)
    }

    public static func documentPath(_ path: String) -> JSONRPCParams {
        JSONRPCParams(["path": .string(path)])
    }

    public static func documentExport(
        path: String,
        format: String,
        output: String?,
        theme: String?,
        scale: Int?
    ) -> JSONRPCParams {
        var values: [String: AnyCodable] = [
            "path": .string(path),
            "format": .string(format),
        ]
        if let output { values["output"] = .string(output) }
        if let theme { values["theme"] = .string(theme) }
        if let scale { values["scale"] = .int(scale) }
        return JSONRPCParams(values)
    }

    public static func recentsList(clear: Bool) -> JSONRPCParams {
        JSONRPCParams(["clear": .bool(clear)])
    }
}
