import ArgumentParser
import Foundation

public struct SlopCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "slop",
        abstract: "hitSlop command-line interface",
        subcommands: [
            StatusCommand.self,
            TemplatesCommand.self,
            SchemaCommand.self,
            ThemesCommand.self,
            CreateCommand.self,
            ReadCommand.self,
            WriteCommand.self,
            ValidateCommand.self,
            InfoCommand.self,
            OpenCommand.self,
            PickerCommand.self,
            RecentsCommand.self,
            ExportCommand.self,
            VersionCommand.self,
            IdentifyCommand.self,
        ]
    )

    public init() {}
}

/// Public entry point callable from the app's init().
public enum SlopCLI {
    public static var isCLIMode: Bool {
        let args = CommandLine.arguments
        if args.contains("--cli") { return true }
        return ProcessInfo.processInfo.processName == "slop"
    }

    public static func run() -> Never {
        var args = Array(CommandLine.arguments.dropFirst())
        args.removeAll { $0 == "--cli" }
        SlopCommand.main(args)
        exit(0)
    }
}
