import SwiftUI

/// Wraps content in a `ScrollView` for interactive mode, plain layout for export.
///
/// Replaces the common pattern:
/// ```swift
/// // Before:
/// if renderTarget == .interactive {
///     ScrollView { content }
/// } else {
///     content
/// }
///
/// // After:
/// SlopContent { content }
/// ```
public struct SlopContent<Content: View>: View {
    private let content: Content

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if renderTarget == .interactive {
            ScrollView(showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content
        }
    }
}

/// Shows content only in interactive mode. Hidden during export.
///
/// Wrapper equivalent of `.slopHiddenInExport()` for use in result builder context:
/// ```swift
/// SlopInteractiveOnly {
///     Button("Add Item") { ... }
/// }
/// ```
public struct SlopInteractiveOnly<Content: View>: View {
    private let content: Content

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if renderTarget == .interactive {
            content
        }
    }
}
