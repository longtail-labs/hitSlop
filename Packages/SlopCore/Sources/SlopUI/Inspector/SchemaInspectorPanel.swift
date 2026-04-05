import AppKit
import SwiftUI
import SlopKit

@MainActor
final class SchemaInspectorPanel: NSPanel {
    static let panelWidth: CGFloat = 280
    private static let cornerRadius: CGFloat = 12

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(document: SlopTemplateDocumentModel, schema: Schema) {
        let rect = NSRect(x: 0, y: 0, width: Self.panelWidth, height: 440)
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        isRestorable = false
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.moveToActiveSpace]

        let root = SchemaInspectorView(
            document: document,
            schema: schema
        )
        .frame(width: Self.panelWidth)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))

        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = rect
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    func reposition(relativeTo window: NSWindow, gap: CGFloat = 8) {
        let parentFrame = window.frame
        let x = parentFrame.minX - Self.panelWidth - gap
        let y = parentFrame.minY
        let height = parentFrame.height
        setFrame(
            NSRect(x: x, y: y, width: Self.panelWidth, height: height),
            display: true
        )
    }
}
