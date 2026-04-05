import CoreGraphics

enum OrganicSkins {
    static var all: [SkinSpec] {
        [blob, cloud, teardrop]
    }

    // MARK: - Blob — Warm coral/salmon gradient (lava lamp vibes)

    static let blobPalette = SkinPalette(
        fillTop: CGColor(red: 0.28, green: 0.10, blue: 0.12, alpha: 1.0),
        fillBottom: CGColor(red: 0.20, green: 0.06, blue: 0.10, alpha: 1.0),
        border: CGColor(red: 0.85, green: 0.35, blue: 0.30, alpha: 0.6),
        accent: CGColor(red: 0.95, green: 0.50, blue: 0.40, alpha: 0.3),
        shadow: CGColor(red: 0.80, green: 0.30, blue: 0.25, alpha: 0.35)
    )

    static var blob: SkinSpec {
        SkinSpec(name: "blob", width: 420, height: 540, category: "Organic") { ctx, w, h in
            let fw = CGFloat(w)
            let fh = CGFloat(h)
            let path = CGMutablePath()

            path.move(to: CGPoint(x: fw * 0.50, y: fh * 0.03))
            path.addCurve(
                to: CGPoint(x: fw * 0.92, y: fh * 0.18),
                control1: CGPoint(x: fw * 0.72, y: fh * 0.01),
                control2: CGPoint(x: fw * 0.88, y: fh * 0.06)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.96, y: fh * 0.52),
                control1: CGPoint(x: fw * 0.97, y: fh * 0.30),
                control2: CGPoint(x: fw * 0.99, y: fh * 0.42)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.85, y: fh * 0.88),
                control1: CGPoint(x: fw * 0.93, y: fh * 0.65),
                control2: CGPoint(x: fw * 0.94, y: fh * 0.78)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.45, y: fh * 0.97),
                control1: CGPoint(x: fw * 0.76, y: fh * 0.97),
                control2: CGPoint(x: fw * 0.60, y: fh * 0.99)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.08, y: fh * 0.78),
                control1: CGPoint(x: fw * 0.28, y: fh * 0.95),
                control2: CGPoint(x: fw * 0.10, y: fh * 0.92)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.04, y: fh * 0.40),
                control1: CGPoint(x: fw * 0.05, y: fh * 0.65),
                control2: CGPoint(x: fw * 0.01, y: fh * 0.52)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.50, y: fh * 0.03),
                control1: CGPoint(x: fw * 0.07, y: fh * 0.22),
                control2: CGPoint(x: fw * 0.25, y: fh * 0.05)
            )
            path.closeSubpath()

            SkinRenderer.addGlow(ctx, path: path, palette: blobPalette, radius: 6)
            SkinRenderer.fillAndStroke(ctx, path: path, palette: blobPalette)
        }
    }

    // MARK: - Cloud — Soft sky blue gradient (dreamy, airy)

    static let cloudPalette = SkinPalette(
        fillTop: CGColor(red: 0.75, green: 0.85, blue: 0.95, alpha: 1.0),
        fillBottom: CGColor(red: 0.60, green: 0.72, blue: 0.85, alpha: 1.0),
        border: CGColor(red: 0.50, green: 0.62, blue: 0.78, alpha: 0.6),
        accent: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.35),
        shadow: CGColor(red: 0.45, green: 0.55, blue: 0.70, alpha: 0.3)
    )

    static var cloud: SkinSpec {
        SkinSpec(name: "cloud", width: 480, height: 400, category: "Organic") { ctx, w, h in
            let fw = CGFloat(w)
            let fh = CGFloat(h)
            let path = CGMutablePath()

            path.move(to: CGPoint(x: fw * 0.10, y: fh * 0.88))
            path.addLine(to: CGPoint(x: fw * 0.90, y: fh * 0.88))

            path.addCurve(
                to: CGPoint(x: fw * 0.92, y: fh * 0.55),
                control1: CGPoint(x: fw * 0.97, y: fh * 0.85),
                control2: CGPoint(x: fw * 0.98, y: fh * 0.65)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.70, y: fh * 0.20),
                control1: CGPoint(x: fw * 0.88, y: fh * 0.38),
                control2: CGPoint(x: fw * 0.82, y: fh * 0.22)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.42, y: fh * 0.12),
                control1: CGPoint(x: fw * 0.62, y: fh * 0.08),
                control2: CGPoint(x: fw * 0.52, y: fh * 0.06)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.18, y: fh * 0.35),
                control1: CGPoint(x: fw * 0.30, y: fh * 0.14),
                control2: CGPoint(x: fw * 0.20, y: fh * 0.22)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.10, y: fh * 0.88),
                control1: CGPoint(x: fw * 0.08, y: fh * 0.48),
                control2: CGPoint(x: fw * 0.03, y: fh * 0.78)
            )
            path.closeSubpath()

            SkinRenderer.fillAndStroke(ctx, path: path, palette: cloudPalette, lineWidth: 1.5)

            // White highlight shimmer on top bumps
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.setStrokeColor(cloudPalette.accent)
            ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: fw * 0.30, y: fh * 0.18))
            ctx.addCurve(
                to: CGPoint(x: fw * 0.65, y: fh * 0.15),
                control1: CGPoint(x: fw * 0.42, y: fh * 0.08),
                control2: CGPoint(x: fw * 0.55, y: fh * 0.10)
            )
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    // MARK: - Teardrop — Deep teal to aqua gradient (water drop)

    static let teardropPalette = SkinPalette(
        fillTop: CGColor(red: 0.08, green: 0.22, blue: 0.25, alpha: 1.0),
        fillBottom: CGColor(red: 0.04, green: 0.15, blue: 0.20, alpha: 1.0),
        border: CGColor(red: 0.20, green: 0.60, blue: 0.65, alpha: 0.7),
        accent: CGColor(red: 0.40, green: 0.85, blue: 0.90, alpha: 0.3),
        shadow: CGColor(red: 0.15, green: 0.50, blue: 0.55, alpha: 0.4)
    )

    static var teardrop: SkinSpec {
        SkinSpec(name: "teardrop", width: 380, height: 560, category: "Organic") { ctx, w, h in
            let fw = CGFloat(w)
            let fh = CGFloat(h)
            let path = CGMutablePath()

            path.move(to: CGPoint(x: fw * 0.50, y: fh * 0.95))
            path.addCurve(
                to: CGPoint(x: fw * 0.92, y: fh * 0.35),
                control1: CGPoint(x: fw * 0.55, y: fh * 0.82),
                control2: CGPoint(x: fw * 0.92, y: fh * 0.58)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.08, y: fh * 0.35),
                control1: CGPoint(x: fw * 0.92, y: fh * 0.08),
                control2: CGPoint(x: fw * 0.08, y: fh * 0.08)
            )
            path.addCurve(
                to: CGPoint(x: fw * 0.50, y: fh * 0.95),
                control1: CGPoint(x: fw * 0.08, y: fh * 0.58),
                control2: CGPoint(x: fw * 0.45, y: fh * 0.82)
            )
            path.closeSubpath()

            SkinRenderer.addGlow(ctx, path: path, palette: teardropPalette, radius: 5)
            SkinRenderer.fillAndStroke(ctx, path: path, palette: teardropPalette)

            // Specular highlight on upper-left dome
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            let highlightPath = CGMutablePath()
            highlightPath.addEllipse(in: CGRect(x: fw * 0.22, y: fh * 0.12, width: fw * 0.20, height: fh * 0.15))
            ctx.addPath(highlightPath)
            ctx.setFillColor(CGColor(red: 0.40, green: 0.85, blue: 0.90, alpha: 0.10))
            ctx.fillPath()
            ctx.restoreGState()
        }
    }
}
