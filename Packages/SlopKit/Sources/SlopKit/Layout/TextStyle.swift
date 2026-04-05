import Foundation

/// Styling options for text layout nodes.
public struct TextStyle: Sendable, Hashable {
    public var font: FontStyle?
    public var weight: FontWeight?
    public var color: String?
    public var alignment: TextAlignment?
    public var lineLimit: Int?

    public init(
        font: FontStyle? = nil,
        weight: FontWeight? = nil,
        color: String? = nil,
        alignment: TextAlignment? = nil,
        lineLimit: Int? = nil
    ) {
        self.font = font
        self.weight = weight
        self.color = color
        self.alignment = alignment
        self.lineLimit = lineLimit
    }

    public enum FontStyle: String, Sendable, Hashable {
        case largeTitle, title, title2, title3
        case headline, subheadline
        case body, callout, footnote, caption, caption2
    }

    public enum FontWeight: String, Sendable, Hashable {
        case ultraLight, thin, light, regular, medium
        case semibold, bold, heavy, black
    }

    public enum TextAlignment: String, Sendable, Hashable {
        case leading, center, trailing
    }
}
