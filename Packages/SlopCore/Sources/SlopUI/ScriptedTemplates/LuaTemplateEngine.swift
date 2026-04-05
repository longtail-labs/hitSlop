import Foundation
import SlopKit
import Lua
import os

private let log = Logger(subsystem: "ca.long.tail.labs.slop", category: "LuaTemplateEngine")

/// Manages a sandboxed Lua state for a single scripted template.
/// Handles loading, calling schema/metadata/layout/onAction, and instruction limits.
@MainActor
final class LuaTemplateEngine {

    /// Errors from the Lua template engine.
    enum EngineError: Error, LocalizedError {
        case loadFailed(String)
        case schemaCallFailed(String)
        case metadataCallFailed(String)
        case layoutCallFailed(String)
        case actionCallFailed(String)
        case executionLimitExceeded

        var errorDescription: String? {
            switch self {
            case .loadFailed(let msg): return "Script load failed: \(msg)"
            case .schemaCallFailed(let msg): return "schema() failed: \(msg)"
            case .metadataCallFailed(let msg): return "metadata() failed: \(msg)"
            case .layoutCallFailed(let msg): return "layout() failed: \(msg)"
            case .actionCallFailed(let msg): return "onAction() failed: \(msg)"
            case .executionLimitExceeded: return "Script exceeded instruction limit"
            }
        }
    }

    private nonisolated(unsafe) var L: LuaState?
    private let scriptPath: String
    private let maxInstructions = 10_000_000
    private nonisolated(unsafe) var instructionCount = 0

    /// The schema parsed from `template.schema()`.
    private(set) var schema: Schema?

    /// The metadata parsed from `template.metadata()`.
    private(set) var metadata: TemplateMetadata?

    init(scriptPath: String) {
        self.scriptPath = scriptPath
    }

    deinit {
        L?.close()
    }

    // MARK: - Lifecycle

    /// Load the script, call schema() and metadata(), and prepare the state for layout calls.
    func load() throws {
        let L = LuaState(libraries: [.string, .table, .math])
        self.L = L

        // Remove potentially dangerous globals
        for name in ["dofile", "loadfile", "load", "collectgarbage"] {
            L.pushnil()
            L.setglobal(name: name)
        }

        // Register LayoutNode metatable and all constructor globals
        registerLayoutNodeMetatable(L)
        registerLayoutConstructors(L)

        // Set instruction count hook for sandboxing
        instructionCount = 0
        L.setHook(mask: .count, count: 10_000) { [weak self] _, _, _ in
            guard let self else { return }
            self.instructionCount += 10_000
            if self.instructionCount > self.maxInstructions {
                throw LuaCallError("execution limit exceeded")
            }
        }

        // Load and execute the script (should return a table)
        do {
            try L.dofile(scriptPath)
        } catch {
            throw EngineError.loadFailed("\(error)")
        }

        // The script should have set the template table via `return template`.
        // After dofile, the return value is on the stack.
        // Check if the top of stack is a table (the returned template module).
        if L.type(-1) != .table {
            // Script didn't return a table — look for a global "template"
            L.pop()
            if L.getglobal("template") != .table {
                L.pop()
                throw EngineError.loadFailed("Script must return a template table")
            }
        }

        // Store the template table as a global for later calls
        L.setglobal(name: "_template")

        // Call schema()
        self.schema = try callSchema()

        // Call metadata()
        self.metadata = try callMetadata()
    }

    // MARK: - Call Schema

    private func callSchema() throws -> Schema {
        guard let L else { throw EngineError.loadFailed("No Lua state") }

        resetInstructionCount()

        L.getglobal("_template")
        guard L.type(-1) == .table else {
            L.pop()
            throw EngineError.schemaCallFailed("_template is not a table")
        }

        L.rawget(-1, utf8Key: "schema")
        guard L.type(-1) == .function else {
            L.pop(2) // pop nil + table
            // Schema is optional — return empty if not provided
            return Schema(sections: [])
        }

        do {
            try L.pcall(nargs: 0, nret: 1)
        } catch {
            L.pop() // pop _template table
            throw EngineError.schemaCallFailed("\(error)")
        }

        let schema = parseSchema(L, at: -1)
        L.pop(2) // pop result + _template table
        return schema
    }

    // MARK: - Call Metadata

    private func callMetadata() throws -> TemplateMetadata {
        guard let L else { throw EngineError.loadFailed("No Lua state") }

        resetInstructionCount()

        L.getglobal("_template")
        guard L.type(-1) == .table else {
            L.pop()
            throw EngineError.metadataCallFailed("_template is not a table")
        }

        L.rawget(-1, utf8Key: "metadata")
        guard L.type(-1) == .function else {
            L.pop(2)
            return TemplateMetadata()
        }

        do {
            try L.pcall(nargs: 0, nret: 1)
        } catch {
            L.pop()
            throw EngineError.metadataCallFailed("\(error)")
        }

        let metadata = parseMetadata(L, at: -1)
        L.pop(2) // pop result + _template table
        return metadata
    }

    // MARK: - Call Layout

    /// Call `template.layout(data, theme, context)` and return the root LayoutNode.
    func callLayout(
        store: RawTemplateStore,
        theme: SlopTheme,
        renderTarget: SlopRenderTarget
    ) throws -> LayoutNode {
        guard let L else { throw EngineError.loadFailed("No Lua state") }

        resetInstructionCount()

        L.getglobal("_template")
        guard L.type(-1) == .table else {
            L.pop()
            throw EngineError.layoutCallFailed("_template is not a table")
        }

        L.rawget(-1, utf8Key: "layout")
        guard L.type(-1) == .function else {
            L.pop(2)
            throw EngineError.layoutCallFailed("template.layout is not a function")
        }

        // Push data as a Lua table (snapshot of current values)
        pushFieldValue(L, .record(store.values))

        // Push theme as a Lua table with hex color strings
        let tp = ThemeProxy(theme: theme)
        L.newtable(nrec: 6)
        L.rawset(-1, utf8Key: "foreground", value: tp.foreground)
        L.rawset(-1, utf8Key: "background", value: tp.background)
        L.rawset(-1, utf8Key: "secondary", value: tp.secondary)
        L.rawset(-1, utf8Key: "accent", value: tp.accent)
        L.rawset(-1, utf8Key: "surface", value: tp.surface)
        L.rawset(-1, utf8Key: "divider", value: tp.divider)

        // Push render context
        L.newtable(nrec: 1)
        L.rawset(-1, utf8Key: "renderTarget", value: renderTarget.luaName)

        do {
            try L.pcall(nargs: 3, nret: 1)
        } catch {
            L.pop() // pop _template table
            throw EngineError.layoutCallFailed("\(error)")
        }

        guard let result: LayoutNode = L.touserdata(-1) else {
            L.pop(2)
            throw EngineError.layoutCallFailed("layout() did not return a LayoutNode")
        }

        L.pop(2) // pop result + _template table
        return result
    }

    // MARK: - Call onAction

    /// Call `template.onAction(name, data)` and return updated data.
    func callOnAction(name: String, store: RawTemplateStore) throws -> [String: FieldValue]? {
        guard let L else { return nil }

        resetInstructionCount()

        L.getglobal("_template")
        guard L.type(-1) == .table else {
            L.pop()
            return nil
        }

        L.rawget(-1, utf8Key: "onAction")
        guard L.type(-1) == .function else {
            L.pop(2)
            return nil
        }

        L.push(utf8String: name)
        pushFieldValue(L, .record(store.values))

        do {
            try L.pcall(nargs: 2, nret: 1)
        } catch {
            L.pop() // pop _template
            log.error("onAction('\(name)') error: \(error)")
            throw EngineError.actionCallFailed("\(error)")
        }

        // If onAction returns a table, use it as updated data
        var updatedData: [String: FieldValue]?
        if L.type(-1) == .table {
            let val = toFieldValue(L, at: -1)
            if case .record(let dict) = val {
                updatedData = dict
            }
        }

        L.pop(2) // pop result + _template table
        return updatedData
    }

    // MARK: - Helpers

    private func resetInstructionCount() {
        instructionCount = 0
    }
}

private extension SlopRenderTarget {
    var luaName: String {
        switch self {
        case .interactive:
            return "interactive"
        case .pdfExport:
            return "pdfExport"
        case .imageExport:
            return "imageExport"
        }
    }
}
