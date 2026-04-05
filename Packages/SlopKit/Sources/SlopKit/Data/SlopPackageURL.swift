import SwiftUI

private struct SlopPackageURLKey: EnvironmentKey {
    static let defaultValue: URL? = nil
}

extension EnvironmentValues {
    public var slopPackageURL: URL? {
        get { self[SlopPackageURLKey.self] }
        set { self[SlopPackageURLKey.self] = newValue }
    }
}
