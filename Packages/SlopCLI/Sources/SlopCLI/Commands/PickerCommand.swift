import ArgumentParser
import Foundation
import SlopIPC

struct PickerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "picker",
        abstract: "Show the template picker window"
    )

    func run() throws {
        let response = try sendRequest(method: .pickerShow)
        if let msg = response.result?.string("message") {
            print(msg)
        }
    }
}
