import Foundation
import SlopKit

/// Raw document envelope decoded before a schema is resolved.
public struct SlopFileEnvelope: Codable, Sendable {
    public var templateID: String
    public var templateVersion: String
    public var data: [String: JSONValue]
    public var theme: String?
    public var alwaysOnTop: Bool?
    public var windowShape: WindowShape?

    public init(
        templateID: String,
        templateVersion: String,
        data: [String: JSONValue] = [:],
        theme: String? = nil,
        alwaysOnTop: Bool? = nil,
        windowShape: WindowShape? = nil
    ) {
        self.templateID = templateID
        self.templateVersion = templateVersion
        self.data = data
        self.theme = theme
        self.alwaysOnTop = alwaysOnTop
        self.windowShape = windowShape
    }
}

/// Typed `.slop` document containing schema-guided field values.
public struct SlopFile: Sendable, Equatable {
    public var templateID: String
    public var templateVersion: String
    public var data: [String: FieldValue]
    public var theme: String?
    public var alwaysOnTop: Bool?
    public var windowShape: WindowShape?

    public init(
        templateID: String,
        templateVersion: String,
        data: [String: FieldValue] = [:],
        theme: String? = nil,
        alwaysOnTop: Bool? = nil,
        windowShape: WindowShape? = nil
    ) {
        self.templateID = templateID
        self.templateVersion = templateVersion
        self.data = data
        self.theme = theme
        self.alwaysOnTop = alwaysOnTop
        self.windowShape = windowShape
    }

    public init(envelope: SlopFileEnvelope, schema: Schema) {
        self.init(
            templateID: envelope.templateID,
            templateVersion: envelope.templateVersion,
            data: FieldValue.decodeRecord(envelope.data, schema: schema),
            theme: envelope.theme,
            alwaysOnTop: envelope.alwaysOnTop,
            windowShape: envelope.windowShape
        )
    }

    public func envelope(schema: Schema) -> SlopFileEnvelope {
        SlopFileEnvelope(
            templateID: templateID,
            templateVersion: templateVersion,
            data: FieldValue.encodeRecord(data, schema: schema),
            theme: theme,
            alwaysOnTop: alwaysOnTop,
            windowShape: windowShape
        )
    }

    /// Returns the URL of `slop.json` inside a `.slop` package directory.
    public static func jsonURL(in packageURL: URL) -> URL {
        packageURL.appendingPathComponent("slop.json")
    }

    public static func loadEnvelope(from packageURL: URL) throws -> SlopFileEnvelope {
        let jsonURL = Self.jsonURL(in: packageURL)
        let data = try Data(contentsOf: jsonURL)
        return try JSONDecoder().decode(SlopFileEnvelope.self, from: data)
    }

    /// Creates or overwrites `slop.json` inside the package directory, creating the directory if needed.
    public static func writePackage(at packageURL: URL, data: Data) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: packageURL.path) {
            try fm.createDirectory(at: packageURL, withIntermediateDirectories: true)
        }
        try data.write(to: jsonURL(in: packageURL), options: .atomic)
    }

    /// Creates or overwrites `slop.json` and any sidecar files for file-kind fields.
    public static func writePackage(at packageURL: URL, data: Data, schema: Schema) throws {
        try writePackage(at: packageURL, data: data)

        // Create empty sidecar files for any file-kind fields that don't already exist
        let fm = FileManager.default
        for field in schema.allFields where field.kind == .file {
            guard let desc = field.fileDescriptor else { continue }
            let sidecarURL = packageURL.appendingPathComponent(desc.defaultFilename)
            if !fm.fileExists(atPath: sidecarURL.path) {
                if desc.isText {
                    try "".write(to: sidecarURL, atomically: true, encoding: .utf8)
                } else {
                    try Data().write(to: sidecarURL, options: .atomic)
                }
            }
        }
    }

    public func encodedData(schema: Schema) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope(schema: schema))
    }
}
