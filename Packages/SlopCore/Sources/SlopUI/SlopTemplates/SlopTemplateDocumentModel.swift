import Foundation
import SwiftUI
import SlopKit

/// Document model for Slop templates.
/// Manages a single `.slop` JSON file, undo/redo, and file watching.
@MainActor
public class SlopTemplateDocumentModel: ObservableObject {
    public let fileURL: URL
    public private(set) var slopFile: SlopFile

    @Published public var rawData: [String: FieldValue]
    @Published public var themeName: String?
    @Published public var alwaysOnTop: Bool
    @Published public var currentWindowShape: WindowShape
    public let rawStore: RawTemplateStore
    public let sidecarStore: SidecarStore

    public let schema: Schema
    public let metadata: TemplateMetadata

    /// Maps field key → filename for sidecar file fields.
    public private(set) var sidecarFields: [String: FileFieldDescriptor] = [:]

    // Preview rendering
    public var onNeedPreviewRender: (() -> Void)?
    private var previewDebounce: DispatchWorkItem?

    // File watching
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var writeDebounce: DispatchWorkItem?
    private var readDebounce: DispatchWorkItem?
    private var suppressReloadUntil: Date = .distantPast

    // Sidecar file watching
    private var sidecarFileDescriptors: [String: Int32] = [:]
    private var sidecarDispatchSources: [String: DispatchSourceFileSystemObject] = [:]
    private var sidecarWriteDebounces: [String: DispatchWorkItem] = [:]
    private var sidecarSuppressReloadUntil: [String: Date] = [:]

    // Undo/redo
    private var undoStack: [[String: FieldValue]] = []
    private var redoStack: [[String: FieldValue]] = []
    private let maxUndoLevels = 100

    public init(fileURL: URL, slopFile: SlopFile, schema: Schema, metadata: TemplateMetadata) {
        self.fileURL = fileURL
        self.slopFile = slopFile
        self.schema = schema
        self.metadata = metadata

        // Merge schema defaults with file data (schema defaults fill missing keys)
        let values = Self.merge(values: slopFile.data, over: schema.defaultValues())

        self.rawData = values
        self.themeName = slopFile.theme
        self.alwaysOnTop = slopFile.alwaysOnTop ?? metadata.alwaysOnTop
        self.currentWindowShape = metadata.windowShape

        self.rawStore = RawTemplateStore(values: values, persist: { _ in })
        self.sidecarStore = SidecarStore()

        self.rawStore.setPersistHandler { [weak self] newValues in
            self?.dataDidChange(newValues)
        }

        // Scan schema for file fields and set up sidecar store
        setupSidecarFields()

        startFileWatcher()

        // Render initial preview shortly after open
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onNeedPreviewRender?()
        }
    }

    /// Called by the store when data changes via template UI.
    /// Does NOT call externalUpdate — the store already has the new values.
    public func dataDidChange(_ newValues: [String: FieldValue]) {
        let oldValues = rawData
        rawData = newValues
        pushUndo(oldValues)
        redoStack.removeAll()
        persistDebounced()
    }

    // MARK: - Persistence

    private func persistDebounced() {
        readDebounce?.cancel()
        readDebounce = nil
        writeDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persistToDisk()
            self?.suppressReloadUntil = Date().addingTimeInterval(0.5)
            self?.writeDebounce = nil
        }
        writeDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private var jsonURL: URL { SlopFile.jsonURL(in: fileURL) }

    private func persistToDisk() {
        slopFile.data = rawData
        guard let data = try? slopFile.encodedData(schema: schema) else { return }
        try? SlopFile.writePackage(at: fileURL, data: data)
        schedulePreviewRender()
    }

    private func schedulePreviewRender() {
        previewDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onNeedPreviewRender?()
            self?.previewDebounce = nil
        }
        previewDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    // MARK: - Undo/Redo

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(rawData)
        rawData = previous
        rawStore.externalUpdate(previous)
        persistDebounced()
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(rawData)
        rawData = next
        rawStore.externalUpdate(next)
        persistDebounced()
    }

    private func pushUndo(_ oldValues: [String: FieldValue]) {
        undoStack.append(oldValues)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
    }

    // MARK: - Theme

    public func setTheme(_ name: String?) {
        slopFile.theme = name
        themeName = name
        slopFile.data = rawData
        guard let data = try? slopFile.encodedData(schema: schema) else { return }
        try? SlopFile.writePackage(at: fileURL, data: data)
        suppressReloadUntil = Date().addingTimeInterval(0.5)
        schedulePreviewRender()
    }

    // MARK: - Window Shape

    public func setShape(_ shape: WindowShape?) {
        slopFile.windowShape = shape
        currentWindowShape = shape ?? metadata.windowShape
        slopFile.data = rawData
        guard let data = try? slopFile.encodedData(schema: schema) else { return }
        try? SlopFile.writePackage(at: fileURL, data: data)
        suppressReloadUntil = Date().addingTimeInterval(0.5)
    }

    // MARK: - Always on Top

    public func setAlwaysOnTop(_ value: Bool) {
        slopFile.alwaysOnTop = value
        alwaysOnTop = value
        slopFile.data = rawData
        guard let data = try? slopFile.encodedData(schema: schema) else { return }
        try? SlopFile.writePackage(at: fileURL, data: data)
        suppressReloadUntil = Date().addingTimeInterval(0.5)
    }

    // MARK: - File Watcher

    private func startFileWatcher() {
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            persistToDisk()
            return
        }
        restartFileWatcher()
    }

    private func restartFileWatcher() {
        dispatchSource?.cancel()
        dispatchSource = nil

        fileDescriptor = open(jsonURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let fd = fileDescriptor
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.handleFileEvent()
        }
        src.setCancelHandler {
            close(fd)
        }
        src.resume()
        dispatchSource = src
    }

    private func handleFileEvent() {
        guard writeDebounce == nil else { return }
        readDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reloadFromDisk()
            self.restartFileWatcher()
        }
        readDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    public func reloadFromDisk() {
        guard Date() >= suppressReloadUntil else { return }
        guard let envelope = try? SlopFile.loadEnvelope(from: fileURL)
        else { return }
        let decoded = SlopFile(envelope: envelope, schema: schema)
        let mergedValues = Self.merge(values: decoded.data, over: schema.defaultValues())
        guard mergedValues != rawData || decoded.theme != slopFile.theme || decoded.alwaysOnTop != slopFile.alwaysOnTop else { return }
        let oldValues = rawData
        slopFile = decoded
        rawData = mergedValues
        themeName = decoded.theme
        alwaysOnTop = decoded.alwaysOnTop ?? metadata.alwaysOnTop
        rawStore.externalUpdate(mergedValues)
        pushUndo(oldValues)
        redoStack.removeAll()
    }

    // MARK: - Sidecar Files

    private func setupSidecarFields() {
        for field in schema.allFields where field.kind == .file {
            guard let desc = field.fileDescriptor else { continue }
            sidecarFields[field.key] = desc

            // Load existing sidecar content
            let sidecarURL = fileURL.appendingPathComponent(desc.defaultFilename)
            if desc.isText {
                if let content = try? String(contentsOf: sidecarURL, encoding: .utf8) {
                    sidecarStore.externalTextUpdate(content, forKey: field.key)
                } else {
                    sidecarStore.externalTextUpdate("", forKey: field.key)
                }
            } else {
                if let data = try? Data(contentsOf: sidecarURL) {
                    sidecarStore.externalBinaryUpdate(data, forKey: field.key)
                }
            }

            // Start file watcher for this sidecar
            startSidecarFileWatcher(forKey: field.key, filename: desc.defaultFilename)
        }

        // Wire persist handler: debounced write back to sidecar file
        sidecarStore.setPersistHandler { [weak self] key, content in
            self?.sidecarContentDidChange(key: key, content: content)
        }
    }

    private func sidecarContentDidChange(key: String, content: String) {
        guard let desc = sidecarFields[key] else { return }
        sidecarWriteDebounces[key]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let sidecarURL = self.fileURL.appendingPathComponent(desc.defaultFilename)
            try? content.write(to: sidecarURL, atomically: true, encoding: .utf8)
            self.sidecarSuppressReloadUntil[key] = Date().addingTimeInterval(0.5)
            self.sidecarWriteDebounces[key] = nil
            self.schedulePreviewRender()
        }
        sidecarWriteDebounces[key] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// URL for a sidecar file inside the package.
    public func sidecarURL(forKey key: String) -> URL? {
        guard let desc = sidecarFields[key] else { return nil }
        return fileURL.appendingPathComponent(desc.defaultFilename)
    }

    private func startSidecarFileWatcher(forKey key: String, filename: String) {
        let sidecarURL = fileURL.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else { return }
        restartSidecarFileWatcher(forKey: key, filename: filename)
    }

    private func restartSidecarFileWatcher(forKey key: String, filename: String) {
        sidecarDispatchSources[key]?.cancel()
        sidecarDispatchSources[key] = nil

        let sidecarURL = fileURL.appendingPathComponent(filename)
        let fd = open(sidecarURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        sidecarFileDescriptors[key] = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.handleSidecarFileEvent(key: key, filename: filename)
        }
        src.setCancelHandler {
            close(fd)
        }
        src.resume()
        sidecarDispatchSources[key] = src
    }

    private func handleSidecarFileEvent(key: String, filename: String) {
        guard sidecarWriteDebounces[key] == nil else { return }
        guard Date() >= (sidecarSuppressReloadUntil[key] ?? .distantPast) else { return }

        let sidecarURL = fileURL.appendingPathComponent(filename)
        guard let content = try? String(contentsOf: sidecarURL, encoding: .utf8) else { return }
        guard content != sidecarStore.textContent[key] else { return }
        sidecarStore.externalTextUpdate(content, forKey: key)

        // Restart watcher (file may have been replaced atomically)
        restartSidecarFileWatcher(forKey: key, filename: filename)
    }

    public func tearDown() {
        writeDebounce?.cancel()
        readDebounce?.cancel()
        previewDebounce?.cancel()
        dispatchSource?.cancel()
        dispatchSource = nil
        // Tear down sidecar watchers
        for (_, work) in sidecarWriteDebounces { work.cancel() }
        sidecarWriteDebounces.removeAll()
        for (_, src) in sidecarDispatchSources { src.cancel() }
        sidecarDispatchSources.removeAll()
        sidecarFileDescriptors.removeAll()
    }

    deinit {
        dispatchSource?.cancel()
        dispatchSource = nil
        for (_, src) in sidecarDispatchSources { src.cancel() }
    }

    private static func merge(
        values: [String: FieldValue],
        over defaults: [String: FieldValue]
    ) -> [String: FieldValue] {
        var merged = defaults
        for (key, value) in values {
            merged[key] = value
        }
        return merged
    }
}
