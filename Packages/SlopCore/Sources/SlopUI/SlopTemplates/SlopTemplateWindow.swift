import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SlopAI
import SlopKit
import SlopTemplates

/// Window coordinator for Slop templates.
/// Opens a `.slop` JSON file, resolves the template from the registry,
/// and renders it in a shaped window.
@MainActor
public class SlopTemplateWindow: NSObject, HoverToolbarPanelDelegate, NSWindowDelegate {
    public let window: ShapedWindow
    public let document: SlopTemplateDocumentModel
    public let template: any AnySlopTemplate
    private let bundleURL: URL?
    private let aiService: SlopAIService?

    public weak var delegate: SlopTemplateWindowDelegate?

    private var toolbarPanel: HoverToolbarPanel?
    private var inspectorPanel: SchemaInspectorPanel?
    private var chatPanel: AIChatPanel?
    private var themePickerPanel: ThemePickerPanel?
    private var skinPickerPanel: SkinPickerPanel?
    private var mouseTracker: HCMouseTrackingProxy?
    private var hideTimer: DispatchWorkItem?
    private var toolbarVisible = false
    private var inspectorVisible = false
    private var chatVisible = false
    private var themePickerVisible = false
    private var skinPickerVisible = false

    private static let toolbarGap: CGFloat = 6
    private static let toolbarHeight: CGFloat = 36
    private static let toolbarWidth: CGFloat = 348
    private static let hideDelay: TimeInterval = 0.15

    public enum OpenError: Error, LocalizedError {
        case fileReadFailed(URL)
        case templateNotFound(String, String)

        public var errorDescription: String? {
            switch self {
            case .fileReadFailed(let url):
                return "Failed to read .slop file at \(url.path)"
            case .templateNotFound(let templateID, let version):
                return "Template '\(templateID)' version \(version) was not found in ~/.hitslop/templates/"
            }
        }
    }

    public init(
        fileURL: URL,
        registry: SlopTemplateRegistry,
        aiService: SlopAIService? = nil
    ) throws {
        // 1. Parse the .slop envelope
        guard let envelope = try? SlopFile.loadEnvelope(from: fileURL) else {
            throw OpenError.fileReadFailed(fileURL)
        }

        // 2. Resolve the exact installed template version
        guard let entry = registry.resolve(
            templateID: envelope.templateID,
            version: envelope.templateVersion
        ) else {
            throw OpenError.templateNotFound(envelope.templateID, envelope.templateVersion)
        }

        // 3. Decode typed data using the resolved schema
        let slopFile = SlopFile(envelope: envelope, schema: entry.manifest.schema)
        self.bundleURL = entry.isBuiltIn
            ? BuiltInTemplateRegistry.resourceBundle.bundleURL
            : entry.bundleURL
        self.aiService = aiService

        // 4. Apply SlopFile overrides over template metadata
        let baseMeta = entry.manifest.metadata
        let meta = TemplateMetadata(
            width: baseMeta.width,
            height: baseMeta.height,
            minSize: baseMeta.minSize,
            windowShape: slopFile.windowShape ?? baseMeta.windowShape,
            theme: slopFile.theme ?? baseMeta.theme,
            alwaysOnTop: slopFile.alwaysOnTop ?? baseMeta.alwaysOnTop,
            titleBarHidden: baseMeta.titleBarHidden
        )

        // 5. Create document model
        self.document = SlopTemplateDocumentModel(
            fileURL: fileURL,
            slopFile: slopFile,
            schema: entry.manifest.schema,
            metadata: meta
        )

        // 6. Instantiate template — branch on built-in, scripted, or external bundle
        if let builtInType = entry.builtInType {
            // Built-in: direct instantiation, no loading
            self.template = builtInType.init(rawStore: document.rawStore, sidecarStore: document.sidecarStore)
        } else if let scriptURL = entry.scriptURL {
            // Tier 2: Lua scripted template
            self.template = try ScriptedTemplate.create(
                scriptPath: scriptURL.path,
                manifest: entry.manifest,
                rawStore: document.rawStore
            )
        } else if let bundleURL = entry.bundleURL {
            // Tier 1: Compiled Swift bundle
            let loaded = try SlopTemplateBundleLoader.load(
                bundleURL: bundleURL,
                expectedManifest: entry.manifest
            )
            self.template = loaded.templateType.init(rawStore: document.rawStore, sidecarStore: document.sidecarStore)
        } else {
            throw OpenError.templateNotFound(envelope.templateID, envelope.templateVersion)
        }

        // 8. Create window from metadata
        let size = NSSize(width: meta.width, height: meta.height)

        switch meta.windowShape {
        case .skin(let filename):
            // Try template bundle first, then SkinCatalog
            let skinURL: URL?
            if entry.isBuiltIn {
                skinURL = BuiltInTemplateRegistry.resourceBundle.resourceURL?
                    .appendingPathComponent(filename)
            } else {
                skinURL = entry.bundleURL?
                    .appendingPathComponent("Contents/Resources")
                    .appendingPathComponent(filename)
            }
            let resolvedURL = skinURL.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
                ?? SkinCatalog.resolve(filename)?.fileURL
            if let resolvedURL, let skin = SkinLoader.load(from: resolvedURL) {
                self.window = ShapedWindow(skin: skin)
            } else {
                let shape = NSBezierPath(
                    roundedRect: NSRect(origin: .zero, size: size),
                    xRadius: 16, yRadius: 16
                )
                self.window = ShapedWindow(shape: shape, size: size)
            }

        case .roundedRect(let radius):
            let shape = NSBezierPath(
                roundedRect: NSRect(origin: .zero, size: size),
                xRadius: radius, yRadius: radius
            )
            self.window = ShapedWindow(shape: shape, size: size)

        case .circle:
            let diameter = min(size.width, size.height)
            let circleSize = NSSize(width: diameter, height: diameter)
            let shape = NSBezierPath(ovalIn: NSRect(origin: .zero, size: circleSize))
            self.window = ShapedWindow(shape: shape, size: circleSize)

        case .capsule:
            let radius = min(size.width, size.height) / 2
            let shape = NSBezierPath(
                roundedRect: NSRect(origin: .zero, size: size),
                xRadius: radius, yRadius: radius
            )
            self.window = ShapedWindow(shape: shape, size: size)

        case .path:
            // TODO: SVG path parsing
            let shape = NSBezierPath(
                roundedRect: NSRect(origin: .zero, size: size),
                xRadius: 16, yRadius: 16
            )
            self.window = ShapedWindow(shape: shape, size: size)
        }

        super.init()

        // Wire up per-document preview rendering
        let previewBundleURL = self.bundleURL
        let previewTemplate = self.template
        let previewDocument = self.document
        document.onNeedPreviewRender = {
            SlopTemplatePreviewCache.renderDocumentPreview(
                templateBody: previewTemplate.body(),
                metadata: previewDocument.metadata,
                themeName: previewDocument.themeName,
                bundleURL: previewBundleURL ?? previewDocument.fileURL.deletingLastPathComponent(),
                packageURL: previewDocument.fileURL,
                effectiveShape: previewDocument.currentWindowShape
            )
        }

        self.window.isRestorable = false
        self.window.delegate = self

        // 9. Set up content view with template body + theme injection
        let undoResponder = SlopTemplateUndoResponder(document: document)
        undoResponder.frame = window.contentView?.bounds ?? .zero
        undoResponder.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(undoResponder)

        let themedView = SlopTemplateThemedView(
            document: document,
            templateBody: template.body(),
            bundleURL: bundleURL ?? entry.installURL,
            size: size
        )
        let hostingView = NSHostingView(rootView: themedView)
        undoResponder.addSubview(hostingView)
        hostingView.frame = undoResponder.bounds
        hostingView.autoresizingMask = [.width, .height]

        // 10. Window configuration
        window.level = meta.alwaysOnTop ? .floating : .normal

        setupToolbar()
        setupMouseTracking()
    }

    public func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func tearDownToolbar() {
        hideTimer?.cancel()
        hideTimer = nil
        toolbarVisible = false
        if let panel = toolbarPanel {
            panel.orderOut(nil)
            window.removeChildWindow(panel)
            panel.close()
        }
        toolbarPanel = nil
    }

    public func tearDownInspector() {
        inspectorVisible = false
        if let panel = inspectorPanel {
            panel.orderOut(nil)
            window.removeChildWindow(panel)
            panel.close()
        }
        inspectorPanel = nil
    }

    public func tearDownChat() {
        chatVisible = false
        if let panel = chatPanel {
            panel.orderOut(nil)
            window.removeChildWindow(panel)
            panel.close()
        }
        chatPanel = nil
    }

    public func tearDownThemePicker() {
        themePickerVisible = false
        if let panel = themePickerPanel {
            panel.orderOut(nil)
            window.removeChildWindow(panel)
            panel.close()
        }
        themePickerPanel = nil
    }

    public func tearDownSkinPicker() {
        skinPickerVisible = false
        if let panel = skinPickerPanel {
            panel.orderOut(nil)
            window.removeChildWindow(panel)
            panel.close()
        }
        skinPickerPanel = nil
    }

    public func owns(window candidate: NSWindow) -> Bool {
        candidate === window
            || candidate === toolbarPanel
            || candidate === inspectorPanel
            || candidate === chatPanel
            || candidate === themePickerPanel
            || candidate === skinPickerPanel
    }

    // MARK: - Toolbar

    private func setupToolbar() {
        let rect = NSRect(x: 0, y: 0, width: Self.toolbarWidth, height: Self.toolbarHeight)
        let panel = HoverToolbarPanel(contentRect: rect)
        panel.hoverDelegate = self
        let hostingView = NSHostingView(rootView: makeToolbarContentView())
        hostingView.frame = panel.contentView?.bounds ?? rect
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)

        window.addChildWindow(panel, ordered: .above)
        panel.orderOut(nil)
        toolbarPanel = panel
    }

    private func makeToolbarActions() -> SlopTemplateToolbarActions {
        SlopTemplateToolbarActions(
            close: { [weak self] in
                guard let self else { return }
                self.delegate?.slopTemplateWindowRequestsClose(self)
            },
            duplicate: { [weak self] in
                guard let self else { return }
                self.delegate?.slopTemplateWindowRequestsDuplicate(self)
            },
            openIn: { [weak self] editor in
                guard let self else { return }
                self.delegate?.slopTemplateWindowRequestsOpen(self, in: editor)
            },
            toggleInspector: { [weak self] in
                self?.toggleInspector()
            },
            toggleChat: { [weak self] in
                self?.toggleChat()
            },
            toggleThemePicker: { [weak self] in
                self?.toggleThemePicker()
            },
            toggleSkinPicker: { [weak self] in
                self?.toggleSkinPicker()
            },
            toggleAlwaysOnTop: { [weak self] in
                guard let self else { return }
                let newValue = !self.document.alwaysOnTop
                self.document.setAlwaysOnTop(newValue)
                self.window.level = newValue ? .floating : .normal
            },
            setTheme: { [weak self] name in
                self?.document.setTheme(name)
            },
            exportPDF: { [weak self] in
                self?.exportPDF()
            },
            exportImage: { [weak self] in
                self?.exportImage()
            }
        )
    }

    private func makeToolbarContentView() -> SlopTemplateToolbarContentView {
        SlopTemplateToolbarContentView(
            fileURL: document.fileURL,
            parentWindow: window,
            actions: makeToolbarActions(),
            document: document,
            inspectorVisible: inspectorVisible,
            chatVisible: chatVisible,
            chatAvailable: aiService != nil,
            themePickerVisible: themePickerVisible,
            skinPickerVisible: skinPickerVisible
        )
    }

    private func refreshToolbar() {
        guard let panel = toolbarPanel else { return }
        let hostingView = NSHostingView(rootView: makeToolbarContentView())
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.subviews.forEach { $0.removeFromSuperview() }
        panel.contentView?.addSubview(hostingView)
    }

    private func toggleInspector() {
        if inspectorVisible {
            hideInspector()
            return
        }
        showInspector()
    }

    private func showInspector() {
        let panel: SchemaInspectorPanel
        if let existing = inspectorPanel {
            panel = existing
        } else {
            let created = SchemaInspectorPanel(document: document, schema: document.schema)
            inspectorPanel = created
            window.addChildWindow(created, ordered: .above)
            panel = created
        }

        inspectorVisible = true
        panel.reposition(relativeTo: window)
        panel.makeKeyAndOrderFront(nil)
        refreshToolbar()
    }

    private func hideInspector() {
        guard inspectorVisible, let panel = inspectorPanel else { return }
        inspectorVisible = false
        panel.orderOut(nil)
        refreshToolbar()
    }

    private func toggleChat() {
        if chatVisible {
            hideChat()
            return
        }
        showChat()
    }

    private func showChat() {
        guard let aiService else { return }

        let panel: AIChatPanel
        if let existing = chatPanel {
            panel = existing
        } else {
            let created = AIChatPanel(document: document, aiService: aiService)
            chatPanel = created
            window.addChildWindow(created, ordered: .above)
            panel = created
        }

        chatVisible = true
        panel.reposition(relativeTo: window)
        panel.makeKeyAndOrderFront(nil)
        refreshToolbar()
    }

    private func hideChat() {
        guard chatVisible, let panel = chatPanel else { return }
        chatVisible = false
        panel.orderOut(nil)
        refreshToolbar()
    }

    private func toggleThemePicker() {
        if themePickerVisible {
            hideThemePicker()
            return
        }
        showThemePicker()
    }

    private func showThemePicker() {
        let panel: ThemePickerPanel
        if let existing = themePickerPanel {
            panel = existing
        } else {
            let created = ThemePickerPanel(document: document)
            themePickerPanel = created
            window.addChildWindow(created, ordered: .above)
            panel = created
        }

        themePickerVisible = true
        panel.reposition(relativeTo: window)
        panel.makeKeyAndOrderFront(nil)
        refreshToolbar()
    }

    private func hideThemePicker() {
        guard themePickerVisible, let panel = themePickerPanel else { return }
        themePickerVisible = false
        panel.orderOut(nil)
        refreshToolbar()
    }

    // MARK: - Skin Picker

    private func toggleSkinPicker() {
        if skinPickerVisible {
            hideSkinPicker()
            return
        }
        showSkinPicker()
    }

    private func showSkinPicker() {
        let panel: SkinPickerPanel
        if let existing = skinPickerPanel {
            panel = existing
        } else {
            let created = SkinPickerPanel(document: document) { [weak self] shape in
                self?.applyShape(shape)
            }
            skinPickerPanel = created
            window.addChildWindow(created, ordered: .above)
            panel = created
        }

        skinPickerVisible = true
        panel.reposition(relativeTo: window)
        panel.makeKeyAndOrderFront(nil)
        refreshToolbar()
    }

    private func hideSkinPicker() {
        guard skinPickerVisible, let panel = skinPickerPanel else { return }
        skinPickerVisible = false
        panel.orderOut(nil)
        refreshToolbar()
    }

    // MARK: - Apply Shape

    private func applyShape(_ shape: WindowShape?) {
        document.setShape(shape)

        let meta = document.metadata
        let size = NSSize(width: meta.width, height: meta.height)

        switch shape {
        case .skin(let skinID):
            if let entry = SkinCatalog.resolve(skinID),
               let skin = SkinLoader.load(from: entry.fileURL) {
                window.updateSkin(skin)
            }

        case .roundedRect(let radius):
            let path = NSBezierPath(
                roundedRect: NSRect(origin: .zero, size: size),
                xRadius: radius, yRadius: radius
            )
            window.updateToVector(path, size: size)

        case .circle:
            let diameter = min(size.width, size.height)
            let circleSize = NSSize(width: diameter, height: diameter)
            let path = NSBezierPath(ovalIn: NSRect(origin: .zero, size: circleSize))
            window.updateToVector(path, size: circleSize)

        case .capsule:
            let radius = min(size.width, size.height) / 2
            let path = NSBezierPath(
                roundedRect: NSRect(origin: .zero, size: size),
                xRadius: radius, yRadius: radius
            )
            window.updateToVector(path, size: size)

        case .path, nil:
            // Default: rounded rect
            let path = NSBezierPath(
                roundedRect: NSRect(origin: .zero, size: size),
                xRadius: 16, yRadius: 16
            )
            window.updateToVector(path, size: size)
        }

        repositionFloatingPanels()
    }

    private func setupMouseTracking() {
        let tracker = HCMouseTrackingProxy(owner: self)
        if let contentView = window.contentView {
            let area = NSTrackingArea(
                rect: contentView.bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: tracker,
                userInfo: nil
            )
            contentView.addTrackingArea(area)
        }
        mouseTracker = tracker
    }

    // MARK: - Export

    private var baseName: String {
        document.fileURL.deletingPathExtension().lastPathComponent
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = baseName + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let snapshot = SlopTemplateSnapshotRenderer.renderPDF(
            makeTemplateBody: { self.template.body() },
            metadata: document.metadata,
            themeName: document.themeName,
            bundleURL: bundleURL ?? document.fileURL.deletingLastPathComponent(),
            packageURL: document.fileURL,
            effectiveShape: document.currentWindowShape
        ) else { return }
        try? snapshot.pdfData.write(to: url, options: .atomic)
    }

    private func exportImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = baseName + ".png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let snapshot = SlopTemplateSnapshotRenderer.renderImage(
            makeTemplateBody: { self.template.body() },
            metadata: document.metadata,
            themeName: document.themeName,
            bundleURL: bundleURL ?? document.fileURL.deletingLastPathComponent(),
            scale: 2,
            packageURL: document.fileURL,
            effectiveShape: document.currentWindowShape
        ), let data = snapshot.pngData() else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Show/Hide Toolbar

    func showToolbar() {
        hideTimer?.cancel()
        hideTimer = nil
        guard !toolbarVisible, let panel = toolbarPanel else { return }
        toolbarVisible = true
        repositionToolbar()
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func scheduleHideToolbar() {
        hideTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hideToolbar()
        }
        hideTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hideDelay, execute: work)
    }

    private func hideToolbar() {
        guard toolbarVisible, let panel = toolbarPanel else { return }
        toolbarVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
            }
        })
    }

    private func repositionToolbar() {
        guard let panel = toolbarPanel else { return }
        let windowFrame = window.frame
        let toolbarSize = panel.frame.size
        let x = windowFrame.midX - toolbarSize.width / 2
        let y = windowFrame.maxY + Self.toolbarGap
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func repositionFloatingPanels() {
        if toolbarVisible {
            repositionToolbar()
        }
        if inspectorVisible {
            inspectorPanel?.reposition(relativeTo: window)
        }
        if chatVisible {
            chatPanel?.reposition(relativeTo: window)
        }
        if themePickerVisible {
            themePickerPanel?.reposition(relativeTo: window)
        }
        if skinPickerVisible {
            skinPickerPanel?.reposition(relativeTo: window)
        }
    }

    func windowMouseEntered() { showToolbar() }
    func windowMouseExited() { scheduleHideToolbar() }

    public func windowDidMove(_ notification: Notification) {
        repositionFloatingPanels()
    }

    public func windowDidResize(_ notification: Notification) {
        repositionFloatingPanels()
    }

    public func windowWillClose(_ notification: Notification) {
        tearDownToolbar()
        tearDownInspector()
        tearDownChat()
        tearDownThemePicker()
        tearDownSkinPicker()
    }

    // MARK: - HoverToolbarPanelDelegate

    nonisolated func toolbarPanelMouseEntered() {
        MainActor.assumeIsolated {
            hideTimer?.cancel()
            hideTimer = nil
        }
    }

    nonisolated func toolbarPanelMouseExited() {
        MainActor.assumeIsolated {
            scheduleHideToolbar()
        }
    }
}

// MARK: - Delegate

@MainActor
public protocol SlopTemplateWindowDelegate: AnyObject {
    func slopTemplateWindowRequestsClose(_ window: SlopTemplateWindow)
    func slopTemplateWindowRequestsDuplicate(_ window: SlopTemplateWindow)
    func slopTemplateWindowRequestsOpen(_ window: SlopTemplateWindow, in editor: ExternalEditor)
}

// MARK: - Toolbar

struct SlopTemplateToolbarActions {
    var close: () -> Void = {}
    var duplicate: () -> Void = {}
    var openIn: (ExternalEditor) -> Void = { _ in }
    var toggleInspector: () -> Void = {}
    var toggleChat: () -> Void = {}
    var toggleThemePicker: () -> Void = {}
    var toggleSkinPicker: () -> Void = {}
    var toggleAlwaysOnTop: () -> Void = {}
    var setTheme: (String?) -> Void = { _ in }
    var exportPDF: () -> Void = {}
    var exportImage: () -> Void = {}
}

struct SlopTemplateToolbarContentView: View {
    let fileURL: URL
    let parentWindow: NSWindow
    let actions: SlopTemplateToolbarActions
    @ObservedObject var document: SlopTemplateDocumentModel
    let inspectorVisible: Bool
    let chatVisible: Bool
    let chatAvailable: Bool
    let themePickerVisible: Bool
    let skinPickerVisible: Bool

    var body: some View {
        HStack(spacing: 2) {
            // Window
            Button { actions.close() } label: {
                toolbarIcon("xmark")
            }
            .buttonStyle(.plain)

            toolbarDivider()

            // View Toggles
            Button { actions.toggleAlwaysOnTop() } label: {
                toolbarIcon(document.alwaysOnTop ? "pin.fill" : "pin.slash")
            }
            .buttonStyle(.plain)

            Button { actions.toggleInspector() } label: {
                toolbarIcon("slider.horizontal.3", isActive: inspectorVisible)
            }
            .buttonStyle(.plain)

            Button { actions.toggleChat() } label: {
                toolbarIcon(chatVisible ? "bubble.right.fill" : "bubble.right", isActive: chatVisible)
            }
            .buttonStyle(.plain)
            .disabled(!chatAvailable)

            Button { actions.toggleThemePicker() } label: {
                toolbarIcon("paintpalette", isActive: themePickerVisible)
            }
            .buttonStyle(.plain)

            Button { actions.toggleSkinPicker() } label: {
                toolbarIcon("square.on.circle", isActive: skinPickerVisible)
            }
            .buttonStyle(.plain)

            toolbarDivider()

            // File Actions
            Menu {
                ForEach(ExternalEditor.available, id: \.rawValue) { editor in
                    Button(editor.rawValue) { actions.openIn(editor) }
                }
            } label: {
                toolbarIcon("arrow.up.forward.square")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button { actions.duplicate() } label: {
                toolbarIcon("doc.on.doc")
            }
            .buttonStyle(.plain)

            toolbarDivider()

            // Output
            Menu {
                Button("Save as PDF") { actions.exportPDF() }
                Button("Save as Image") { actions.exportImage() }
            } label: {
                toolbarIcon("arrow.down.doc")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button { showSharePicker() } label: {
                toolbarIcon("square.and.arrow.up")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func toolbarDivider() -> some View {
        Capsule()
            .fill(.primary.opacity(0.15))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 3)
    }

    private func toolbarIcon(_ systemName: String, isActive: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .frame(width: 28, height: 24)
            .contentShape(Rectangle())
    }

    private func showSharePicker() {
        let picker = NSSharingServicePicker(items: [fileURL])
        if let view = parentWindow.contentView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
    }
}

// MARK: - Undo Responder

private struct SlopTemplateThemedView: View {
    @ObservedObject var document: SlopTemplateDocumentModel
    let templateBody: AnyView
    let bundleURL: URL
    let size: NSSize

    var body: some View {
        SlopTemplateCanvasView(
            templateBody: templateBody,
            metadata: document.metadata,
            themeName: document.themeName,
            renderTarget: .interactive,
            bundleURL: bundleURL,
            canvasSize: size,
            clipToWindowShape: true,
            packageURL: document.fileURL,
            effectiveShape: document.currentWindowShape
        )
    }
}

private class SlopTemplateUndoResponder: NSView {
    let document: SlopTemplateDocumentModel

    init(document: SlopTemplateDocumentModel) {
        self.document = document
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    @objc func undo(_ sender: Any?) { document.undo() }
    @objc func redo(_ sender: Any?) { document.redo() }
}

// MARK: - Mouse Tracking

private class HCMouseTrackingProxy: NSResponder {
    weak var owner: SlopTemplateWindow?

    init(owner: SlopTemplateWindow) {
        self.owner = owner
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) {
        MainActor.assumeIsolated { owner?.windowMouseEntered() }
    }

    override func mouseExited(with event: NSEvent) {
        MainActor.assumeIsolated { owner?.windowMouseExited() }
    }
}
