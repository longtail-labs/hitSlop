import SwiftUI

public enum SlopRenderTarget: Sendable {
    case interactive
    case pdfExport
    case imageExport
}

private struct SlopRenderTargetKey: EnvironmentKey {
    static let defaultValue: SlopRenderTarget = .interactive
}

extension EnvironmentValues {
    public var slopRenderTarget: SlopRenderTarget {
        get { self[SlopRenderTargetKey.self] }
        set { self[SlopRenderTargetKey.self] = newValue }
    }
}
