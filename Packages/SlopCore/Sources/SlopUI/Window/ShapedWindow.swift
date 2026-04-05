import AppKit
import QuartzCore

public class ShapedWindow: NSWindow {

    /// Height in points of the top drag bar region used for window movement.
    /// Drags in this region move the window; clicks on interactive controls still work.
    public var dragBarHeight: CGFloat = 28

    override public var canBecomeKey: Bool { true }

    public init(shape: NSBezierPath, size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false

        let container = ShapedContentView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.shapePath = shape.cgPath
        contentView = container

        let mask = CAShapeLayer()
        mask.path = shape.cgPath
        container.layer?.mask = mask
    }

    /// Bitmap skin init — PNG alpha defines shape, image is background
    public init(skin: SkinImage) {
        let size = skin.size
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false

        let container = ShapedContentView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.alphaData = skin.alphaData
        container.alphaWidth = skin.alphaWidth
        container.alphaHeight = skin.alphaHeight
        contentView = container

        // Skin image as background layer
        let bgLayer = CALayer()
        bgLayer.name = "skinBackground"
        bgLayer.contents = skin.cgImage
        bgLayer.frame = CGRect(origin: .zero, size: size)
        bgLayer.contentsGravity = .resizeAspect
        container.layer?.addSublayer(bgLayer)

        // Alpha mask layer
        let maskLayer = CALayer()
        maskLayer.contents = skin.cgImage
        maskLayer.frame = CGRect(origin: .zero, size: size)
        container.layer?.mask = maskLayer
    }

    /// Update window shape dynamically (vector → vector)
    public func updateShape(_ shape: NSBezierPath) {
        guard let mask = contentView?.layer?.mask as? CAShapeLayer else { return }
        mask.path = shape.cgPath
        (contentView as? ShapedContentView)?.shapePath = shape.cgPath
    }

    /// Switch to a bitmap skin at runtime
    public func updateSkin(_ skin: SkinImage) {
        guard let container = contentView as? ShapedContentView else { return }

        // Clear vector state
        container.shapePath = nil

        // Set bitmap hit-testing data
        container.alphaData = skin.alphaData
        container.alphaWidth = skin.alphaWidth
        container.alphaHeight = skin.alphaHeight

        // Remove old skin background layer
        container.layer?.sublayers?.removeAll { $0.name == "skinBackground" }

        // Remove old mask
        container.layer?.mask = nil

        // Resize window
        let origin = frame.origin
        let newFrame = NSRect(origin: origin, size: skin.size)
        setFrame(newFrame, display: true)
        container.frame = NSRect(origin: .zero, size: skin.size)

        // Insert skin image as background layer at index 0
        let bgLayer = CALayer()
        bgLayer.name = "skinBackground"
        bgLayer.contents = skin.cgImage
        bgLayer.frame = CGRect(origin: .zero, size: skin.size)
        bgLayer.contentsGravity = .resizeAspect
        container.layer?.insertSublayer(bgLayer, at: 0)

        // Alpha mask
        let maskLayer = CALayer()
        maskLayer.contents = skin.cgImage
        maskLayer.frame = CGRect(origin: .zero, size: skin.size)
        container.layer?.mask = maskLayer
    }

    /// Switch to a vector shape at runtime (from skin or different vector)
    public func updateToVector(_ shape: NSBezierPath, size: NSSize) {
        guard let container = contentView as? ShapedContentView else { return }

        // Clear bitmap state
        container.alphaData = nil
        container.alphaWidth = 0
        container.alphaHeight = 0

        // Set vector hit-testing
        container.shapePath = shape.cgPath

        // Remove skin background layer
        container.layer?.sublayers?.removeAll { $0.name == "skinBackground" }

        // Resize window
        let origin = frame.origin
        let newFrame = NSRect(origin: origin, size: size)
        setFrame(newFrame, display: true)
        container.frame = NSRect(origin: .zero, size: size)

        // Set vector mask
        let mask = CAShapeLayer()
        mask.path = shape.cgPath
        container.layer?.mask = mask
    }

    // MARK: - Drag Bar

    override public func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && dragBarHeight > 0 {
            // Window coordinates: y=0 is bottom, y=frame.height is top
            let location = event.locationInWindow
            if location.y >= frame.height - dragBarHeight {
                // Check if an interactive control was hit — let it handle the event
                if let cv = contentView {
                    let local = cv.convert(location, from: nil)
                    if let hitView = cv.hitTest(local), Self.isInteractiveControl(hitView) {
                        super.sendEvent(event)
                        return
                    }
                }
                performDrag(with: event)
                return
            }
        }
        super.sendEvent(event)
    }

    private static func isInteractiveControl(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let v = current {
            if v is NSControl { return true }
            current = v.superview
        }
        return false
    }
}

// MARK: - Content View with Hit Testing

private class ShapedContentView: NSView {
    var shapePath: CGPath?
    var alphaData: Data?
    var alphaWidth: Int = 0
    var alphaHeight: Int = 0

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)

        // Bitmap hit testing (skin mode)
        if let alpha = alphaData, alphaWidth > 0, alphaHeight > 0 {
            let scaleX = CGFloat(alphaWidth) / bounds.width
            let scaleY = CGFloat(alphaHeight) / bounds.height
            let px = Int(local.x * scaleX)
            let py = Int(local.y * scaleY)
            guard px >= 0, px < alphaWidth, py >= 0, py < alphaHeight else { return nil }
            let idx = py * alphaWidth + px
            guard idx >= 0, idx < alpha.count, alpha[idx] > 25 else { return nil }
            return super.hitTest(point)
        }

        // Vector hit testing (shape mode)
        guard let path = shapePath, path.contains(local) else { return nil }
        return super.hitTest(point)
    }
}

// MARK: - NSBezierPath → CGPath

extension NSBezierPath {
    public var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for i in 0..<elementCount {
            let kind = element(at: i, associatedPoints: &points)
            switch kind {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            @unknown default:
                break
            }
        }
        return path
    }
}
