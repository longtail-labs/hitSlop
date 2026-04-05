import ArgumentParser
import Foundation
import SlopIPC

struct TemplatesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "templates",
        abstract: "List installed templates"
    )

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let response = try sendRequest(method: .templateList)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        if json {
            OutputFormatter.printJSON(result)
            return
        }

        guard let templates = result.values["templates"]?.arrayValue else {
            print("No templates found")
            return
        }

        var rows: [[String: String]] = []
        for t in templates {
            guard let obj = t.objectValue else { continue }
            var row: [String: String] = [:]
            row["id"] = obj["id"]?.stringValue ?? ""
            row["name"] = obj["name"]?.stringValue ?? ""
            row["version"] = obj["version"]?.stringValue ?? ""
            var tags: [String] = []
            if obj["builtIn"]?.boolValue == true { tags.append("built-in") }
            if obj["scripted"]?.boolValue == true { tags.append("scripted") }
            row["type"] = tags.isEmpty ? "external" : tags.joined(separator: ", ")
            if let cat = obj["category"]?.stringValue { row["category"] = cat }
            rows.append(row)
        }

        OutputFormatter.printTable(rows, columns: ["id", "name", "version", "type"])
    }
}
