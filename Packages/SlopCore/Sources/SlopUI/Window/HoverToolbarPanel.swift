import AppKit

/// Delegate for hover events on the toolbar panel itself.
protocol HoverToolbarPanelDelegate: AnyObject {
    func toolbarPanelMouseEntered()
    func toolbarPanelMouseExited()
}

/// A transparent, non-activating panel that floats above a shaped slop window
/// and contains the hover toolbar UI.
@MainActor
class HoverToolbarPanel: NSPanel {
    weak var hoverDelegate: HoverToolbarPanelDelegate?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        level = .floating + 1
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        let trackingView = ToolbarTrackingView(frame: contentRect)
        trackingView.autoresizingMask = [.width, .height]
        trackingView.panel = self
        contentView = trackingView
    }
}

// MARK: - Tracking View

/// Reports mouse enter/exit on the toolbar panel to the delegate.
private class ToolbarTrackingView: NSView {
    weak var panel: HoverToolbarPanel?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        panel?.hoverDelegate?.toolbarPanelMouseEntered()
    }

    override func mouseExited(with event: NSEvent) {
        panel?.hoverDelegate?.toolbarPanelMouseExited()
    }
}
