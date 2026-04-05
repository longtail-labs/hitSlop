import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import SlopUI
import SlopAI
import SlopIPC
import SlopCLI
import FirebaseCore
import Sharing
import os

@main
struct hitSlopApp: App {
    @NSApplicationDelegateAdaptor var delegate: AppDelegate

    init() {
        if SlopCLI.isCLIMode {
            SlopCLI.run()
        }
    }

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("New From Template\u{2026}") {
                        delegate.showPicker()
                    }
                    .keyboardShortcut("n")

                    Button("Open\u{2026}") {
                        delegate.openFilePanel()
                    }
                    .keyboardShortcut("o")

                    Menu("Open Recent") {
                        let recents = delegate.recentURLs
                        if recents.isEmpty {
                            Button("No Recent Documents") { }
                                .disabled(true)
                        } else {
                            ForEach(recents, id: \.path) { url in
                                Button(url.deletingPathExtension().lastPathComponent) {
                                    delegate.openTemplate(url)
                                }
                            }
                            Divider()
                            Button("Clear Recents") {
                                delegate.clearRecents()
                            }
                        }
                    }

                    Divider()

                    Button("Close Window") {
                        delegate.closeWindow()
                    }
                    .keyboardShortcut("w")
                }

                CommandGroup(replacing: .undoRedo) {
                    Button("Undo") { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
                        .keyboardShortcut("z")
                    Button("Redo") { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
                        .keyboardShortcut("z", modifiers: [.command, .shift])
                }

                CommandGroup(replacing: .pasteboard) {
                    Button("Cut") { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                        .keyboardShortcut("x")
                    Button("Copy") { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                        .keyboardShortcut("c")
                    Button("Paste") { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                        .keyboardShortcut("v")
                    Divider()
                    Button("Select All") { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
                        .keyboardShortcut("a")
                }
            }
    }
}

extension URL {
    static let recentsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".hitslop")
        .appendingPathComponent("recents.json")
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, SlopTemplateWindowDelegate {
    var slopTemplateWindows: [SlopTemplateWindow] = []
    var pickerWindow: NSWindow?
    let templateRegistry = SlopTemplateRegistry()
    let aiService = SlopAIService()
    let commandServer = CommandServer()

    @ObservationIgnored
    @Shared(.fileStorage(.recentsURL)) var recentDocuments: [RecentDocument] = []

    private static let hitslopDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".hitslop")
    private static let templatesDir = hitslopDir.appendingPathComponent("templates")
    private static let skinsDir = hitslopDir.appendingPathComponent("skins")
    private static let themesDir = hitslopDir.appendingPathComponent("themes")

    private static let log = Logger(subsystem: "com.hitslop.ai", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Firebase must be configured before any AI service calls.
        // Requires GoogleService-Info.plist in the app bundle.
        if let _ = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            FirebaseApp.configure()
            Self.log.info("Firebase configured — app=\(FirebaseApp.app()?.name ?? "<nil>", privacy: .public)")
        } else {
            Self.log.error("GoogleService-Info.plist NOT found in app bundle — Firebase AI will not work")
        }

        installKeyboardMonitor()
        seedTemplatesIfNeeded()
        seedThemesIfNeeded()
        templateRegistry.scan()
        SlopTemplatePreviewCache.generatePreviews(for: templateRegistry.entries)

        startCommandServer()
        CLIInstaller.install()
        CLIInstaller.installShellPath()
        CLIInstaller.installSkill()
        CLIInstaller.installHook()

        let args = ProcessInfo.processInfo.arguments
        if args.count > 1, FileManager.default.fileExists(atPath: args[1]) {
            openTemplate(URL(fileURLWithPath: args[1]))
        } else {
            showPicker()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        commandServer.stop()
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    private func installKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Only intercept Cmd-W for borderless windows (menu shortcuts don't reach them)
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "w",
                  let keyWindow = NSApp.keyWindow,
                  self.owningTemplateWindow(for: keyWindow) != nil
            else { return event }
            self.closeWindow()
            return nil
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openTemplate(url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showPicker() }
        return true
    }

    // MARK: - Menu Actions
	
    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        if let slopType = UTType(filenameExtension: "slop") {
            panel.allowedContentTypes = [slopType]
        }
        if panel.runModal() == .OK, let url = panel.url {
            openTemplate(url)
        }
    }

    func closeWindow() {
        guard let keyWindow = NSApp.keyWindow else { return }
        if let window = owningTemplateWindow(for: keyWindow) {
            closeTemplateWindow(window)
            return
        }
        keyWindow.close()
    }

    // MARK: - Template Opening

    func openTemplate(_ url: URL) {
        do {
            let window = try SlopTemplateWindow(
                fileURL: url,
                registry: templateRegistry,
                aiService: aiService
            )
            window.delegate = self
            slopTemplateWindows.append(window)
            window.show()
            trackRecent(url)
        } catch {
            NSLog("Failed to open .slop file: \(error)")
            let alert = NSAlert()
            alert.messageText = "Failed to open template"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - Recents

    func trackRecent(_ url: URL) {
        let envelope = try? SlopFile.loadEnvelope(from: url)

        let recent = RecentDocument(
            url: url,
            templateID: envelope?.templateID,
            templateVersion: envelope?.templateVersion
        )

        // Remove existing entry for this path (avoid duplicates)
        recentDocuments.removeAll { $0.path == url.path }

        // Insert at the beginning (most recent first)
        recentDocuments.insert(recent, at: 0)

        // Trim to 100 most recent
        if recentDocuments.count > 100 {
            recentDocuments = Array(recentDocuments.prefix(100))
        }
    }

    var recentURLs: [URL] {
        recentDocuments
            .sorted { $0.lastOpened > $1.lastOpened }
            .map { URL(fileURLWithPath: $0.path) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .prefix(100)
            .map { $0 }
    }

    func clearRecents() {
        recentDocuments.removeAll()
    }

    // MARK: - Picker

    func showPicker() {
        if let existing = pickerWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = makePickerWindow(delegate: self)
        pickerWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Template Seeding

    /// On first launch, copy bundled Slop template bundles to ~/.hitslop/templates/
    private func seedTemplatesIfNeeded() {
        let fm = FileManager.default
        let dest = Self.templatesDir
        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)

        if let bundled = SlopBundledResources.templatesDirectoryURL {
            copyMissingItems(from: bundled, to: dest, fm: fm)
        }
    }

    /// Ensure the user theme directory exists. Bundled themes are read from the app bundle
    /// via `ThemeCatalog`; only user-authored overrides live in `~/.hitslop/themes/`.
    private func seedThemesIfNeeded() {
        let fm = FileManager.default
        let dest = Self.themesDir
        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)

        SlopThemeLoader.invalidateCache()
    }

    private func copyMissingItems(from src: URL, to dest: URL, fm: FileManager) {
        guard let items = try? fm.contentsOfDirectory(
            at: src,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for srcItem in items {
            let dstItem = dest.appendingPathComponent(srcItem.lastPathComponent)
            let isDirectory = (try? srcItem.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true

            if isDirectory {
                if !fm.fileExists(atPath: dstItem.path) {
                    try? fm.createDirectory(at: dstItem, withIntermediateDirectories: true)
                }
                copyMissingItems(from: srcItem, to: dstItem, fm: fm)
            } else if !fm.fileExists(atPath: dstItem.path) {
                try? fm.copyItem(at: srcItem, to: dstItem)
            }
        }
    }

    // MARK: - SlopTemplateWindowDelegate

    func slopTemplateWindowRequestsClose(_ window: SlopTemplateWindow) {
        closeTemplateWindow(window)
    }

    func slopTemplateWindowRequestsDuplicate(_ window: SlopTemplateWindow) {
        let srcURL = window.document.fileURL
        let fm = FileManager.default
        let parent = srcURL.deletingLastPathComponent()
        let baseName = srcURL.deletingPathExtension().lastPathComponent
        let ext = srcURL.pathExtension

        var destURL = parent.appendingPathComponent("\(baseName) copy.\(ext)")
        var counter = 2
        while fm.fileExists(atPath: destURL.path) {
            destURL = parent.appendingPathComponent("\(baseName) copy \(counter).\(ext)")
            counter += 1
        }

        do {
            try fm.copyItem(at: srcURL, to: destURL)
            openTemplate(destURL)
        } catch {
            NSLog("Duplicate failed: \(error)")
        }
    }

    func slopTemplateWindowRequestsOpen(_ window: SlopTemplateWindow, in editor: ExternalEditor) {
        let url = window.document.fileURL
        switch editor {
        case .finder:
            NSWorkspace.shared.activateFileViewerSelecting([url])
        default:
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: editor.bundleID) {
                NSWorkspace.shared.open(
                    [url], withApplicationAt: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
        }
    }

    private func owningTemplateWindow(for window: NSWindow) -> SlopTemplateWindow? {
        slopTemplateWindows.first { $0.owns(window: window) }
    }

    private func closeTemplateWindow(_ window: SlopTemplateWindow) {
        window.tearDownToolbar()
        window.tearDownInspector()
        window.tearDownChat()
        window.document.tearDown()
        window.window.close()
        DispatchQueue.main.async { [self] in
            slopTemplateWindows.removeAll { $0 === window }
        }
    }

    // MARK: - IPC Server

    private func startCommandServer() {
        let handler = SlopIPCHandler(
            registry: templateRegistry,
            openDocument: { [weak self] url in self?.openTemplate(url) },
            showPicker: { [weak self] in self?.showPicker() },
            getRecents: { [weak self] in self?.recentURLs ?? [] },
            clearRecents: { [weak self] in self?.clearRecents() },
            getVersion: {
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
            }
        )
        commandServer.handler = { request in
            await handler.handle(request)
        }

        do {
            try commandServer.start()
        } catch {
            NSLog("Failed to start command server: \(error)")
        }
    }
}
