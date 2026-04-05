import AppKit

/// Known external editors that can open .slop files.
public enum ExternalEditor: String, CaseIterable, Sendable {
    case vscode = "Visual Studio Code"
    case cursor = "Cursor"
    case warp = "Warp"
    case iterm = "iTerm"
    case finder = "Finder"

    public var bundleID: String {
        switch self {
        case .vscode: return "com.microsoft.VSCode"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .warp: return "dev.warp.Warp-Stable"
        case .iterm: return "com.googlecode.iterm2"
        case .finder: return "com.apple.finder"
        }
    }

    /// Whether this editor is a terminal that should open to the .slop directory.
    public var isTerminal: Bool {
        switch self {
        case .warp, .iterm: return true
        default: return false
        }
    }

    /// Only show editors that are installed on this machine.
    public static var available: [ExternalEditor] {
        allCases.filter { editor in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: editor.bundleID) != nil
        }
    }
}
