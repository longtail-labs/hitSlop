import ArgumentParser
import Foundation
import SlopIPC

struct ThemesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "themes",
        abstract: "Manage themes",
        subcommands: [
            ThemesListCommand.self,
            ThemesCreateCommand.self,
            ThemesDeriveCommand.self,
            ThemesValidateCommand.self,
            ThemesDeleteCommand.self,
        ],
        defaultSubcommand: ThemesListCommand.self
    )
}

// MARK: - List

struct ThemesListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available themes"
    )

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let response = try sendRequest(method: .themeList)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        if json {
            OutputFormatter.printJSON(result)
            return
        }

        guard let themes = result.values["themes"]?.arrayValue else {
            print("No themes found")
            return
        }

        var rows: [[String: String]] = []
        for t in themes {
            guard let obj = t.objectValue else { continue }
            let id = obj["id"]?.stringValue ?? "unknown"
            let name = obj["name"]?.stringValue ?? id
            let group = obj["group"]?.stringValue ?? ""
            let source = obj["source"]?.stringValue ?? ""
            rows.append(["id": id, "name": name, "group": group, "source": source])
        }
        OutputFormatter.printTable(rows, columns: ["id", "name", "group", "source"])
    }
}

// MARK: - Create

struct ThemesCreateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a theme from explicit colors"
    )

    @Argument(help: "Theme ID (used as filename)")
    var id: String

    @Option(help: "Background color (hex)")
    var background: String

    @Option(help: "Foreground/text color (hex)")
    var foreground: String

    @Option(help: "Secondary text color (hex)")
    var secondary: String

    @Option(help: "Accent/highlight color (hex)")
    var accent: String

    @Option(help: "Surface/card color (hex)")
    var surface: String

    @Option(help: "Divider/border color (hex)")
    var divider: String

    @Option(help: "Display name")
    var displayName: String?

    @Option(help: "Theme group (e.g. Dark, Light, Warm)")
    var group: String?

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let theme: [String: Any] = [
            "displayName": displayName ?? id.split(separator: "-").map { $0.capitalized }.joined(separator: " "),
            "group": group ?? "Other",
            "background": normalizeHex(background),
            "foreground": normalizeHex(foreground),
            "secondary": normalizeHex(secondary),
            "accent": normalizeHex(accent),
            "surface": normalizeHex(surface),
            "divider": normalizeHex(divider),
        ]

        let data = try JSONSerialization.data(withJSONObject: theme, options: [.prettyPrinted, .sortedKeys])
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hitslop/themes")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(id).theme")
        try data.write(to: url, options: .atomic)

        if json {
            let output: [String: Any] = ["id": id, "path": url.path]
            let jsonData = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted])
            print(String(data: jsonData, encoding: .utf8) ?? "{}")
        } else {
            print("Created theme '\(id)' at \(url.path)")

            // Try to validate via IPC if app is running
            if let jsonStr = String(data: data, encoding: .utf8) {
                let params = JSONRPCParams([
                    "themeFile": .string(jsonStr),
                ])
                if let response = try? sendRequest(method: .themeValidate, params: params),
                   let result = response.result {
                    if let warnings = result.values["warnings"]?.arrayValue, !warnings.isEmpty {
                        for w in warnings {
                            print("  Warning: \(w.stringValue ?? "")")
                        }
                    } else {
                        print("  Validation passed")
                    }
                }
            }
        }
    }

    private func normalizeHex(_ hex: String) -> String {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !h.hasPrefix("#") { h = "#\(h)" }
        return h
    }
}

// MARK: - Derive

struct ThemesDeriveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "derive",
        abstract: "Derive a theme from a single accent color"
    )

    @Argument(help: "Theme ID (used as filename)")
    var id: String

    @Option(help: "Accent color (hex)")
    var accent: String

    @Flag(name: .long, help: "Generate light mode theme")
    var light = false

    @Flag(name: .long, help: "Output as JSON without saving")
    var json = false

    @Option(help: "Display name")
    var displayName: String?

    @Option(help: "Theme group (e.g. Dark, Light, Warm)")
    var group: String?

    func run() throws {
        let params = JSONRPCParams([
            "accent": .string(accent),
            "isDark": .bool(!light),
        ])
        let response = try sendRequest(method: .themeDerive, params: params)
        guard let result = response.result,
              let themeObj = result.values["themeFile"]?.objectValue
        else {
            throw CLIError.invalidResponse("No theme derived")
        }

        // Add display name and group
        var theme = themeObj
        let resolvedName = displayName ?? id.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
        let resolvedGroup = group ?? (light ? "Light" : "Dark")
        theme["displayName"] = .string(resolvedName)
        theme["group"] = .string(resolvedGroup)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(theme)

        if json {
            print(String(data: data, encoding: .utf8) ?? "{}")
            return
        }

        // Save to ~/.hitslop/themes/
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hitslop/themes")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(id).theme")
        try data.write(to: url, options: .atomic)

        print("Derived theme '\(id)' from accent \(accent)")
        print("  Saved to \(url.path)")

        // Validate
        if let jsonStr = String(data: data, encoding: .utf8) {
            let validateParams = JSONRPCParams([
                "themeFile": .string(jsonStr),
            ])
            if let validateResponse = try? sendRequest(method: .themeValidate, params: validateParams),
               let validateResult = validateResponse.result {
                if let warnings = validateResult.values["warnings"]?.arrayValue, !warnings.isEmpty {
                    for w in warnings {
                        print("  Warning: \(w.stringValue ?? "")")
                    }
                } else {
                    print("  Validation passed")
                }
            }
        }
    }
}

// MARK: - Validate

struct ThemesValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate a theme file for readability"
    )

    @Argument(help: "Path to .theme file")
    var path: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let resolved = resolvePath(path)
        let url = URL(fileURLWithPath: resolved)
        let data = try Data(contentsOf: url)
        guard let jsonStr = String(data: data, encoding: .utf8) else {
            throw CLIError.invalidResponse("Cannot read theme file")
        }

        let params = JSONRPCParams([
            "themeFile": .string(jsonStr),
        ])
        let response = try sendRequest(method: .themeValidate, params: params)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        if json {
            OutputFormatter.printJSON(result)
            return
        }

        let isValid = result.values["isValid"]?.boolValue ?? false
        let warnings = result.values["warnings"]?.arrayValue ?? []

        if isValid {
            print("Theme is valid")
        } else {
            print("Theme has issues:")
            for w in warnings {
                print("  - \(w.stringValue ?? "")")
            }
        }
    }
}

// MARK: - Delete

struct ThemesDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a user theme"
    )

    @Argument(help: "Theme ID to delete")
    var id: String

    func run() throws {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hitslop/themes/\(id).theme")

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CLIError.invalidResponse("Theme '\(id)' not found at \(url.path)")
        }

        try FileManager.default.removeItem(at: url)
        print("Deleted theme '\(id)'")
    }
}
