import QuickLookThumbnailing
import AppKit
import SlopUI

final class ThumbnailProvider: QLThumbnailProvider {

    private static let themesDir = SlopSharedContainer.themesDir

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, (any Error)?) -> Void
    ) {
        let fileURL = request.fileURL

        let maxSize = request.maximumSize

        if let previewURL = SlopPreviewAssetResolver.resolvePreviewURL(for: fileURL) {
            handler(QLThumbnailReply(imageFileURL: previewURL), nil)
            return
        }

        guard let envelope = try? SlopFile.loadEnvelope(from: fileURL)
        else {
            handler(nil, nil)
            return
        }

        // Resolve theme background color
        let themeColors = Self.loadThemeColors(named: envelope.theme)
        let bgColor = themeColors?.background ?? CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)

        // Fallback: card with template name
        let templateName = envelope.templateID.components(separatedBy: ".").last ?? envelope.templateID

        let reply = QLThumbnailReply(contextSize: maxSize) { context in
            let side = min(maxSize.width, maxSize.height)
            let cardW = side * 0.8
            let cardH = side * 0.8
            let cardX = (maxSize.width - cardW) / 2
            let cardY = (maxSize.height - cardH) / 2
            let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)
            let cornerRadius: CGFloat = 4

            let path = CGPath(
                roundedRect: cardRect,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
            context.setFillColor(bgColor)
            context.addPath(path)
            context.fillPath()

            let fontSize = side * 0.08
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: fontSize, weight: .medium)
            ]
            let label = NSAttributedString(string: templateName, attributes: attrs)
            let labelSize = label.size()
            let labelOrigin = CGPoint(
                x: (maxSize.width - labelSize.width) / 2,
                y: (maxSize.height - labelSize.height) / 2
            )
            label.draw(at: labelOrigin)

            return true
        }
        handler(reply, nil)
    }

    // MARK: - Theme Loading

    private static func loadThemeColors(named themeName: String?) -> ThemeColors? {
        guard let name = themeName else { return nil }
        let themeURL = themesDir.appendingPathComponent("\(name).theme")
        guard let data = try? Data(contentsOf: themeURL),
              let dict = try? JSONDecoder().decode(ThemeColorFile.self, from: data)
        else { return nil }
        return ThemeColors(
            background: Self.cgColor(hex: dict.background) ?? CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
        )
    }

    private static func cgColor(hex: String?) -> CGColor? {
        guard var hex = hex else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let val = UInt64(hex, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xFF) / 255
        let g = CGFloat((val >> 8) & 0xFF) / 255
        let b = CGFloat(val & 0xFF) / 255
        return CGColor(red: r, green: g, blue: b, alpha: 1)
    }
}

private struct ThemeColorFile: Decodable {
    let background: String?
}

private struct ThemeColors {
    let background: CGColor
}
