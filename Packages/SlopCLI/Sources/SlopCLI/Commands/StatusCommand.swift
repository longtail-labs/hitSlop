import ArgumentParser
import Foundation
import SlopIPC

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Check if the hitSlop app is running"
    )

    func run() throws {
        let client = SocketClient()
        guard client.isAppRunning else {
            print("hitSlop app is not running")
            throw ExitCode.failure
        }

        let response = try sendRequest(method: .status)
        guard let result = response.result else {
            print("hitSlop app is running (no status details)")
            return
        }

        let running = result.bool("running") ?? false
        let pid = result.int("pid") ?? 0
        let version = result.string("version") ?? "unknown"

        if running {
            print("hitSlop app is running (PID \(pid), version \(version))")
        } else {
            print("hitSlop app is not running")
        }
    }
}
