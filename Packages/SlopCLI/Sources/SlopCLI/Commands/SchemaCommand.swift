import ArgumentParser
import Foundation
import SlopIPC

struct SchemaCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schema",
        abstract: "Print template schema"
    )

    @Argument(help: "Template ID")
    var templateID: String

    @Flag(name: .long, help: "Output full JSON Schema")
    var jsonSchema = false

    @Flag(name: .long, help: "Output field list only")
    var fields = false

    func run() throws {
        let params = SlopRequest.templateSchema(templateID: templateID)
        let response = try sendRequest(method: .templateSchema, params: params)
        guard let result = response.result else {
            throw CLIError.invalidResponse("No result")
        }

        if jsonSchema || !fields {
            OutputFormatter.printJSON(result)
            return
        }

        // Fields-only mode
        guard let schema = result.values["schema"]?.objectValue,
              let fieldList = schema["fields"]?.arrayValue else {
            OutputFormatter.printJSON(result)
            return
        }

        var rows: [[String: String]] = []
        for field in fieldList {
            guard let obj = field.objectValue else { continue }
            var row: [String: String] = [:]
            row["key"] = obj["key"]?.stringValue ?? ""
            row["label"] = obj["label"]?.stringValue ?? ""
            row["type"] = obj["type"]?.stringValue ?? ""
            row["required"] = obj["required"]?.boolValue == true ? "yes" : "no"
            rows.append(row)
        }

        OutputFormatter.printTable(rows, columns: ["key", "label", "type", "required"])
    }
}
