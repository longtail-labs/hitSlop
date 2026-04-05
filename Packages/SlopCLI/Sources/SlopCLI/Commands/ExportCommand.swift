import ArgumentParser
import Foundation
import SlopIPC

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export a .slop document to PDF or PNG"
    )

    @Argument(help: "Path to .slop file")
    var path: String

    @Option(name: .long, help: "Output format: pdf or png (default: png)")
    var format: String = "png"

    @Option(name: .long, help: "Output path (default: alongside .slop)")
    var output: String?

    @Option(name: .long, help: "Override theme")
    var theme: String?

    @Option(name: .long, help: "PNG scale factor (default: 2)")
    var scale: Int?

    func run() throws {
        let resolvedOutput: String?
        if let output {
            resolvedOutput = resolvePath(output)
        } else {
            resolvedOutput = nil
        }

        let params = SlopRequest.documentExport(
            path: resolvePath(path),
            format: format,
            output: resolvedOutput,
            theme: theme,
            scale: scale
        )
        let response = try sendRequest(method: .documentExport, params: params)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        if let outputPath = result.string("path"),
           let fmt = result.string("format") {
            print("Exported \(fmt.uppercased()): \(outputPath)")
        }
    }
}
