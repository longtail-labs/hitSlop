import Foundation
import SwiftUI
import SlopIPC
import SlopKit

/// Dispatches IPC method calls to app actions.
@MainActor
public final class SlopIPCHandler {
    private let registry: SlopTemplateRegistry
    private let openDocument: (URL) -> Void
    private let showPicker: () -> Void
    private let getRecents: () -> [URL]
    private let clearRecents: () -> Void
    private let getVersion: () -> String

    public init(
        registry: SlopTemplateRegistry,
        openDocument: @escaping (URL) -> Void,
        showPicker: @escaping () -> Void,
        getRecents: @escaping () -> [URL],
        clearRecents: @escaping () -> Void,
        getVersion: @escaping () -> String
    ) {
        self.registry = registry
        self.openDocument = openDocument
        self.showPicker = showPicker
        self.getRecents = getRecents
        self.clearRecents = clearRecents
        self.getVersion = getVersion
    }

    public func handle(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        guard let method = SlopMethod(rawValue: request.method) else {
            return JSONRPCResponse(id: request.id, error: .methodNotFound)
        }

        do {
            let result = try await dispatch(method, params: request.params, id: request.id)
            return JSONRPCResponse(id: request.id, result: result)
        } catch {
            return JSONRPCResponse(id: request.id, error: .internalError(error.localizedDescription))
        }
    }

    private func dispatch(_ method: SlopMethod, params: JSONRPCParams?, id: Int) async throws -> JSONRPCParams {
        switch method {
        case .status:
            return handleStatus()
        case .templateList:
            return handleTemplateList()
        case .templateSchema:
            return try handleTemplateSchema(params)
        case .themeList:
            return handleThemeList()
        case .themeWrite:
            return try handleThemeWrite(params)
        case .themeDerive:
            return handleThemeDerive(params)
        case .themeDelete:
            return try handleThemeDelete(params)
        case .themeValidate:
            return try handleThemeValidate(params)
        case .documentCreate:
            return try handleDocumentCreate(params)
        case .documentRead:
            return try handleDocumentRead(params)
        case .documentWrite:
            return try handleDocumentWrite(params)
        case .documentValidate:
            return try handleDocumentValidate(params)
        case .documentInfo:
            return try handleDocumentInfo(params)
        case .documentOpen:
            return try handleDocumentOpen(params)
        case .documentSetTheme:
            return try handleDocumentSetTheme(params)
        case .documentSetShape:
            return try handleDocumentSetShape(params)
        case .documentExport:
            return try handleDocumentExport(params)
        case .recentsList:
            return handleRecentsList(params)
        case .recentsClear:
            return handleRecentsClear()
        case .pickerShow:
            return handlePickerShow()
        }
    }

    // MARK: - Status

    private func handleStatus() -> JSONRPCParams {
        SlopResponse.status(
            running: true,
            pid: Int(ProcessInfo.processInfo.processIdentifier),
            version: getVersion()
        )
    }

    // MARK: - Templates

    private func handleTemplateList() -> JSONRPCParams {
        let templates: [[String: AnyCodable]] = registry.entries.map { entry in
            let categories = entry.manifest.metadata.categories
            let primaryCategory = TemplateCategoryCatalog.entry(for: categories.first)
            var dict: [String: AnyCodable] = [
                "id": .string(entry.manifest.id),
                "name": .string(entry.manifest.name),
                "version": .string(entry.manifest.version),
                "category": .string(primaryCategory.id),
                "categoryLabel": .string(primaryCategory.label),
                "categories": .array(categories.map { .string($0) }),
            ]
            if entry.isBuiltIn { dict["builtIn"] = .bool(true) }
            if entry.isScripted { dict["scripted"] = .bool(true) }
            return dict
        }
        return SlopResponse.templateList(templates)
    }

    private func handleTemplateSchema(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let templateID = params?.string("templateID") else {
            throw HandlerError.missingParam("templateID")
        }

        guard let entry = registry.entries.first(where: { $0.manifest.id == templateID }) else {
            throw HandlerError.templateNotFound(templateID)
        }

        let jsonSchema = entry.manifest.schema.toJSONSchema(title: entry.manifest.name)
        let schemaData = try JSONSerialization.data(withJSONObject: jsonSchema, options: [.sortedKeys])
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: schemaData)

        // Also include field list for --fields mode
        let fields: [AnyCodable] = entry.manifest.schema.allFields.map { field in
            var info: [String: AnyCodable] = [
                "key": .string(field.key),
                "label": .string(field.label),
                "type": .string(String(describing: field.kind)),
                "required": .bool(field.required),
            ]
            if let hint = field.hint { info["hint"] = .string(hint) }
            return .object(info)
        }

        var result = decoded
        result["fields"] = .array(fields)
        return SlopResponse.templateSchema(result)
    }

    // MARK: - Themes

    private func handleThemeList() -> JSONRPCParams {
        let themeList: [[String: AnyCodable]] = ThemeCatalog.entries().map { entry in
            [
                "id": .string(entry.id),
                "name": .string(entry.displayName),
                "group": .string(entry.group),
                "source": .string(entry.source.rawValue),
            ]
        }
        return SlopResponse.themeList(themeList)
    }

    private func handleThemeWrite(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let id = params?.string("id") else {
            throw HandlerError.missingParam("id")
        }
        guard let themeJSON = params?.string("themeFile") else {
            throw HandlerError.missingParam("themeFile")
        }
        guard let jsonData = themeJSON.data(using: .utf8) else {
            throw HandlerError.invalidFormat("themeFile is not valid UTF-8")
        }
        let themeFile = try JSONDecoder().decode(ThemeFile.self, from: jsonData)

        let validation = ThemeValidator.validate(themeFile)
        try ThemeCatalog.saveUserTheme(themeFile, id: id)

        return SlopResponse.themeWrite(id: id, warnings: validation.warnings)
    }

    private func handleThemeDerive(_ params: JSONRPCParams?) -> JSONRPCParams {
        let accent = params?.string("accent") ?? "#e94560"
        let isDark = params?.bool("isDark") ?? true
        let themeFile = ThemeDeriver.derive(accent: accent, isDark: isDark)

        // Convert to dictionary for response
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(themeFile)) ?? Data()
        let decoded = (try? JSONDecoder().decode([String: AnyCodable].self, from: data)) ?? [:]

        let suggestedID = "derived-\(accent.replacingOccurrences(of: "#", with: "").lowercased())"
        return SlopResponse.themeDerive(themeFile: decoded, suggestedID: suggestedID)
    }

    private func handleThemeDelete(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let id = params?.string("id") else {
            throw HandlerError.missingParam("id")
        }
        try ThemeCatalog.deleteUserTheme(id: id)
        return SlopResponse.ok()
    }

    private func handleThemeValidate(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let themeJSON = params?.string("themeFile") else {
            throw HandlerError.missingParam("themeFile")
        }
        guard let jsonData = themeJSON.data(using: .utf8) else {
            throw HandlerError.invalidFormat("themeFile is not valid UTF-8")
        }
        let themeFile = try JSONDecoder().decode(ThemeFile.self, from: jsonData)
        let result = ThemeValidator.validate(themeFile)
        return SlopResponse.themeValidate(isValid: result.isValid, warnings: result.warnings)
    }

    private func handleDocumentSetTheme(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let path = params?.string("path") else {
            throw HandlerError.missingParam("path")
        }

        let url = URL(fileURLWithPath: path)
        var envelope = try SlopFile.loadEnvelope(from: url)

        let theme = params?.string("theme")
        envelope.theme = theme

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        try SlopFile.writePackage(at: url, data: data)

        return SlopResponse.ok()
    }

    private func handleDocumentSetShape(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let path = params?.string("path") else {
            throw HandlerError.missingParam("path")
        }

        let url = URL(fileURLWithPath: path)
        var envelope = try SlopFile.loadEnvelope(from: url)

        if let shapeJSON = params?.string("shape"),
           let shapeData = shapeJSON.data(using: .utf8) {
            let shape = try JSONDecoder().decode(WindowShape.self, from: shapeData)
            envelope.windowShape = shape
        } else {
            envelope.windowShape = nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        try SlopFile.writePackage(at: url, data: data)

        return SlopResponse.ok()
    }

    // MARK: - Document CRUD

    private func handleDocumentCreate(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let templateID = params?.string("templateID") else {
            throw HandlerError.missingParam("templateID")
        }

        guard let entry = registry.entries.first(where: { $0.manifest.id == templateID }) else {
            throw HandlerError.templateNotFound(templateID)
        }

        let schema = entry.manifest.schema
        var fieldValues = schema.defaultValues()

        // Merge user-provided data
        if let dataJSON = params?.string("data"),
           let dataData = dataJSON.data(using: .utf8),
           let userFields = try? JSONDecoder().decode([String: JSONValue].self, from: dataData) {
            let decoded = FieldValue.decodeRecord(userFields, schema: schema)
            for (key, value) in decoded {
                fieldValues[key] = value
            }
        }

        let theme = params?.string("theme")
        let outputPath: String
        if let explicit = params?.string("outputPath") {
            outputPath = explicit
        } else {
            outputPath = FileManager.default.currentDirectoryPath + "/Untitled.\(templateID.split(separator: ".").last ?? "doc").slop"
        }

        let url = URL(fileURLWithPath: outputPath)
        let slopFile = SlopFile(
            templateID: templateID,
            templateVersion: entry.manifest.version,
            data: fieldValues,
            theme: theme
        )
        let data = try slopFile.encodedData(schema: schema)
        try SlopFile.writePackage(at: url, data: data)

        if params?.bool("open") == true {
            openDocument(url)
        }

        return SlopResponse.documentCreate(path: url.path)
    }

    private func handleDocumentRead(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let path = params?.string("path") else {
            throw HandlerError.missingParam("path")
        }

        let url = URL(fileURLWithPath: path)
        let envelope = try SlopFile.loadEnvelope(from: url)
        let raw = params?.bool("raw") == true

        if raw {
            let envelopeData = try JSONEncoder().encode(envelope)
            let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: envelopeData)
            return SlopResponse.documentRead(decoded)
        }

        // Resolve schema and decode typed fields
        if let entry = registry.resolve(templateID: envelope.templateID, version: envelope.templateVersion) {
            let slopFile = SlopFile(envelope: envelope, schema: entry.manifest.schema)

            // If specific field requested
            if let fieldKey = params?.string("field") {
                if let value = slopFile.data[fieldKey] {
                    let jsonValue = FieldValue.fallbackEncode(value)
                    let jsonData = try JSONEncoder().encode(jsonValue)
                    let decoded = try JSONDecoder().decode(AnyCodable.self, from: jsonData)
                    return JSONRPCParams(["value": decoded])
                } else {
                    throw HandlerError.fieldNotFound(fieldKey)
                }
            }

            // Return full data with envelope info
            let encoded = FieldValue.encodeRecord(slopFile.data, schema: entry.manifest.schema)
            let jsonData = try JSONEncoder().encode(encoded)
            let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: jsonData)
            var result = decoded
            result["_templateID"] = .string(slopFile.templateID)
            result["_templateVersion"] = .string(slopFile.templateVersion)
            result["_templateName"] = .string(entry.manifest.name)
            if let theme = slopFile.theme { result["_theme"] = .string(theme) }
            return SlopResponse.documentRead(result)
        }

        // Fallback: return raw envelope
        let envelopeData = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: envelopeData)
        return SlopResponse.documentRead(decoded)
    }

    private func handleDocumentWrite(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let path = params?.string("path") else {
            throw HandlerError.missingParam("path")
        }

        let url = URL(fileURLWithPath: path)
        var envelope = try SlopFile.loadEnvelope(from: url)

        // Apply theme change
        if let theme = params?.string("theme") {
            envelope.theme = theme
        }

        // Apply data merge from --data
        if let dataJSON = params?.string("data"),
           let dataData = dataJSON.data(using: .utf8),
           let userFields = try? JSONDecoder().decode([String: JSONValue].self, from: dataData) {
            for (key, value) in userFields {
                envelope.data[key] = value
            }
        }

        // Apply --field key=value pairs
        if let fieldPairs = params?.values["fields"]?.arrayValue {
            for pair in fieldPairs {
                guard let pairStr = pair.stringValue else { continue }
                let parts = pairStr.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = String(parts[0])
                let value = String(parts[1])
                // Try to parse as JSON value, fallback to string
                if let jsonData = value.data(using: .utf8),
                   let jsonValue = try? JSONDecoder().decode(JSONValue.self, from: jsonData) {
                    envelope.data[key] = jsonValue
                } else {
                    envelope.data[key] = .string(value)
                }
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        try SlopFile.writePackage(at: url, data: data)

        return SlopResponse.message("Updated \(url.lastPathComponent)")
    }

    private func handleDocumentValidate(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let path = params?.string("path") else {
            throw HandlerError.missingParam("path")
        }

        let url = URL(fileURLWithPath: path)
        let envelope = try SlopFile.loadEnvelope(from: url)

        guard let entry = registry.resolve(templateID: envelope.templateID, version: envelope.templateVersion) else {
            return SlopResponse.validate(valid: false, errors: [
                "Template not found: \(envelope.templateID)@\(envelope.templateVersion)"
            ])
        }

        let schema = entry.manifest.schema
        var errors: [String] = []

        // Check required fields
        for field in schema.allFields where field.required {
            if envelope.data[field.key] == nil || envelope.data[field.key] == .null {
                errors.append("Missing required field: \(field.key)")
            }
        }

        // Check for unknown fields
        let knownKeys = Set(schema.allFields.map(\.key))
        for key in envelope.data.keys where !knownKeys.contains(key) {
            errors.append("Unknown field: \(key)")
        }

        return SlopResponse.validate(valid: errors.isEmpty, errors: errors)
    }

    private func handleDocumentInfo(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let path = params?.string("path") else {
            throw HandlerError.missingParam("path")
        }

        let url = URL(fileURLWithPath: path)
        let envelope = try SlopFile.loadEnvelope(from: url)

        var info: [String: AnyCodable] = [
            "templateID": .string(envelope.templateID),
            "templateVersion": .string(envelope.templateVersion),
            "fieldCount": .int(envelope.data.count),
        ]

        if let theme = envelope.theme { info["theme"] = .string(theme) }
        if let alwaysOnTop = envelope.alwaysOnTop { info["alwaysOnTop"] = .bool(alwaysOnTop) }

        if let entry = registry.resolve(templateID: envelope.templateID, version: envelope.templateVersion) {
            info["templateName"] = .string(entry.manifest.name)
            info["templateFound"] = .bool(true)
        } else {
            info["templateFound"] = .bool(false)
        }

        return SlopResponse.documentInfo(info)
    }

    // MARK: - App Commands

    private func handleDocumentOpen(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let path = params?.string("path") else {
            throw HandlerError.missingParam("path")
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw HandlerError.fileNotFound(path)
        }
        openDocument(url)
        return SlopResponse.message("Opened \(url.lastPathComponent)")
    }

    private func handleDocumentExport(_ params: JSONRPCParams?) throws -> JSONRPCParams {
        guard let path = params?.string("path") else {
            throw HandlerError.missingParam("path")
        }
        let format = params?.string("format") ?? "png"
        let scale = params?.int("scale") ?? 2
        let themeOverride = params?.string("theme")

        let url = URL(fileURLWithPath: path)
        let envelope = try SlopFile.loadEnvelope(from: url)

        guard let entry = registry.resolve(templateID: envelope.templateID, version: envelope.templateVersion) else {
            throw HandlerError.templateNotFound("\(envelope.templateID)@\(envelope.templateVersion)")
        }

        let schema = entry.manifest.schema
        let slopFile = SlopFile(envelope: envelope, schema: schema)
        let themeName = themeOverride ?? slopFile.theme ?? entry.manifest.metadata.theme

        // Determine output path
        let outputPath: String
        if let explicit = params?.string("output") {
            outputPath = explicit
        } else {
            let base = url.deletingPathExtension().path
            outputPath = "\(base).\(format)"
        }

        // Create template body and render
        let store = RawTemplateStore(values: slopFile.data, persist: { _ in })

        let resolvedBundleURL = SlopTemplateBodyFactory.bundleURL(for: entry)
        let templateBody = makeTemplateBody(entry: entry, store: store)

        switch format {
        case "pdf":
            guard let snapshot = SlopTemplateSnapshotRenderer.renderPDF(
                makeTemplateBody: { templateBody },
                metadata: entry.manifest.metadata,
                themeName: themeName,
                bundleURL: resolvedBundleURL
            ) else {
                throw HandlerError.exportFailed("PDF rendering failed")
            }
            try snapshot.pdfData.write(to: URL(fileURLWithPath: outputPath))

        case "png":
            guard let snapshot = SlopTemplateSnapshotRenderer.renderImage(
                makeTemplateBody: { templateBody },
                metadata: entry.manifest.metadata,
                themeName: themeName,
                bundleURL: resolvedBundleURL,
                scale: CGFloat(scale)
            ) else {
                throw HandlerError.exportFailed("Image rendering failed")
            }
            guard let pngData = snapshot.pngData() else {
                throw HandlerError.exportFailed("PNG encoding failed")
            }
            try pngData.write(to: URL(fileURLWithPath: outputPath))

        default:
            throw HandlerError.invalidFormat(format)
        }

        return SlopResponse.documentExport(path: outputPath, format: format)
    }

    private func makeTemplateBody(
        entry: SlopTemplateRegistry.Entry,
        store: RawTemplateStore
    ) -> AnyView {
        SlopTemplateBodyFactory.makeBody(entry: entry, store: store)
    }

    // MARK: - Recents

    private func handleRecentsList(_ params: JSONRPCParams?) -> JSONRPCParams {
        let recents = getRecents()
        return SlopResponse.recentsList(recents.map(\.path))
    }

    private func handleRecentsClear() -> JSONRPCParams {
        clearRecents()
        return SlopResponse.message("Recents cleared")
    }

    // MARK: - Picker

    private func handlePickerShow() -> JSONRPCParams {
        showPicker()
        return SlopResponse.message("Picker shown")
    }

    // MARK: - Errors

    enum HandlerError: LocalizedError {
        case missingParam(String)
        case templateNotFound(String)
        case fieldNotFound(String)
        case fileNotFound(String)
        case exportFailed(String)
        case invalidFormat(String)

        var errorDescription: String? {
            switch self {
            case .missingParam(let p): "Missing required parameter: \(p)"
            case .templateNotFound(let id): "Template not found: \(id)"
            case .fieldNotFound(let key): "Field not found: \(key)"
            case .fileNotFound(let path): "File not found: \(path)"
            case .exportFailed(let msg): "Export failed: \(msg)"
            case .invalidFormat(let f): "Invalid format: \(f) (expected pdf or png)"
            }
        }
    }
}
