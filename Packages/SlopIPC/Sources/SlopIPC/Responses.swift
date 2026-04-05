import Foundation

// MARK: - Response Helpers

/// Helpers to build JSONRPCParams results for each method.
public enum SlopResponse {
    public static func status(running: Bool, pid: Int, version: String) -> JSONRPCParams {
        JSONRPCParams([
            "running": .bool(running),
            "pid": .int(pid),
            "version": .string(version),
        ])
    }

    public static func message(_ text: String) -> JSONRPCParams {
        JSONRPCParams(["message": .string(text)])
    }

    public static func templateList(_ templates: [[String: AnyCodable]]) -> JSONRPCParams {
        JSONRPCParams(["templates": .array(templates.map { .object($0) })])
    }

    public static func templateSchema(_ schema: [String: AnyCodable]) -> JSONRPCParams {
        JSONRPCParams(["schema": .object(schema)])
    }

    public static func themeList(_ themes: [[String: AnyCodable]]) -> JSONRPCParams {
        JSONRPCParams(["themes": .array(themes.map { .object($0) })])
    }

    public static func documentRead(_ data: [String: AnyCodable]) -> JSONRPCParams {
        JSONRPCParams(data)
    }

    public static func documentInfo(_ info: [String: AnyCodable]) -> JSONRPCParams {
        JSONRPCParams(info)
    }

    public static func documentCreate(path: String) -> JSONRPCParams {
        JSONRPCParams(["path": .string(path)])
    }

    public static func validate(valid: Bool, errors: [String]) -> JSONRPCParams {
        JSONRPCParams([
            "valid": .bool(valid),
            "errors": .array(errors.map { .string($0) }),
        ])
    }

    public static func documentExport(path: String, format: String) -> JSONRPCParams {
        JSONRPCParams(["path": .string(path), "format": .string(format)])
    }

    public static func recentsList(_ paths: [String]) -> JSONRPCParams {
        JSONRPCParams(["recents": .array(paths.map { .string($0) })])
    }

    public static func themeWrite(id: String, warnings: [String]) -> JSONRPCParams {
        JSONRPCParams([
            "id": .string(id),
            "warnings": .array(warnings.map { .string($0) }),
        ])
    }

    public static func themeDerive(themeFile: [String: AnyCodable], suggestedID: String) -> JSONRPCParams {
        JSONRPCParams([
            "themeFile": .object(themeFile),
            "suggestedID": .string(suggestedID),
        ])
    }

    public static func themeValidate(isValid: Bool, warnings: [String]) -> JSONRPCParams {
        JSONRPCParams([
            "isValid": .bool(isValid),
            "warnings": .array(warnings.map { .string($0) }),
        ])
    }

    public static func ok() -> JSONRPCParams {
        JSONRPCParams(["ok": .bool(true)])
    }
}
