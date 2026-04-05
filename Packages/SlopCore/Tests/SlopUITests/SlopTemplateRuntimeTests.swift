import Foundation
import AppKit
import CoreGraphics
import ImageIO
import SwiftUI
import Testing
@testable import SlopAI
@testable import SlopUI
@testable import SlopKit

private struct TallExportProbeView: View {
    @Environment(\.slopRenderTarget) private var renderTarget
    @Environment(\.slopTheme) private var theme

    var body: some View {
        Group {
            if renderTarget == .interactive {
                ScrollView(showsIndicators: false) {
                    content
                }
            } else {
                content
            }
        }
        .background(theme.background)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<60, id: \.self) { row in
                Text("Row \(row)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
    }
}

private struct ExportVisibilityProbeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 10)
            Color.clear.frame(height: 40).slopOnlyInExport()
            Color.clear.frame(height: 30).slopHiddenInExport()
        }
    }
}

private func makeTempPackageURL() -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("slop")
}

private func writeSlopPackage(_ file: SlopFile, schema: Schema, to packageURL: URL) throws {
    let encoded = try file.encodedData(schema: schema)
    try SlopFile.writePackage(at: packageURL, data: encoded)
}

private func makeTestSchema() -> Schema {
    Schema(sections: [
        SchemaSection("General", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("Initial"))
        ])
    ])
}

@MainActor
private func makeTestDocument(
    schema: Schema = makeTestSchema(),
    value: String = "Initial"
) throws -> (URL, SlopFile, SlopTemplateDocumentModel) {
    let packageURL = makeTempPackageURL()
    let initial = SlopFile(
        templateID: "com.hitslop.tests.card",
        templateVersion: "1.0.0",
        data: ["title": .string(value)]
    )
    try writeSlopPackage(initial, schema: schema, to: packageURL)

    let document = SlopTemplateDocumentModel(
        fileURL: packageURL,
        slopFile: initial,
        schema: schema,
        metadata: TemplateMetadata(width: 200, height: 100)
    )
    return (packageURL, initial, document)
}

@MainActor
private func measuredHeight<V: View>(
    for view: V,
    renderTarget: SlopRenderTarget,
    width: CGFloat = 120
) -> CGFloat {
    let hostingView = NSHostingView(
        rootView: AnyView(view)
            .environment(\.slopRenderTarget, renderTarget)
            .environment(\.slopTheme, SlopTheme.from("cool"))
    )
    hostingView.frame = NSRect(x: 0, y: 0, width: width, height: 10)
    hostingView.layoutSubtreeIfNeeded()
    hostingView.invalidateIntrinsicContentSize()
    return max(hostingView.fittingSize.height, hostingView.intrinsicContentSize.height)
}

private func pngPointSize(at url: URL, scale: CGFloat = 2) -> CGSize? {
    guard let data = try? Data(contentsOf: url),
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let w = props[kCGImagePropertyPixelWidth] as? Int,
          let h = props[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    return CGSize(width: CGFloat(w) / scale, height: CGFloat(h) / scale)
}

private func renderedPDFCornerColor(_ pdfData: Data, size: NSSize) -> (UInt8, UInt8, UInt8)? {
    guard let provider = CGDataProvider(data: pdfData as CFData),
          let document = CGPDFDocument(provider),
          let page = document.page(at: 1)
    else { return nil }

    let width = Int(size.width)
    let height = Int(size.height)
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    context.drawPDFPage(page)

    let idx = ((height - 1) * width) * 4
    return (pixels[idx], pixels[idx + 1], pixels[idx + 2])
}

@Test
func registryOnlyIndexesManifestBackedTemplateInstalls() async throws {
    let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let installsDir = tempRoot.appendingPathComponent("templates", isDirectory: true)
    try FileManager.default.createDirectory(at: installsDir, withIntermediateDirectories: true)

    let installURL = installsDir
        .appendingPathComponent("com.hitslop.tests.card", isDirectory: true)
        .appendingPathComponent("1.0.0", isDirectory: true)
    try FileManager.default.createDirectory(at: installURL, withIntermediateDirectories: true)
    try Data().write(to: installURL.appendingPathComponent("Card.bundle"))

    let manifest = TemplateManifest(
        id: "com.hitslop.tests.card",
        name: "Card",
        version: "1.0.0",
        bundleFile: "Card.bundle",
        metadata: TemplateMetadata(width: 200, height: 100),
        schema: Schema(sections: [
            SchemaSection("General", fields: [
                FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("Card"))
            ])
        ])
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: installURL.appendingPathComponent("template.json"))

    let strayBundle = installsDir.appendingPathComponent("Stray.bundle", isDirectory: true)
    try FileManager.default.createDirectory(at: strayBundle, withIntermediateDirectories: true)

    let registry = await MainActor.run {
        SlopTemplateRegistry(templatesDirectory: installsDir)
    }
    await MainActor.run {
        registry.scan()
    }

    let entries = await MainActor.run {
        registry.entries
    }

    let cardEntry = entries.first {
        $0.manifest.id == "com.hitslop.tests.card" && $0.manifest.version == "1.0.0"
    }
    #expect(cardEntry != nil)
    #expect(entries.contains { $0.manifest.id == "com.hitslop.templates.habit-tracker" })
    #expect(!entries.contains { $0.installURL == strayBundle })
}

@Test
func slopFileRoundTripPreservesTypedSchemaValues() throws {
    let schema = Schema(sections: [
        SchemaSection("General", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("Untitled")),
            FieldDescriptor(key: "accent", label: "Accent", kind: .color, defaultValue: .color("#111111")),
            FieldDescriptor(key: "when", label: "When", kind: .date, defaultValue: .date(Date(timeIntervalSince1970: 0))),
            FieldDescriptor(key: "logo", label: "Logo", kind: .image, defaultValue: .image("/tmp/default.png")),
            FieldDescriptor(
                key: "items",
                label: "Items",
                kind: .array,
                defaultValue: .array([]),
                itemSchema: Schema(sections: [
                    SchemaSection("Item", fields: [
                        FieldDescriptor(key: "label", label: "Label", kind: .string, defaultValue: .string("")),
                    ])
                ])
            ),
            FieldDescriptor(
                key: "profile",
                label: "Profile",
                kind: .record,
                defaultValue: .record([:]),
                recordSchema: Schema(sections: [
                    SchemaSection("Profile", fields: [
                        FieldDescriptor(key: "name", label: "Name", kind: .string, defaultValue: .string("")),
                    ])
                ])
            ),
        ])
    ])

    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let file = SlopFile(
        templateID: "com.hitslop.tests.card",
        templateVersion: "1.0.0",
        data: [
            "title": .string("Budget"),
            "accent": .color("#ff00ff"),
            "when": .date(date),
            "logo": .image("/tmp/logo.png"),
            "items": .array([.record(["label": .string("One")])]),
            "profile": .record(["name": .string("Jordan")]),
        ],
        theme: "ocean",
        alwaysOnTop: false
    )

    let tempURL = makeTempPackageURL()
    try writeSlopPackage(file, schema: schema, to: tempURL)

    let envelope = try SlopFile.loadEnvelope(from: tempURL)
    let decoded = SlopFile(envelope: envelope, schema: schema)

    #expect(decoded.templateID == "com.hitslop.tests.card")
    #expect(decoded.templateVersion == "1.0.0")
    #expect(decoded.theme == "ocean")
    #expect(decoded.alwaysOnTop == false)
    #expect(decoded.data["accent"] == .color("#ff00ff"))
    #expect(decoded.data["logo"] == .image("/tmp/logo.png"))
    #expect(decoded.data["items"]?.asArray?.first?.asRecord?["label"] == .string("One"))
    #expect(decoded.data["profile"]?.asRecord?["name"] == .string("Jordan"))
    #expect(decoded.data["when"]?.asDate == date)
}

@Test
func templateSideWritesPersistThroughDocumentModel() async throws {
    let schema = Schema(sections: [
        SchemaSection("General", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("Initial"))
        ])
    ])

    let (tempURL, _, document) = try await MainActor.run {
        try makeTestDocument(schema: schema)
    }

    await MainActor.run {
        document.rawStore.setValue(.string("Updated"), forKey: "title")
    }
    try await Task.sleep(for: .milliseconds(500))

    let envelope = try SlopFile.loadEnvelope(from: tempURL)
    let decoded = SlopFile(envelope: envelope, schema: schema)
    #expect(decoded.data["title"] == .string("Updated"))

    await MainActor.run {
        document.tearDown()
    }
}

@Test
func externalDiskChangesReloadIntoOpenDocument() async throws {
    let schema = Schema(sections: [
        SchemaSection("General", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("Initial"))
        ])
    ])

    let (tempURL, _, document) = try await MainActor.run {
        try makeTestDocument(schema: schema)
    }

    let updated = SlopFile(
        templateID: "com.hitslop.tests.card",
        templateVersion: "1.0.0",
        data: ["title": .string("External")]
    )
    try writeSlopPackage(updated, schema: schema, to: tempURL)

    await MainActor.run {
        document.reloadFromDisk()
    }

    let value = await MainActor.run {
        document.rawData["title"]
    }
    #expect(value == .string("External"))

    await MainActor.run {
        document.tearDown()
    }
}

@Test
func inspectorPanelCanBecomeKeyForEditableControls() async throws {
    let schema = Schema(sections: [
        SchemaSection("General", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("Initial"))
        ])
    ])

    let (_, _, document) = try await MainActor.run {
        try makeTestDocument(schema: schema)
    }

    await MainActor.run {
        let panel = SchemaInspectorPanel(document: document, schema: schema)
        #expect(panel.canBecomeKey)
        #expect(!panel.styleMask.contains(.nonactivatingPanel))
        panel.close()
        document.tearDown()
    }
}

@Test
@MainActor
func pdfExportUsesTemplateWidthAndExpandsToFullContentHeight() {
    let metadata = TemplateMetadata(
        width: 280,
        height: 120,
        windowShape: .roundedRect(radius: 16)
    )

    let snapshot = SlopTemplatePDFExporter.render(
        makeTemplateBody: { AnyView(TallExportProbeView()) },
        metadata: metadata,
        themeName: "cool",
        bundleURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    )

    #expect(snapshot != nil)
    guard let snapshot else { return }

    #expect(snapshot.size.width == 280)
    #expect(snapshot.size.height > 120)
    #expect(String(decoding: snapshot.pdfData.prefix(5), as: UTF8.self) == "%PDF-")
}

@Test
@MainActor
func imageExportUsesMeasuredFullContentHeight() {
    let metadata = TemplateMetadata(
        width: 280,
        height: 120,
        windowShape: .roundedRect(radius: 16)
    )

    let snapshot = SlopTemplateSnapshotRenderer.renderImage(
        makeTemplateBody: { AnyView(TallExportProbeView()) },
        metadata: metadata,
        themeName: "cool",
        bundleURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        scale: 2
    )

    #expect(snapshot != nil)
    guard let snapshot else { return }

    #expect(snapshot.size.width == 280)
    #expect(snapshot.size.height > 120)
}

@Test
@MainActor
func pdfExportDoesNotClipRoundedCorners() {
    let metadata = TemplateMetadata(
        width: 80,
        height: 80,
        windowShape: .roundedRect(radius: 24)
    )

    let snapshot = SlopTemplateSnapshotRenderer.renderPDF(
        makeTemplateBody: {
            AnyView(
                Color.black
                    .frame(width: 80, height: 80)
            )
        },
        metadata: metadata,
        themeName: nil,
        bundleURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    )

    #expect(snapshot != nil)
    guard let snapshot,
          let corner = renderedPDFCornerColor(snapshot.pdfData, size: snapshot.size) else { return }

    #expect(corner.0 < 250 || corner.1 < 250 || corner.2 < 250)
}

@Test
@MainActor
func previewRenderingUsesSameMeasuredHeightAsImageExport() throws {
    let metadata = TemplateMetadata(
        width: 280,
        height: 120,
        windowShape: .roundedRect(radius: 16)
    )
    let packageURL = makeTempPackageURL()
    try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

    let imageSnapshot = SlopTemplateSnapshotRenderer.renderImage(
        makeTemplateBody: { AnyView(TallExportProbeView()) },
        metadata: metadata,
        themeName: "cool",
        bundleURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        scale: 2
    )
    #expect(imageSnapshot != nil)

    SlopTemplatePreviewCache.renderDocumentPreview(
        templateBody: AnyView(TallExportProbeView()),
        metadata: metadata,
        themeName: "cool",
        bundleURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        packageURL: packageURL
    )

    guard let imageSnapshot,
          let previewPointSize = pngPointSize(at: packageURL.appendingPathComponent("preview.png")) else { return }

    #expect(previewPointSize.width == imageSnapshot.size.width)
    #expect(previewPointSize.height == imageSnapshot.size.height)
}

@Test
@MainActor
func swiftExportVisibilityHelpersReactToRenderTarget() {
    let interactiveHeight = measuredHeight(for: ExportVisibilityProbeView(), renderTarget: .interactive)
    let exportHeight = measuredHeight(for: ExportVisibilityProbeView(), renderTarget: .imageExport)

    #expect(interactiveHeight < exportHeight)
}

@Test
@MainActor
func scriptedLayoutReceivesRenderTargetContext() throws {
    let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("lua")
    let script = """
    local template = {}
    function template.layout(data, theme, context)
      if context and context.renderTarget == "imageExport" then
        return Frame({ height = 40 }, Text("image"))
      end
      return Frame({ height = 10 }, Text("interactive"))
    end
    return template
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)

    let engine = LuaTemplateEngine(scriptPath: scriptURL.path)
    try engine.load()
    let store = RawTemplateStore(values: [:], persist: { _ in })

    let interactiveNode = try engine.callLayout(
        store: store,
        theme: SlopTheme.from("cool"),
        renderTarget: .interactive
    )
    let exportNode = try engine.callLayout(
        store: store,
        theme: SlopTheme.from("cool"),
        renderTarget: .imageExport
    )

    if case .frame(_, let interactiveHeight, _, _) = interactiveNode {
        #expect(interactiveHeight == 10)
    } else {
        Issue.record("Expected interactive node to be a frame")
    }

    if case .frame(_, let exportHeight, _, _) = exportNode {
        #expect(exportHeight == 40)
    } else {
        Issue.record("Expected export node to be a frame")
    }
}

@Test
@MainActor
func scriptedExportVisibilityNodesOmitContentOutsideTheirTarget() {
    let root = LayoutNode.vstack(spacing: 0, children: [
        .frame(width: nil, height: 10, alignment: nil, child: .text("base", TextStyle())),
        .exportVisibility(.hideInExport, child: .frame(width: nil, height: 40, alignment: nil, child: .text("hidden", TextStyle()))),
    ])

    let interactiveHeight = measuredHeight(
        for: ScriptedTemplateRenderer(
            root: root,
            store: RawTemplateStore(values: [:], persist: { _ in }),
            theme: SlopTheme.from("cool"),
            renderTarget: .interactive,
            onAction: { _ in }
        ),
        renderTarget: .interactive
    )
    let exportHeight = measuredHeight(
        for: ScriptedTemplateRenderer(
            root: root,
            store: RawTemplateStore(values: [:], persist: { _ in }),
            theme: SlopTheme.from("cool"),
            renderTarget: .imageExport,
            onAction: { _ in }
        ),
        renderTarget: .imageExport
    )

    #expect(interactiveHeight > exportHeight)
}

@Test
@MainActor
func attachedPanelsAnchorToOppositeSidesOfParentWindow() throws {
    let (_, _, document) = try makeTestDocument()
    defer { document.tearDown() }

    let parent = NSWindow(
        contentRect: NSRect(x: 300, y: 200, width: 240, height: 180),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )

    let inspector = SchemaInspectorPanel(document: document, schema: document.schema)
    let chat = AIChatPanel(document: document, aiService: SlopAIService())

    inspector.reposition(relativeTo: parent)
    chat.reposition(relativeTo: parent)

    #expect(inspector.frame.maxX <= parent.frame.minX)
    #expect(chat.frame.minX >= parent.frame.maxX)

    inspector.close()
    chat.close()
}

@Test
func documentUpdateApplierPersistsThroughDocumentModel() async throws {
    let schema = makeTestSchema()
    let (packageURL, _, document) = try await MainActor.run {
        try makeTestDocument(schema: schema)
    }

    await MainActor.run {
        DocumentUpdateApplier.apply(
            .mergeFields(["title": .string("AI Updated")]),
            to: document.rawStore,
            schema: schema
        )
    }
    try await Task.sleep(for: .milliseconds(500))

    let envelope = try SlopFile.loadEnvelope(from: packageURL)
    let decoded = SlopFile(envelope: envelope, schema: schema)
    #expect(decoded.data["title"] == .string("AI Updated"))

    await MainActor.run {
        document.tearDown()
    }
}

// MARK: - Exportable Frame Tests

@Test
@MainActor
func exportableFrameAllowsContentToExpandBeyondInitialHeight() {
    // A view that uses slopExportableFrame for dynamic content
    struct DynamicHeightView: View {
        let itemCount: Int
        @Environment(\.slopRenderTarget) private var renderTarget

        var body: some View {
            VStack(spacing: 0) {
                // Header
                Text("Header")
                    .frame(height: 44)

                // Dynamic content that should expand
                VStack(spacing: 8) {
                    ForEach(0..<itemCount, id: \.self) { _ in
                        Text("Item")
                            .frame(height: 40)
                    }
                }
                .slopExportableFrame(maxHeight: .infinity)

                // Footer
                Text("Footer")
                    .frame(height: 44)
            }
            .slopExportableFrame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // Start with a small initial height (200) but content needs much more
    let metadata = TemplateMetadata(
        width: 300,
        height: 200,  // Small initial height
        windowShape: .roundedRect(radius: 16)
    )

    // 10 items at 40px each + spacing + header + footer = ~500+ px
    let snapshot = SlopTemplatePDFExporter.render(
        makeTemplateBody: { AnyView(DynamicHeightView(itemCount: 10)) },
        metadata: metadata,
        themeName: nil,
        bundleURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    )

    #expect(snapshot != nil)
    guard let snapshot else { return }

    // Width should match metadata
    #expect(snapshot.size.width == 300)

    // Height should expand well beyond the initial 200px
    // 10 items * 40px + 9 * 8px spacing + 44 header + 44 footer = 400 + 72 + 88 = 560
    #expect(snapshot.size.height > 500, "Height should expand to fit content, got \(snapshot.size.height)")
    #expect(String(decoding: snapshot.pdfData.prefix(5), as: UTF8.self) == "%PDF-")
}

@Test
@MainActor
func slopTextFieldConsistentWidthBetweenInteractiveAndExport() {
    // Verify SlopTextField doesn't have unexpected frame differences between modes
    struct TextFieldProbeView: View {
        @State var text = "Test content"
        @Environment(\.slopRenderTarget) var renderTarget

        var body: some View {
            VStack {
                SlopTextField("Placeholder", text: $text)
            }
            .padding(16)
            .frame(width: 200)
        }
    }

    let metadata = TemplateMetadata(
        width: 200,
        height: 100,
        windowShape: .roundedRect(radius: 8)
    )

    // Render both interactive and export
    let interactiveSnapshot = SlopTemplateSnapshotRenderer.renderImage(
        makeTemplateBody: { AnyView(TextFieldProbeView()) },
        metadata: metadata,
        themeName: nil,
        bundleURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        scale: 1
    )

    let exportSnapshot = SlopTemplatePDFExporter.render(
        makeTemplateBody: {
            AnyView(TextFieldProbeView().environment(\.slopRenderTarget, .pdfExport))
        },
        metadata: metadata,
        themeName: nil,
        bundleURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    )

    #expect(interactiveSnapshot != nil)
    #expect(exportSnapshot != nil)

    // Both should have the same width (200)
    guard let interactive = interactiveSnapshot, let exported = exportSnapshot else { return }
    #expect(interactive.size.width == 200)
    #expect(exported.size.width == 200)
}