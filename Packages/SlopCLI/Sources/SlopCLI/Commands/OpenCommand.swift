import ArgumentParser
import Foundation
import SlopIPC

struct OpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open a .slop document in the app"
    )

    @Argument(help: "Path to .slop file")
    var path: String

    func run() throws {
        let params = SlopRequest.documentPath(resolvePath(path))
        let response = try sendRequest(method: .documentOpen, params: params)
        if let msg = response.result?.string("message") {
            print(msg)
        }
    }
}
