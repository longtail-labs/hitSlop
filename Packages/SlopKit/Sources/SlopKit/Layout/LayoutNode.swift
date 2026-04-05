import Foundation

/// Declarative view tree returned by scripted templates.
/// The host renders each node as the equivalent SwiftUI view.
public indirect enum LayoutNode: Sendable {
    // MARK: - Layout

    case vstack(spacing: CGFloat, children: [LayoutNode])
    case hstack(spacing: CGFloat, children: [LayoutNode])
    case zstack(children: [LayoutNode])
    case scrollView(axes: ScrollAxes, child: LayoutNode)
    case padding(EdgeSet, CGFloat, child: LayoutNode)
    case frame(width: CGFloat?, height: CGFloat?, alignment: FrameAlignment?, child: LayoutNode)
    case background(color: String, cornerRadius: CGFloat, child: LayoutNode)
    case exportVisibility(ExportVisibility, child: LayoutNode)

    // MARK: - Display

    case text(String, TextStyle)
    case image(systemName: String, size: CGFloat?, color: String?)
    case divider
    case spacer(minLength: CGFloat?)
    case progressBar(value: Double, total: Double, color: String?)
    case colorDot(hex: String, size: CGFloat)

    // MARK: - Input

    case textField(fieldKey: String, placeholder: String)
    case numberField(fieldKey: String)
    case toggle(fieldKey: String, label: String)
    case picker(fieldKey: String, options: [(value: String, label: String)])
    case slider(fieldKey: String, range: ClosedRange<Double>, step: Double?)
    case button(label: String, action: String, style: ButtonVariant?)

    // MARK: - Data

    case forEach(arrayFieldKey: String, itemBuilder: @Sendable ([String: FieldValue], Int) -> LayoutNode)
    case conditional(predicate: Bool, then: LayoutNode, otherwise: LayoutNode?)

    // MARK: - Empty

    case empty

    // MARK: - Supporting Types

    public enum ScrollAxes: Sendable {
        case vertical, horizontal, both
    }

    public enum EdgeSet: Sendable {
        case all, horizontal, vertical, top, bottom, leading, trailing
    }

    public enum FrameAlignment: String, Sendable {
        case center, leading, trailing, top, bottom
        case topLeading, topTrailing, bottomLeading, bottomTrailing
    }

    public enum ButtonVariant: String, Sendable {
        case `default`, bordered, borderedProminent, plain
    }

    public enum ExportVisibility: Sendable {
        case hideInExport
        case onlyInExport
    }
}
