import Testing
import Foundation
import SlopIPC
import SlopKit
@testable import SlopUI
@testable import SlopAI

// MARK: - Test Helpers

@MainActor
private func makeTestHandler() -> (handler: SlopIPCHandler, tempDir: URL) {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("SlopIPCHandlerTests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let registry = SlopTemplateRegistry(templatesDirectory: tempDir)
    registry.scan()

    let handler = SlopIPCHandler(
        registry: registry,
        openDocument: { _ in },
        showPicker: { },
        getRecents: { [] },
        clearRecents: { },
        getVersion: { "1.0.0-test" }
    )

    return (handler, tempDir)
}

@MainActor
private func cleanup(_ dir: URL) {
    try? FileManager.default.removeItem(at: dir)
}

// MARK: - IPC Handler Tests

@Test @MainActor
func statusReturnsRunningAndVersion() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let request = JSONRPCRequest(id: 1, method: "status")
    let response = await handler.handle(request)
    #expect(response.result?.bool("running") == true)
    #expect(response.result?.string("version") == "1.0.0-test")
}

@Test @MainActor
func unknownMethodReturnsMethodNotFound() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let request = JSONRPCRequest(id: 1, method: "bogus.nonexistent")
    let response = await handler.handle(request)
    #expect(response.error?.code == -32601)
}

@Test @MainActor
func templateListReturnsNonEmptyArray() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let request = JSONRPCRequest(id: 1, method: "template.list")
    let response = await handler.handle(request)
    let templates = response.result?.values["templates"]?.arrayValue
    #expect(templates != nil)
    #expect(!templates!.isEmpty)
}

@Test @MainActor
func templateListIncludesBuiltInFlag() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let request = JSONRPCRequest(id: 1, method: "template.list")
    let response = await handler.handle(request)
    let templates = response.result?.values["templates"]?.arrayValue ?? []
    let hasBuiltIn = templates.contains { entry in
        entry.objectValue?["builtIn"]?.boolValue == true
    }
    #expect(hasBuiltIn)
}

@Test @MainActor
func templateSchemaReturnsSchemaForKnownTemplate() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let params = SlopRequest.templateSchema(templateID: "com.hitslop.templates.budget-tracker")
    let request = JSONRPCRequest(id: 1, method: "template.schema", params: params)
    let response = await handler.handle(request)
    #expect(response.error == nil)
    let schema = response.result?.values["schema"]?.objectValue
    #expect(schema != nil)
}

@Test @MainActor
func templateSchemaReturnsErrorForUnknownTemplate() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let params = SlopRequest.templateSchema(templateID: "com.bogus.nonexistent")
    let request = JSONRPCRequest(id: 1, method: "template.schema", params: params)
    let response = await handler.handle(request)
    #expect(response.error != nil)
}

@Test @MainActor
func themeListReturnsThemesKey() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let request = JSONRPCRequest(id: 1, method: "theme.list")
    let response = await handler.handle(request)
    let themes = response.result?.values["themes"]?.arrayValue
    #expect(themes != nil)
    #expect(!(themes ?? []).isEmpty)
    let firstTheme = themes?.first?.objectValue
    #expect(firstTheme?["id"]?.stringValue != nil)
    #expect(firstTheme?["group"]?.stringValue != nil)
}

@Test @MainActor
func templateListReturnsCanonicalCategoryLabel() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let request = JSONRPCRequest(id: 1, method: "template.list")
    let response = await handler.handle(request)
    let templates = response.result?.values["templates"]?.arrayValue ?? []
    let meetingNotes = templates.first {
        $0.objectValue?["id"]?.stringValue == "com.hitslop.templates.meeting-notes"
    }?.objectValue

    #expect(meetingNotes?["category"]?.stringValue == "work")
    #expect(meetingNotes?["categoryLabel"]?.stringValue == "Work")
}

@Test @MainActor
func documentCreateWritesFile() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let outputPath = tempDir.appendingPathComponent("test-create.slop").path
    let params = SlopRequest.documentCreate(
        templateID: "com.hitslop.templates.simple-note",
        outputPath: outputPath,
        data: nil,
        theme: nil,
        open: false
    )
    let request = JSONRPCRequest(id: 1, method: "document.create", params: params)
    let response = await handler.handle(request)

    #expect(response.error == nil)
    #expect(response.result?.string("path") == outputPath)
    #expect(FileManager.default.fileExists(atPath: outputPath))
}

@Test @MainActor
func documentCreateWithDataMergesFields() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let outputPath = tempDir.appendingPathComponent("test-merge.slop").path
    let jsonData = #"{"title":"Custom Title"}"#
    let params = SlopRequest.documentCreate(
        templateID: "com.hitslop.templates.simple-note",
        outputPath: outputPath,
        data: jsonData,
        theme: nil,
        open: false
    )
    let request = JSONRPCRequest(id: 1, method: "document.create", params: params)
    let response = await handler.handle(request)
    #expect(response.error == nil)

    // Read back and verify
    let readParams = SlopRequest.documentRead(path: outputPath, raw: false, field: nil)
    let readRequest = JSONRPCRequest(id: 2, method: "document.read", params: readParams)
    let readResponse = await handler.handle(readRequest)
    #expect(readResponse.result?.values["title"]?.stringValue == "Custom Title")
}

@Test @MainActor
func documentReadReturnsFieldData() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    // Create first
    let outputPath = tempDir.appendingPathComponent("test-read.slop").path
    let createParams = SlopRequest.documentCreate(
        templateID: "com.hitslop.templates.simple-note",
        outputPath: outputPath,
        data: nil,
        theme: nil,
        open: false
    )
    let createRequest = JSONRPCRequest(id: 1, method: "document.create", params: createParams)
    let _ = await handler.handle(createRequest)

    // Read
    let readParams = SlopRequest.documentRead(path: outputPath, raw: false, field: nil)
    let readRequest = JSONRPCRequest(id: 2, method: "document.read", params: readParams)
    let readResponse = await handler.handle(readRequest)
    #expect(readResponse.error == nil)
    #expect(readResponse.result?.values["_templateID"]?.stringValue == "com.hitslop.templates.simple-note")
}

@Test @MainActor
func documentReadSingleField() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let outputPath = tempDir.appendingPathComponent("test-field.slop").path
    let jsonData = #"{"title":"Field Test"}"#
    let createParams = SlopRequest.documentCreate(
        templateID: "com.hitslop.templates.simple-note",
        outputPath: outputPath,
        data: jsonData,
        theme: nil,
        open: false
    )
    let _ = await handler.handle(JSONRPCRequest(id: 1, method: "document.create", params: createParams))

    let readParams = SlopRequest.documentRead(path: outputPath, raw: false, field: "title")
    let readRequest = JSONRPCRequest(id: 2, method: "document.read", params: readParams)
    let readResponse = await handler.handle(readRequest)
    #expect(readResponse.error == nil)
    #expect(readResponse.result?.values["value"]?.stringValue == "Field Test")
}

@Test @MainActor
func documentWriteUpdatesFields() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let outputPath = tempDir.appendingPathComponent("test-write.slop").path
    let createParams = SlopRequest.documentCreate(
        templateID: "com.hitslop.templates.simple-note",
        outputPath: outputPath,
        data: nil,
        theme: nil,
        open: false
    )
    let _ = await handler.handle(JSONRPCRequest(id: 1, method: "document.create", params: createParams))

    // Write new data
    let writeParams = SlopRequest.documentWrite(
        path: outputPath,
        fields: ["title=Updated Title"],
        data: nil,
        theme: nil
    )
    let writeRequest = JSONRPCRequest(id: 2, method: "document.write", params: writeParams)
    let writeResponse = await handler.handle(writeRequest)
    #expect(writeResponse.error == nil)

    // Read back
    let readParams = SlopRequest.documentRead(path: outputPath, raw: true, field: nil)
    let readRequest = JSONRPCRequest(id: 3, method: "document.read", params: readParams)
    let readResponse = await handler.handle(readRequest)
    #expect(readResponse.error == nil)
}

@Test @MainActor
func documentValidatePassesForValidDoc() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let outputPath = tempDir.appendingPathComponent("test-valid.slop").path
    let createParams = SlopRequest.documentCreate(
        templateID: "com.hitslop.templates.simple-note",
        outputPath: outputPath,
        data: nil,
        theme: nil,
        open: false
    )
    let _ = await handler.handle(JSONRPCRequest(id: 1, method: "document.create", params: createParams))

    let validateParams = SlopRequest.documentPath(outputPath)
    let request = JSONRPCRequest(id: 2, method: "document.validate", params: validateParams)
    let response = await handler.handle(request)
    #expect(response.result?.bool("valid") == true)
}

@Test @MainActor
func documentValidateReportsUnknownFields() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    // Create a document, then manually add an unknown field
    let outputPath = tempDir.appendingPathComponent("test-invalid.slop").path
    let createParams = SlopRequest.documentCreate(
        templateID: "com.hitslop.templates.simple-note",
        outputPath: outputPath,
        data: nil,
        theme: nil,
        open: false
    )
    let _ = await handler.handle(JSONRPCRequest(id: 1, method: "document.create", params: createParams))

    // Add an unknown field by writing raw JSON
    let writeParams = SlopRequest.documentWrite(
        path: outputPath,
        fields: [],
        data: #"{"bogusField":"value"}"#,
        theme: nil
    )
    let _ = await handler.handle(JSONRPCRequest(id: 2, method: "document.write", params: writeParams))

    let validateParams = SlopRequest.documentPath(outputPath)
    let request = JSONRPCRequest(id: 3, method: "document.validate", params: validateParams)
    let response = await handler.handle(request)
    let errors = response.result?.values["errors"]?.arrayValue ?? []
    let hasUnknownFieldError = errors.contains { $0.stringValue?.contains("Unknown field") == true }
    #expect(hasUnknownFieldError)
}

@Test @MainActor
func documentInfoReturnsMetadata() async {
    let (handler, tempDir) = makeTestHandler()
    defer { cleanup(tempDir) }

    let outputPath = tempDir.appendingPathComponent("test-info.slop").path
    let createParams = SlopRequest.documentCreate(
        templateID: "com.hitslop.templates.simple-note",
        outputPath: outputPath,
        data: nil,
        theme: nil,
        open: false
    )
    let _ = await handler.handle(JSONRPCRequest(id: 1, method: "document.create", params: createParams))

    let infoParams = SlopRequest.documentPath(outputPath)
    let request = JSONRPCRequest(id: 2, method: "document.info", params: infoParams)
    let response = await handler.handle(request)
    #expect(response.result?.values["templateID"]?.stringValue == "com.hitslop.templates.simple-note")
    #expect(response.result?.values["templateFound"]?.boolValue == true)
    #expect(response.result?.values["fieldCount"]?.intValue != nil)
}

// MARK: - DocumentUpdateApplier Tests

@Test @MainActor
func fullRewriteReplacesAllFields() {
    let schema = Schema(sections: [
        SchemaSection("Test", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("Default")),
            FieldDescriptor(key: "count", label: "Count", kind: .number, defaultValue: .number(0)),
        ]),
    ])
    let store = RawTemplateStore(
        values: ["title": .string("Old"), "count": .number(5)],
        persist: { _ in }
    )

    DocumentUpdateApplier.apply(
        .fullRewrite(["title": .string("New")]),
        to: store,
        schema: schema
    )

    #expect(store.values["title"] == .string("New"))
    #expect(store.values["count"] == .number(0)) // Reset to default
}

@Test @MainActor
func mergeFieldsPreservesExistingFields() {
    let schema = Schema(sections: [
        SchemaSection("Test", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("")),
            FieldDescriptor(key: "count", label: "Count", kind: .number, defaultValue: .number(0)),
        ]),
    ])
    let store = RawTemplateStore(
        values: ["title": .string("Keep"), "count": .number(5)],
        persist: { _ in }
    )

    DocumentUpdateApplier.apply(
        .mergeFields(["count": .number(10)]),
        to: store,
        schema: schema
    )

    #expect(store.values["title"] == .string("Keep"))
    #expect(store.values["count"] == .number(10))
}

@Test @MainActor
func arrayOpsRemoveByID() {
    let schema = Schema(sections: [
        SchemaSection("Test", fields: [
            FieldDescriptor(key: "items", label: "Items", kind: .array, defaultValue: .array([])),
        ]),
    ])
    let store = RawTemplateStore(
        values: [
            "items": .array([
                .record(["id": .string("1"), "name": .string("First")]),
                .record(["id": .string("2"), "name": .string("Second")]),
            ]),
        ],
        persist: { _ in }
    )

    DocumentUpdateApplier.apply(
        .arrayOps([ArrayOperation(field: "items", add: [], removeIDs: ["1"], update: [])]),
        to: store,
        schema: schema
    )

    let items = store.values["items"]?.asArray ?? []
    #expect(items.count == 1)
    #expect(items.first?.asRecord?["id"]?.asString == "2")
}

@Test @MainActor
func arrayOpsUpdateByID() {
    let schema = Schema(sections: [
        SchemaSection("Test", fields: [
            FieldDescriptor(key: "items", label: "Items", kind: .array, defaultValue: .array([])),
        ]),
    ])
    let store = RawTemplateStore(
        values: [
            "items": .array([
                .record(["id": .string("1"), "name": .string("Original")]),
            ]),
        ],
        persist: { _ in }
    )

    DocumentUpdateApplier.apply(
        .arrayOps([ArrayOperation(
            field: "items",
            add: [],
            removeIDs: [],
            update: [.record(["id": .string("1"), "name": .string("Updated")])]
        )]),
        to: store,
        schema: schema
    )

    let items = store.values["items"]?.asArray ?? []
    #expect(items.first?.asRecord?["name"]?.asString == "Updated")
}

@Test @MainActor
func arrayOpsAppendNew() {
    let schema = Schema(sections: [
        SchemaSection("Test", fields: [
            FieldDescriptor(key: "items", label: "Items", kind: .array, defaultValue: .array([])),
        ]),
    ])
    let store = RawTemplateStore(
        values: [
            "items": .array([
                .record(["id": .string("1"), "name": .string("Existing")]),
            ]),
        ],
        persist: { _ in }
    )

    DocumentUpdateApplier.apply(
        .arrayOps([ArrayOperation(
            field: "items",
            add: [.record(["id": .string("2"), "name": .string("New")])],
            removeIDs: [],
            update: []
        )]),
        to: store,
        schema: schema
    )

    let items = store.values["items"]?.asArray ?? []
    #expect(items.count == 2)
    #expect(items.last?.asRecord?["name"]?.asString == "New")
}
