import Foundation
import SlopKit
import FirebaseAILogic
import os

private let log = Logger(subsystem: "com.hitslop.ai", category: "service")

// MARK: - Types

/// Describes how a document should be updated based on AI output.
public enum DocumentUpdate: Sendable {
    /// Replace the entire document data.
    case fullRewrite([String: SlopKit.FieldValue])
    /// Merge only the changed fields into the existing data.
    case mergeFields([String: SlopKit.FieldValue])
    /// Typed array operations (add/remove/update items by ID).
    case arrayOps([ArrayOperation])
}

/// A set of operations to apply to a single array field.
public struct ArrayOperation: Sendable {
    public let field: String
    public let add: [SlopKit.FieldValue]
    public let removeIDs: [String]
    public let update: [SlopKit.FieldValue]

    public init(field: String, add: [SlopKit.FieldValue], removeIDs: [String], update: [SlopKit.FieldValue]) {
        self.field = field
        self.add = add
        self.removeIDs = removeIDs
        self.update = update
    }
}

/// Errors from the AI service.
public enum SlopAIError: Error, LocalizedError, Sendable {
    case emptyResponse
    case noFunctionCall
    case noImageGenerated
    case invalidResponseFormat(String)
    case firebaseNotConfigured

    public var errorDescription: String? {
        switch self {
        case .emptyResponse: return "AI returned an empty response"
        case .noFunctionCall: return "AI did not call any function"
        case .noImageGenerated: return "AI did not generate any images"
        case .invalidResponseFormat(let detail): return "AI response could not be parsed: \(detail)"
        case .firebaseNotConfigured: return "Firebase has not been configured. Call FirebaseApp.configure() first."
        }
    }
}

// MARK: - Service

/// Core AI service that wires template schemas to Firebase AI Logic tool calling.
///
/// Usage:
/// 1. Call `FirebaseApp.configure()` in your app delegate (requires GoogleService-Info.plist).
/// 2. Create a `SlopAIService` instance.
/// 3. Use `createDocument` for new documents or `updateDocument` for edits.
public actor SlopAIService {
    private let modelName: String

    /// Create a new AI service.
    /// - Parameter modelName: The Gemini model to use (e.g. "gemini-2.5-flash").
    public init(modelName: String = "gemini-2.5-flash") {
        self.modelName = modelName
    }

    // MARK: - Create Document

    /// Generate a complete new document from a natural language prompt.
    /// Uses structured output (responseSchema) so the model returns valid JSON directly.
    public func createDocument(
        templateName: String,
        schema: SlopKit.Schema,
        prompt: String
    ) async throws -> [String: SlopKit.FieldValue] {
        log.info("createDocument: template=\(templateName, privacy: .public), fields=\(schema.allFields.count)")
        let firebaseSchema = schema.toFirebaseSchema(allOptional: false)

        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: modelName,
            generationConfig: GenerationConfig(
                responseMIMEType: "application/json",
                responseSchema: firebaseSchema
            )
        )

        let fullPrompt = """
            Create data for a "\(templateName)" document.

            User request: \(prompt)

            Return a complete JSON object with all required fields populated.
            """

        let response = try await model.generateContent(fullPrompt)
        guard let text = response.text,
              let data = text.data(using: .utf8) else {
            log.error("createDocument: empty response from model")
            throw SlopAIError.emptyResponse
        }

        log.info("createDocument: response text length=\(text.count)")
        let jsonObject = try JSONDecoder().decode([String: SlopKit.JSONValue].self, from: data)
        let result = SlopKit.FieldValue.decodeRecord(jsonObject, schema: schema)
        log.info("createDocument: decoded \(result.count) keys")
        return result
    }

    // MARK: - Update Document

    /// Update an existing document with a natural language instruction.
    /// The model picks the most appropriate tool: `rewrite_document`, `update_fields`, or array-specific tools.
    public func updateDocument(
        templateName: String,
        schema: SlopKit.Schema,
        currentData: [String: SlopKit.JSONValue],
        instruction: String
    ) async throws -> DocumentUpdate {
        let tools = Self.buildTools(from: schema)
        log.info("updateDocument: template=\(templateName, privacy: .public), tools=\(tools.count)")

        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: modelName,
            tools: [.functionDeclarations(tools)]
        )

        let chat = model.startChat()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let currentDataJSON: String
        if let data = try? encoder.encode(currentData),
           let str = String(data: data, encoding: .utf8) {
            currentDataJSON = str
        } else {
            currentDataJSON = "{}"
        }

        log.info("updateDocument: currentData JSON length=\(currentDataJSON.count)")

        let prompt = """
            Current document ("\(templateName)"):
            \(currentDataJSON)

            User instruction: \(instruction)

            Choose the most efficient tool to apply this change.
            Use "update_fields" for small changes to specific fields.
            Use "rewrite_document" for large structural changes.
            """

        log.info("updateDocument: sending prompt to model…")
        let response = try await chat.sendMessage(prompt)

        let functionCalls = response.functionCalls
        log.info("updateDocument: response functionCalls=\(functionCalls.count), text=\(response.text?.prefix(120) ?? "<nil>", privacy: .public)")

        for functionCall in functionCalls {
            log.info("updateDocument: functionCall name=\(functionCall.name, privacy: .public), arg keys=\(functionCall.args.keys.sorted().joined(separator: ", "), privacy: .public)")

            switch functionCall.name {
            case "rewrite_document":
                let values = ResponseParser.parseFirebaseArgs(functionCall.args, schema: schema)
                log.info("updateDocument: → fullRewrite with \(values.count) keys")
                return .fullRewrite(values)

            case "update_fields":
                let values = ResponseParser.parseFirebaseArgs(functionCall.args, schema: schema)
                log.info("updateDocument: → mergeFields with \(values.count) keys")
                return .mergeFields(values)

            default:
                if functionCall.name.hasPrefix("update_") {
                    let fieldName = String(functionCall.name.dropFirst("update_".count))
                    let ops = ResponseParser.parseArrayOps(functionCall.args, field: fieldName, schema: schema)
                    log.info("updateDocument: → arrayOps field=\(fieldName, privacy: .public), ops=\(ops.count)")
                    return .arrayOps(ops)
                }
            }
        }

        log.error("updateDocument: no function call found — response text preview: \(response.text?.prefix(200) ?? "<nil>", privacy: .public)")
        throw SlopAIError.noFunctionCall
    }

    // MARK: - Image Generation (Nano Banana)

    /// Result from an image generation request.
    public struct ImageGenerationResult: Sendable {
        public let text: String
        public let images: [Data]
    }

    /// Generate an image using Gemini's native image generation capabilities.
    /// Uses `gemini-2.5-flash-image` with `responseModalities: [.text, .image]`.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt describing the desired image.
    ///   - existingImageData: Optional existing image data for editing/refinement.
    /// - Returns: Text response and generated image data arrays (PNG format).
    public func generateImage(
        prompt: String,
        existingImageData: Data? = nil
    ) async throws -> ImageGenerationResult {
        log.info("generateImage: prompt=\(prompt.prefix(80), privacy: .public)")

        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: "gemini-2.5-flash-image",
            generationConfig: GenerationConfig(
                responseModalities: [.text, .image]
            )
        )

        let response: GenerateContentResponse
        if let existingImageData {
            let imagePart = InlineDataPart(data: existingImageData, mimeType: "image/png")
            let textPart = TextPart(prompt)
            response = try await model.generateContent(imagePart, textPart)
        } else {
            response = try await model.generateContent(prompt)
        }

        var textParts: [String] = []
        var imageParts: [Data] = []

        if let candidate = response.candidates.first {
            for part in candidate.content.parts {
                if let textPart = part as? TextPart {
                    textParts.append(textPart.text)
                } else if let inlineDataPart = part as? InlineDataPart,
                          inlineDataPart.mimeType.hasPrefix("image/") {
                    imageParts.append(inlineDataPart.data)
                }
            }
        }

        log.info("generateImage: text parts=\(textParts.count), image parts=\(imageParts.count)")

        guard !imageParts.isEmpty else {
            if !textParts.isEmpty {
                log.warning("generateImage: got text but no images — text: \(textParts.joined().prefix(200), privacy: .public)")
            }
            throw SlopAIError.noImageGenerated
        }

        return ImageGenerationResult(text: textParts.joined(separator: "\n"), images: imageParts)
    }

    // MARK: - Tool Building

    /// Build Firebase function declarations from a template schema.
    /// Returns tools for document rewrite, field update, and per-array operations.
    public static func buildTools(from schema: SlopKit.Schema) -> [FunctionDeclaration] {
        log.debug("buildTools: schema fields=\(schema.allFields.count)")
        var tools: [FunctionDeclaration] = []

        let allProperties = schema.toFirebaseProperties()
        let optionalKeys = schema.allFields
            .filter { $0.kind != .image && $0.kind != .file && !$0.required }
            .map(\.key)
        let allKeys = schema.allFields
            .filter { $0.kind != .image && $0.kind != .file }
            .map(\.key)

        // Tool 1: Full rewrite — complete document replacement
        tools.append(FunctionDeclaration(
            name: "rewrite_document",
            description: "Replace the entire document data. Use for large changes that affect most fields.",
            parameters: allProperties,
            optionalParameters: optionalKeys
        ))

        // Tool 2: Merge patch — only changed fields (all optional)
        tools.append(FunctionDeclaration(
            name: "update_fields",
            description: "Update specific fields only. Return only the fields that should change. Use for small, targeted edits.",
            parameters: allProperties,
            optionalParameters: allKeys
        ))

        // Tool 3+: Per-array operation tools
        for field in schema.allFields where field.kind == .array {
            guard let itemSchema = field.itemSchema else { continue }
            let itemFirebase = itemSchema.toFirebaseSchema()
            tools.append(FunctionDeclaration(
                name: "update_\(field.key)",
                description: "Add, remove, or update items in '\(field.label)'. Provide arrays of items to add, IDs to remove, or items to update.",
                parameters: [
                    "add": .array(items: itemFirebase, description: "Items to add"),
                    "remove_ids": .array(items: .string(description: "IDs of items to remove")),
                    "update": .array(items: itemFirebase, description: "Items to update (must include id)"),
                ],
                optionalParameters: ["add", "remove_ids", "update"]
            ))
        }

        return tools
    }
}
