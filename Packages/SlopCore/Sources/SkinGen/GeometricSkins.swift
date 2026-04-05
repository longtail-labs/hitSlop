import CoreGraphics

enum GeometricSkins {
    static var all: [SkinSpec] {
        [chamferedRect, hexagon, diamond]
    }

    // MARK: - Chamfered Rect — Midnight blue with cyan glow (sci-fi HUD feel)

    static let chamferedPalette = SkinPalette(
        fillTop: CGColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0),
        fillBottom: CGColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1.0),
        border: CGColor(red: 0.20, green: 0.55, blue: 0.80, alpha: 0.7),
        accent: CGColor(red: 0.30, green: 0.70, blue: 0.95, alpha: 0.4),
        shadow: CGColor(red: 0.20, green: 0.60, blue: 0.90, alpha: 0.5)
    )

    static var chamferedRect: SkinSpec {
        SkinSpec(name: "chamfered-rect", width: 420, height: 620, category: "Geometric") { ctx, w, h in
            let inset: CGFloat = 6
            let chamfer: CGFloat = 28
            let path = CGMutablePath()
            let r = CGRect(x: inset, y: inset, width: CGFloat(w) - inset * 2, height: CGFloat(h) - inset * 2)

            path.move(to: CGPoint(x: r.minX + chamfer, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX - chamfer, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.minY + chamfer))
            path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - chamfer))
            path.addLine(to: CGPoint(x: r.maxX - chamfer, y: r.maxY))
            path.addLine(to: CGPoint(x: r.minX + chamfer, y: r.maxY))
            path.addLine(to: CGPoint(x: r.minX, y: r.maxY - chamfer))
            path.addLine(to: CGPoint(x: r.minX, y: r.minY + chamfer))
            path.closeSubpath()

            SkinRenderer.addGlow(ctx, path: path, palette: chamferedPalette, radius: 8)
            SkinRenderer.fillAndStroke(ctx, path: path, palette: chamferedPalette)

            // Corner accent marks — small cyan lines at each chamfer
            ctx.setStrokeColor(chamferedPalette.accent)
            ctx.setLineWidth(1.5)
            let markLen: CGFloat = 10
            // Top-left chamfer accent
            ctx.move(to: CGPoint(x: r.minX + chamfer * 0.3, y: r.minY + chamfer * 0.7))
            ctx.addLine(to: CGPoint(x: r.minX + chamfer * 0.3 + markLen, y: r.minY + chamfer * 0.7 - markLen))
            // Top-right
            ctx.move(to: CGPoint(x: r.maxX - chamfer * 0.3, y: r.minY + chamfer * 0.7))
            ctx.addLine(to: CGPoint(x: r.maxX - chamfer * 0.3 - markLen, y: r.minY + chamfer * 0.7 - markLen))
            ctx.strokePath()
        }
    }

    // MARK: - Hexagon — Deep purple with magenta bevel (crystal/gem feel)

    static let hexPalette = SkinPalette(
        fillTop: CGColor(red: 0.18, green: 0.08, blue: 0.25, alpha: 1.0),
        fillBottom: CGColor(red: 0.10, green: 0.04, blue: 0.18, alpha: 1.0),
        border: CGColor(red: 0.55, green: 0.25, blue: 0.70, alpha: 0.8),
        accent: CGColor(red: 0.75, green: 0.40, blue: 0.90, alpha: 0.4),
        shadow: CGColor(red: 0.50, green: 0.20, blue: 0.65, alpha: 0.4)
    )

    static var hexagon: SkinSpec {
        SkinSpec(name: "hexagon", width: 440, height: 500, category: "Geometric") { ctx, w, h in
            let inset: CGFloat = 8
            let cx = CGFloat(w) / 2
            let cy = CGFloat(h) / 2
            let rx = cx - inset
            let ry = cy - inset

            let path = CGMutablePath()
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3 - .pi / 6
                let x = cx + rx * cos(angle)
                let y = cy + ry * sin(angle)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()

            SkinRenderer.fillAndStroke(ctx, path: path, palette: hexPalette)

            // Inner bevel ring
            let bevelPath = CGMutablePath()
            let bevelInset: CGFloat = 5
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3 - .pi / 6
                let x = cx + (rx - bevelInset) * cos(angle)
                let y = cy + (ry - bevelInset) * sin(angle)
                if i == 0 {
                    bevelPath.move(to: CGPoint(x: x, y: y))
                } else {
                    bevelPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            bevelPath.closeSubpath()

            SkinRenderer.innerHighlight(ctx, path: bevelPath, color: hexPalette.accent, lineWidth: 1)
        }
    }

    // MARK: - Diamond — Dark emerald green with gold 3D edge (jewel feel)

    static let diamondPalette = SkinPalette(
        fillTop: CGColor(red: 0.06, green: 0.18, blue: 0.12, alpha: 1.0),
        fillBottom: CGColor(red: 0.03, green: 0.12, blue: 0.08, alpha: 1.0),
        border: CGColor(red: 0.20, green: 0.50, blue: 0.30, alpha: 0.8),
        accent: CGColor(red: 0.75, green: 0.65, blue: 0.30, alpha: 0.6),  // gold highlight
        shadow: CGColor(red: 0.15, green: 0.40, blue: 0.25, alpha: 0.4)
    )

    static var diamond: SkinSpec {
        SkinSpec(name: "diamond", width: 460, height: 460, category: "Geometric") { ctx, w, h in
            let inset: CGFloat = 10
            let cx = CGFloat(w) / 2
            let cy = CGFloat(h) / 2
            let halfW = cx - inset
            let halfH = cy - inset

            let path = CGMutablePath()
            path.move(to: CGPoint(x: cx, y: inset))
            path.addLine(to: CGPoint(x: cx + halfW, y: cy))
            path.addLine(to: CGPoint(x: cx, y: cy + halfH))
            path.addLine(to: CGPoint(x: cx - halfW, y: cy))
            path.closeSubpath()

            SkinRenderer.fillAndStroke(ctx, path: path, palette: diamondPalette)

            // Gold 3D edge — lighter top-left edges
            ctx.saveGState()
            ctx.setStrokeColor(diamondPalette.accent)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: cx - halfW + 5, y: cy))
            ctx.addLine(to: CGPoint(x: cx, y: inset + 5))
            ctx.addLine(to: CGPoint(x: cx + halfW - 5, y: cy))
            ctx.strokePath()
            ctx.restoreGState()
        }
    }
}
