import Foundation

/// Window shape for template rendering.
public enum WindowShape: Codable, Sendable, Hashable {
    case roundedRect(radius: CGFloat)
    case circle
    case capsule
    case path(String)       // SVG-like path data for arbitrary shapes
    case skin(String)       // Filename in bundle Resources (e.g. "skin.png")

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    private enum ShapeType: String, Codable {
        case roundedRect, circle, capsule, path, skin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ShapeType.self, forKey: .type)
        switch type {
        case .roundedRect:
            let radius = try container.decode(CGFloat.self, forKey: .value)
            self = .roundedRect(radius: radius)
        case .circle:
            self = .circle
        case .capsule:
            self = .capsule
        case .path:
            self = .path(try container.decode(String.self, forKey: .value))
        case .skin:
            self = .skin(try container.decode(String.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .roundedRect(let radius):
            try container.encode(ShapeType.roundedRect, forKey: .type)
            try container.encode(radius, forKey: .value)
        case .circle:
            try container.encode(ShapeType.circle, forKey: .type)
        case .capsule:
            try container.encode(ShapeType.capsule, forKey: .type)
        case .path(let data):
            try container.encode(ShapeType.path, forKey: .type)
            try container.encode(data, forKey: .value)
        case .skin(let filename):
            try container.encode(ShapeType.skin, forKey: .type)
            try container.encode(filename, forKey: .value)
        }
    }
}

/// Metadata describing the template's window appearance.
/// Templates define this statically; the host reads it to configure the window chrome.
public struct TemplateMetadata: Codable, Sendable, Hashable {
    public let width: CGFloat
    public let height: CGFloat
    public let minSize: CGSize?
    public let windowShape: WindowShape
    public let theme: String?
    public let alwaysOnTop: Bool
    public let titleBarHidden: Bool
    public let categories: [String]

    public init(
        width: CGFloat = 400,
        height: CGFloat = 600,
        minSize: CGSize? = nil,
        windowShape: WindowShape = .roundedRect(radius: 16),
        theme: String? = nil,
        alwaysOnTop: Bool = true,
        titleBarHidden: Bool = true,
        categories: [String] = []
    ) {
        self.width = width
        self.height = height
        self.minSize = minSize
        self.windowShape = windowShape
        self.theme = theme
        self.alwaysOnTop = alwaysOnTop
        self.titleBarHidden = titleBarHidden
        self.categories = categories
    }
}
