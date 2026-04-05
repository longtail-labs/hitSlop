import Foundation

/// Serialized manifest describing an installed template artifact.
public struct TemplateManifest: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let description: String?
    public let version: String
    public let minimumHostVersion: String
    public let bundleFile: String?
    public let scriptFile: String?
    public let previewFile: String?
    public let metadata: TemplateMetadata
    public let schema: Schema

    /// True if this manifest describes a Lua-scripted template (Tier 2).
    public var isScripted: Bool { scriptFile != nil }

    public init(
        id: String,
        name: String,
        description: String? = nil,
        version: String,
        minimumHostVersion: String = "1.0.0",
        bundleFile: String? = "Template.bundle",
        scriptFile: String? = nil,
        previewFile: String? = nil,
        metadata: TemplateMetadata,
        schema: Schema
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.minimumHostVersion = minimumHostVersion
        self.bundleFile = bundleFile
        self.scriptFile = scriptFile
        self.previewFile = previewFile
        self.metadata = metadata
        self.schema = schema
    }

    /// Returns the template's schema as a JSON Schema dictionary.
    public func jsonSchema() -> [String: Any] {
        schema.toJSONSchema(title: name)
    }

    public static func make<T: AnySlopTemplate>(
        for templateType: T.Type,
        bundleFile: String = "Template.bundle",
        previewFile: String? = nil
    ) -> TemplateManifest {
        TemplateManifest(
            id: templateType.templateID,
            name: templateType.name,
            description: templateType.templateDescription,
            version: templateType.version,
            minimumHostVersion: templateType.minimumHostVersion,
            bundleFile: bundleFile,
            previewFile: previewFile,
            metadata: templateType.metadata,
            schema: templateType.schema
        )
    }
}
