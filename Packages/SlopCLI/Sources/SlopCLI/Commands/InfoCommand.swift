import ArgumentParser
import Foundation
import SlopIPC

struct InfoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show document info"
    )

    @Argument(help: "Path to .slop file")
    var path: String

    func run() throws {
        let params = SlopRequest.documentPath(resolvePath(path))
        let response = try sendRequest(method: .documentInfo, params: params)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        let templateID = result.string("templateID") ?? "unknown"
        let version = result.string("templateVersion") ?? "unknown"
        let name = result.string("templateName")
        let fieldCount = result.int("fieldCount") ?? 0
        let theme = result.string("theme")

        print("Template:    \(templateID)")
        if let name { print("Name:        \(name)") }
        print("Version:     \(version)")
        print("Fields:      \(fieldCount)")
        if let theme { print("Theme:       \(theme)") }
    }
}
