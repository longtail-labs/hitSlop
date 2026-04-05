import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct SkinSpec {
    let name: String
    let width: Int
    let height: Int
    let category: String
    let render: (CGContext, Int, Int) -> Void
}

/// Palette for a single skin — fill gradient, border, accent details.
struct SkinPalette {
    let fillTop: CGColor
    let fillBottom: CGColor
    let border: CGColor
    let accent: CGColor      // inner details, highlights, decorations
    let shadow: CGColor       // subtle shadow/glow tint

    static func solid(_ fill: CGColor, border: CGColor, accent: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.15), shadow: CGColor? = nil) -> SkinPalette {
        SkinPalette(fillTop: fill, fillBottom: fill, border: border, accent: accent, shadow: shadow ?? border)
    }
}

enum SkinRenderer {
    static func createContext(width: Int, height: Int) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    static func writePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            print("Failed to create image destination for \(url.lastPathComponent)")
            return
        }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    static func generateAll(to outputDir: URL) {
        let specs: [SkinSpec] =
            GeometricSkins.all + OrganicSkins.all + RetroSkins.all + MinimalSkins.all

        let fm = FileManager.default
        try? fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

        for spec in specs {
            guard let ctx = createContext(width: spec.width, height: spec.height) else {
                print("Failed to create context for \(spec.name)")
                continue
            }
            ctx.clear(CGRect(x: 0, y: 0, width: spec.width, height: spec.height))
            spec.render(ctx, spec.width, spec.height)

            guard let image = ctx.makeImage() else {
                print("Failed to make image for \(spec.name)")
                continue
            }

            let url = outputDir.appendingPathComponent("\(spec.name).png")
            writePNG(image, to: url)
            print("Generated \(spec.name).png (\(spec.width)x\(spec.height))")
        }
    }

    // MARK: - Gradient Fill

    /// Fill a path with a vertical linear gradient using the palette.
    static func gradientFill(_ ctx: CGContext, path: CGPath, palette: SkinPalette) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bounds = path.boundingBox
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [palette.fillTop, palette.fillBottom] as CFArray,
            locations: [0.0, 1.0]
        ) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: bounds.midX, y: bounds.minY),
                end: CGPoint(x: bounds.midX, y: bounds.maxY),
                options: []
            )
        }
        ctx.restoreGState()
    }

    /// Fill path with gradient, then stroke border.
    static func fillAndStroke(_ ctx: CGContext, path: CGPath, palette: SkinPalette, lineWidth: CGFloat = 2) {
        gradientFill(ctx, path: path, palette: palette)

        ctx.addPath(path)
        ctx.setStrokeColor(palette.border)
        ctx.setLineWidth(lineWidth)
        ctx.strokePath()
    }

    /// Add an outer glow effect using the palette shadow color.
    static func addGlow(_ ctx: CGContext, path: CGPath, palette: SkinPalette, radius: CGFloat = 4) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setShadow(offset: .zero, blur: radius, color: palette.shadow)
        ctx.setStrokeColor(palette.shadow)
        ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Draw a subtle inner highlight stroke offset from the main path.
    static func innerHighlight(_ ctx: CGContext, path: CGPath, color: CGColor, lineWidth: CGFloat = 1) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(lineWidth)
        ctx.strokePath()
        ctx.restoreGState()
    }
}
