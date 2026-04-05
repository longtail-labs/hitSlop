import ArgumentParser
import Foundation
import SlopIPC

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print version information"
    )

    func run() throws {
        // Try to get version from running app
        let client = SocketClient()
        if client.isAppRunning {
            if let response = try? sendRequest(method: .status),
               let version = response.result?.string("version") {
                print("slop \(version)")
                return
            }
        }

        // Fallback: print CLI version
        print("slop (app not running — version unknown)")
    }
}
