import ArgumentParser
import Foundation
import SlopIPC

struct ReadCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "read",
        abstract: "Read and display document data"
    )

    @Argument(help: "Path to .slop file")
    var path: String

    @Flag(name: .long, help: "Raw envelope (no schema resolution)")
    var raw = false

    @Option(name: .long, help: "Single field key to read")
    var field: String?

    func run() throws {
        let params = SlopRequest.documentRead(
            path: resolvePath(path),
            raw: raw,
            field: field
        )
        let response = try sendRequest(method: .documentRead, params: params)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        OutputFormatter.printJSON(result)
    }
}
