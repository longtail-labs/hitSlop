import SwiftUI

private enum SlopExportVisibilityMode {
    case hideInExport
    case onlyInExport
}

private struct SlopExportVisibilityModifier: ViewModifier {
    let mode: SlopExportVisibilityMode

    @Environment(\.slopRenderTarget) private var renderTarget

    private var isExport: Bool {
        renderTarget != .interactive
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch mode {
        case .hideInExport:
            if isExport {
                EmptyView()
            } else {
                content
            }
        case .onlyInExport:
            if isExport {
                content
            } else {
                EmptyView()
            }
        }
    }
}

public extension View {
    func slopHiddenInExport() -> some View {
        modifier(SlopExportVisibilityModifier(mode: .hideInExport))
    }

    func slopOnlyInExport() -> some View {
        modifier(SlopExportVisibilityModifier(mode: .onlyInExport))
    }
}

// MARK: - Exportable Frame

/// Applies frame constraints only in interactive mode.
/// In export mode, content is unconstrained to allow proper measurement.
///
/// This resolves the conflict between `fixedSize(vertical: true)` used during
/// measurement and `.frame(maxHeight: .infinity)` which requests infinite space.
///
/// ```swift
/// VStack {
///     header
///     content
///         .exportableFrame(maxHeight: .infinity)  // Expands in interactive, natural height in export
///     footer
/// }
/// ```
public extension View {
    /// Applies frame constraints only in interactive mode.
    /// During export, no frame constraints are applied, allowing natural content sizing.
    ///
    /// - Parameters:
    ///  - maxWidth: Maximum width constraint (applied only in interactive mode)
    ///  - maxHeight: Maximum height constraint (applied only in interactive mode)
    ///  - alignment: Alignment within the frame
    func slopExportableFrame(
        maxWidth: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {
        modifier(SlopExportableFrameModifier(maxWidth: maxWidth, maxHeight: maxHeight, alignment: alignment))
    }
}

private struct SlopExportableFrameModifier: ViewModifier {
    let maxWidth: CGFloat?
    let maxHeight: CGFloat?
    let alignment: Alignment

    @Environment(\.slopRenderTarget) private var renderTarget

    func body(content: Content) -> some View {
        if renderTarget == .interactive {
            content.frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: alignment)
        } else {
            content
        }
    }
}
