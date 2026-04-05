import ArgumentParser
import Foundation
import SlopIPC

struct WriteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "write",
        abstract: "Update document fields"
    )

    @Argument(help: "Path to .slop file")
    var path: String

    @Option(name: .long, parsing: .upToNextOption, help: "Field key=value pairs (repeatable)")
    var field: [String] = []

    @Option(name: .long, help: "Merge JSON data")
    var data: String?

    @Option(name: .long, help: "Change theme")
    var theme: String?

    func run() throws {
        let params = SlopRequest.documentWrite(
            path: resolvePath(path),
            fields: field,
            data: data,
            theme: theme
        )
        let response = try sendRequest(method: .documentWrite, params: params)
        if let msg = response.result?.string("message") {
            print(msg)
        }
    }
}
