import SwiftUI

// MARK: - Canvas Item Protocol

/// Protocol for items that can be placed on a SlopCanvas.
public protocol CanvasPositionable: Identifiable {
    var x: Double { get set }
    var y: Double { get set }
    var width: Double { get }
    var height: Double { get }
}

// MARK: - Viewport

/// Persistent viewport state for a canvas (pan offset + zoom level).
@SlopData
public struct CanvasViewport {
    @Field("X") public var x: Double = 0
    @Field("Y") public var y: Double = 0
    @Field("Zoom") public var zoom: Double = 1.0
}

// MARK: - SlopCanvas

/// Reusable infinite canvas with pan, zoom, and draggable nodes.
///
/// Gestures are jitter-free: transient offsets live in `@State` during interaction
/// and commit to `@Binding` only on gesture end, avoiding persistence round-trips.
public struct SlopCanvas<Item: CanvasPositionable, NodeContent: View>: View {
    @Binding var items: [Item]
    @Binding var viewport: CanvasViewport

    let gridSpacing: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onDoubleTap: ((CGPoint) -> Void)?
    @ViewBuilder let nodeContent: (Binding<Item>) -> NodeContent

    // Transient gesture state — local only, never persisted
    @State private var panOffset: CGSize = .zero
    @State private var zoomDelta: CGFloat = 1.0
    @State private var dragItemID: Item.ID?
    @State private var dragOffset: CGSize = .zero

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(
        items: Binding<[Item]>,
        viewport: Binding<CanvasViewport>,
        gridSpacing: CGFloat = 30,
        minZoom: CGFloat = 0.2,
        maxZoom: CGFloat = 3.0,
        onDoubleTap: ((CGPoint) -> Void)? = nil,
        @ViewBuilder nodeContent: @escaping (Binding<Item>) -> NodeContent
    ) {
        self._items = items
        self._viewport = viewport
        self.gridSpacing = gridSpacing
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.onDoubleTap = onDoubleTap
        self.nodeContent = nodeContent
    }

    public var body: some View {
        // NOTE: Interactive vs Export layout intentionally differs:
        // - Interactive: Free-form infinite canvas with pan/zoom and dot grid
        // - Export: 3-column grid layout for clean print output
        // This is by design to ensure export produces predictable, printable results
        // regardless of the viewport state in interactive mode.
        if renderTarget == .interactive {
            interactiveCanvas
        } else {
            exportLayout
        }
    }

    // MARK: - Interactive Canvas

    private var interactiveCanvas: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let zoom = effectiveZoom
            let center = effectiveCenter(in: size)

            ZStack {
                // Background — tappable, draggable surface
                dotGrid(zoom: zoom, center: center)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { location in
                        onDoubleTap?(viewToWorld(location, in: size))
                    }
                    .gesture(panGesture(in: size))
                    .simultaneousGesture(magnifyGesture(in: size))
                    .overlay {
                        ScrollWheelOverlay { dx, dy in
                            viewport.x -= dx / effectiveZoom
                            viewport.y -= dy / effectiveZoom
                        }
                    }

                // Nodes
                ForEach(items) { item in
                    if let binding = itemBinding(for: item.id) {
                        let pos = nodeViewPosition(for: item, zoom: zoom, center: center, in: size)
                        let isDragging = dragItemID == item.id

                        nodeContent(binding)
                            .frame(width: item.width, height: item.height)
                            .scaleEffect(zoom, anchor: .center)
                            .frame(width: item.width * zoom, height: item.height * zoom)
                            .contentShape(Rectangle())
                            .shadow(
                                color: .black.opacity(isDragging ? 0.15 : 0),
                                radius: isDragging ? 8 : 0,
                                y: isDragging ? 4 : 0
                            )
                            .position(x: pos.x, y: pos.y)
                            .gesture(nodeDragGesture(for: item.id, zoom: zoom))
                    }
                }
            }
            .clipped()
        }
    }

    // MARK: - Dot Grid

    @ViewBuilder
    private func dotGrid(zoom: CGFloat, center: CGPoint) -> some View {
        Canvas { context, canvasSize in
            let dotAlpha = min(1.0, zoom * 0.8)
            guard dotAlpha > 0.05 else { return }

            let gridStep = gridSpacing * zoom
            guard gridStep > 4 else { return }

            let dotSize: CGFloat = max(1, 1.5 * zoom)
            let color = Color.gray.opacity(0.15 * dotAlpha)

            let halfW = canvasSize.width / (2 * zoom)
            let halfH = canvasSize.height / (2 * zoom)

            let startX = ((center.x - halfW) / gridSpacing).rounded(.down) * gridSpacing
            let startY = ((center.y - halfH) / gridSpacing).rounded(.down) * gridSpacing
            let endX = center.x + halfW
            let endY = center.y + halfH

            guard endX > startX, endY > startY else { return }

            var dotCount = 0
            var wx = startX
            while wx <= endX, dotCount < 10_000 {
                var wy = startY
                while wy <= endY, dotCount < 10_000 {
                    let vx = (wx - center.x) * zoom + canvasSize.width / 2
                    let vy = (wy - center.y) * zoom + canvasSize.height / 2
                    let rect = CGRect(
                        x: vx - dotSize / 2,
                        y: vy - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    wy += gridSpacing
                    dotCount += 1
                }
                wx += gridSpacing
            }
        }
    }

    // MARK: - Export Layout
    //
    // Exports nodes in a 3-column grid rather than preserving interactive positions.
    // This ensures:
    // - Predictable layout for printing/PDF export
    // - No dependency on viewport state (pan/zoom)
    // - Consistent spacing and alignment for printed output
    //
    // If you need to preserve exact positions in export, create a custom canvas
    // component that uses the same positioning logic in both modes.
    private var exportLayout: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items) { item in
                if let binding = itemBinding(for: item.id) {
                    nodeContent(binding)
                        .frame(width: item.width, height: item.height)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Transform

    private var effectiveZoom: CGFloat {
        clamp(viewport.zoom * zoomDelta)
    }

    private func effectiveCenter(in size: CGSize) -> CGPoint {
        CGPoint(
            x: viewport.x - panOffset.width / effectiveZoom,
            y: viewport.y - panOffset.height / effectiveZoom
        )
    }

    private func worldToView(_ world: CGPoint, in size: CGSize) -> CGPoint {
        let center = effectiveCenter(in: size)
        return CGPoint(
            x: (world.x - center.x) * effectiveZoom + size.width / 2,
            y: (world.y - center.y) * effectiveZoom + size.height / 2
        )
    }

    private func viewToWorld(_ view: CGPoint, in size: CGSize) -> CGPoint {
        let center = effectiveCenter(in: size)
        return CGPoint(
            x: center.x + (view.x - size.width / 2) / effectiveZoom,
            y: center.y + (view.y - size.height / 2) / effectiveZoom
        )
    }

    private func nodeViewPosition(
        for item: Item,
        zoom: CGFloat,
        center: CGPoint,
        in size: CGSize
    ) -> CGPoint {
        let worldCenter = CGPoint(
            x: item.x + item.width / 2,
            y: item.y + item.height / 2
        )
        var pos = CGPoint(
            x: (worldCenter.x - center.x) * zoom + size.width / 2,
            y: (worldCenter.y - center.y) * zoom + size.height / 2
        )

        if dragItemID == item.id {
            pos.x += dragOffset.width
            pos.y += dragOffset.height
        }

        return pos
    }

    // MARK: - Gestures

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                panOffset = value.translation
            }
            .onEnded { _ in
                let center = effectiveCenter(in: size)
                viewport.x = center.x
                viewport.y = center.y
                panOffset = .zero
            }
    }

    private func magnifyGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomDelta = value.magnification
            }
            .onEnded { _ in
                viewport.zoom = effectiveZoom
                zoomDelta = 1.0
            }
    }

    private func nodeDragGesture(for id: Item.ID, zoom: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                dragItemID = id
                dragOffset = value.translation
            }
            .onEnded { value in
                if let idx = items.firstIndex(where: { $0.id == id }) {
                    items[idx].x += value.translation.width / zoom
                    items[idx].y += value.translation.height / zoom
                }
                dragItemID = nil
                dragOffset = .zero
            }
    }

    // MARK: - Helpers

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(maxZoom, max(minZoom, value))
    }

    private func itemBinding(for id: Item.ID) -> Binding<Item>? {
        guard items.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: {
                items.first(where: { $0.id == id }) ?? items[0]
            },
            set: { newValue in
                if let idx = items.firstIndex(where: { $0.id == id }) {
                    items[idx] = newValue
                }
            }
        )
    }
}

// MARK: - Scroll Wheel (Two-Finger Trackpad Panning)

#if canImport(AppKit)
private struct ScrollWheelOverlay: NSViewRepresentable {
    let onScroll: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ScrollCaptureView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ScrollCaptureView)?.onScroll = onScroll
    }

    private class ScrollCaptureView: NSView {
        var onScroll: ((CGFloat, CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
        }

        // Forward pinch-to-zoom so SwiftUI's MagnifyGesture still works
        override func magnify(with event: NSEvent) {
            nextResponder?.magnify(with: event)
        }

        override func smartMagnify(with event: NSEvent) {
            nextResponder?.smartMagnify(with: event)
        }
    }
}
#endif
