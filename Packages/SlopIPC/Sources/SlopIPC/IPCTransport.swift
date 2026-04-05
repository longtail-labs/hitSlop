import Foundation

/// Newline-delimited JSON framing for IPC messages.
public enum IPCTransport {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder = JSONDecoder()

    public static func encode(_ request: JSONRPCRequest) throws -> Data {
        var data = try encoder.encode(request)
        data.append(0x0A) // newline
        return data
    }

    public static func encode(_ response: JSONRPCResponse) throws -> Data {
        var data = try encoder.encode(response)
        data.append(0x0A) // newline
        return data
    }

    public static func decodeRequest(from data: Data) throws -> JSONRPCRequest {
        try decoder.decode(JSONRPCRequest.self, from: data)
    }

    public static func decodeResponse(from data: Data) throws -> JSONRPCResponse {
        try decoder.decode(JSONRPCResponse.self, from: data)
    }

    /// Socket path for the IPC connection.
    public static var socketPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hitslop/slop.sock").path
    }

    /// PID file path.
    public static var pidPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hitslop/slop.pid").path
    }

    /// Base directory for hitslop configuration.
    public static var hitslopDir: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hitslop").path
    }
}
