import Foundation
import SlopIPC

enum OutputFormatter {
    static func printJSON(_ params: JSONRPCParams) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(params.values),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    static func printTable(_ rows: [[String: String]], columns: [String]) {
        guard !rows.isEmpty else { return }

        // Calculate column widths
        var widths: [String: Int] = [:]
        for col in columns {
            widths[col] = col.count
        }
        for row in rows {
            for col in columns {
                let val = row[col] ?? ""
                widths[col] = max(widths[col] ?? 0, val.count)
            }
        }

        // Header
        let header = columns.map { col in
            col.uppercased().padding(toLength: widths[col] ?? 0, withPad: " ", startingAt: 0)
        }.joined(separator: "  ")
        print(header)
        print(String(repeating: "─", count: header.count))

        // Rows
        for row in rows {
            let line = columns.map { col in
                let val = row[col] ?? ""
                return val.padding(toLength: widths[col] ?? 0, withPad: " ", startingAt: 0)
            }.joined(separator: "  ")
            print(line)
        }
    }
}

/// Send a request to the running app and return the response.
func sendRequest(method: SlopMethod, params: JSONRPCParams? = nil) throws -> JSONRPCResponse {
    let client = SocketClient()
    guard client.isAppRunning else {
        throw CLIError.appNotRunning
    }

    let request = JSONRPCRequest(id: 1, method: method.rawValue, params: params)
    let response = try client.send(request)

    if let error = response.error {
        throw CLIError.serverError(error.message)
    }

    return response
}
