import ArgumentParser
import Foundation
import SlopIPC

struct IdentifyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "identify",
        abstract: "Print configuration paths"
    )

    func run() throws {
        print("Socket:     \(IPCTransport.socketPath)")
        print("PID file:   \(IPCTransport.pidPath)")
        print("Config dir: \(IPCTransport.hitslopDir)")
        print("Templates:  \(IPCTransport.hitslopDir)/templates")
        print("Themes:     \(IPCTransport.hitslopDir)/themes")
        print("CLI bin:    \(IPCTransport.hitslopDir)/bin/slop")
    }
}
