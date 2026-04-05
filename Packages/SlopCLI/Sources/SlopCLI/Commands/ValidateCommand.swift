import ArgumentParser
import Foundation
import SlopIPC

struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate a .slop document against its schema"
    )

    @Argument(help: "Path to .slop file")
    var path: String

    func run() throws {
        let params = SlopRequest.documentPath(resolvePath(path))
        let response = try sendRequest(method: .documentValidate, params: params)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        let valid = result.bool("valid") ?? false
        if valid {
            print("Valid")
        } else {
            print("Invalid:")
            if let errors = result.values["errors"]?.arrayValue {
                for err in errors {
                    if let msg = err.stringValue {
                        print("  - \(msg)")
                    }
                }
            }
            throw ExitCode.failure
        }
    }
}
