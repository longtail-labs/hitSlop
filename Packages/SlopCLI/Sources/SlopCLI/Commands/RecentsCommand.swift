import ArgumentParser
import Foundation
import SlopIPC

struct RecentsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recents",
        abstract: "Recently opened documents"
    )

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    @Flag(name: .long, help: "Clear recent documents")
    var clear = false

    func run() throws {
        if clear {
            let response = try sendRequest(method: .recentsClear)
            if let msg = response.result?.string("message") {
                print(msg)
            }
            return
        }

        let response = try sendRequest(method: .recentsList)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        if json {
            OutputFormatter.printJSON(result)
            return
        }

        guard let recents = result.values["recents"]?.arrayValue else {
            print("No recent documents")
            return
        }

        for (i, r) in recents.enumerated() {
            if let path = r.stringValue {
                print("\(i + 1). \(path)")
            }
        }
    }
}
