import ArgumentParser
import Foundation
import SlopIPC

struct CreateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new .slop document"
    )

    @Argument(help: "Template ID")
    var templateID: String

    @Argument(help: "Output path (default: current directory)")
    var outputPath: String?

    @Option(name: .long, help: "Initial data as JSON")
    var data: String?

    @Option(name: .long, help: "Theme name")
    var theme: String?

    @Flag(name: .long, help: "Open in app after creation")
    var open = false

    func run() throws {
        let resolvedPath: String?
        if let outputPath {
            resolvedPath = resolvePath(outputPath)
        } else {
            resolvedPath = nil
        }

        let params = SlopRequest.documentCreate(
            templateID: templateID,
            outputPath: resolvedPath,
            data: data,
            theme: theme,
            open: open
        )
        let response = try sendRequest(method: .documentCreate, params: params)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        if let path = result.string("path") {
            print("Created: \(path)")
        }
    }
}
