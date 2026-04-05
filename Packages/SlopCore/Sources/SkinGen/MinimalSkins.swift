import CoreGraphics
import Foundation

enum MinimalSkins {
    static var all: [SkinSpec] {
        [pill, squircle, notchedRect]
    }

    // MARK: - Pill — Soft charcoal with lavender tint (matte, elegant)

    static let pillPalette = SkinPalette(
        fillTop: CGColor(red: 0.16, green: 0.15, blue: 0.20, alpha: 1.0),
        fillBottom: CGColor(red: 0.12, green: 0.11, blue: 0.16, alpha: 1.0),
        border: CGColor(red: 0.35, green: 0.32, blue: 0.45, alpha: 0.5),
        accent: CGColor(red: 0.55, green: 0.48, blue: 0.70, alpha: 0.2),
        shadow: CGColor(red: 0.30, green: 0.26, blue: 0.42, alpha: 0.3)
    )

    static var pill: SkinSpec {
        SkinSpec(name: "pill", width: 400, height: 600, category: "Minimal") { ctx, w, h in
            let fw = CGFloat(w)
            let fh = CGFloat(h)
            let inset: CGFloat = 4
            let r = CGRect(x: inset, y: inset, width: fw - inset * 2, height: fh - inset * 2)
            let radius = r.width / 2

            let path = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
            SkinRenderer.fillAndStroke(ctx, path: path, palette: pillPalette, lineWidth: 1.5)
        }
    }

    // MARK: - Squircle — Warm dark brown with orange accent (cozy, app-icon feel)

    static let squirclePalette = SkinPalette(
        fillTop: CGColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 1.0),
        fillBottom: CGColor(red: 0.13, green: 0.10, blue: 0.07, alpha: 1.0),
        border: CGColor(red: 0.45, green: 0.35, blue: 0.22, alpha: 0.6),
        accent: CGColor(red: 0.85, green: 0.55, blue: 0.20, alpha: 0.25),
        shadow: CGColor(red: 0.40, green: 0.28, blue: 0.15, alpha: 0.3)
    )

    static var squircle: SkinSpec {
        SkinSpec(name: "squircle", width: 400, height: 400, category: "Minimal") { ctx, w, h in
            let fw = CGFloat(w)
            let fh = CGFloat(h)
            let inset: CGFloat = 6
            let cx = fw / 2
            let cy = fh / 2
            let rx = cx - inset
            let ry = cy - inset
            let k: CGFloat = 0.92

            let path = CGMutablePath()
            path.move(to: CGPoint(x: cx + rx, y: cy))
            path.addCurve(
                to: CGPoint(x: cx, y: cy - ry),
                control1: CGPoint(x: cx + rx, y: cy - ry * k),
                control2: CGPoint(x: cx + rx * k, y: cy - ry)
            )
            path.addCurve(
                to: CGPoint(x: cx - rx, y: cy),
                control1: CGPoint(x: cx - rx * k, y: cy - ry),
                control2: CGPoint(x: cx - rx, y: cy - ry * k)
            )
            path.addCurve(
                to: CGPoint(x: cx, y: cy + ry),
                control1: CGPoint(x: cx - rx, y: cy + ry * k),
                control2: CGPoint(x: cx - rx * k, y: cy + ry)
            )
            path.addCurve(
                to: CGPoint(x: cx + rx, y: cy),
                control1: CGPoint(x: cx + rx * k, y: cy + ry),
                control2: CGPoint(x: cx + rx, y: cy + ry * k)
            )
            path.closeSubpath()

            SkinRenderer.fillAndStroke(ctx, path: path, palette: squirclePalette, lineWidth: 1.5)

            // Subtle inner glow/highlight
            let innerPath = CGMutablePath()
            let ir: CGFloat = 6
            let irx = rx - ir
            let iry = ry - ir
            innerPath.move(to: CGPoint(x: cx + irx, y: cy))
            innerPath.addCurve(
                to: CGPoint(x: cx, y: cy - iry),
                control1: CGPoint(x: cx + irx, y: cy - iry * k),
                control2: CGPoint(x: cx + irx * k, y: cy - iry)
            )
            innerPath.addCurve(
                to: CGPoint(x: cx - irx, y: cy),
                control1: CGPoint(x: cx - irx * k, y: cy - iry),
                control2: CGPoint(x: cx - irx, y: cy - iry * k)
            )
            innerPath.addCurve(
                to: CGPoint(x: cx, y: cy + iry),
                control1: CGPoint(x: cx - irx, y: cy + iry * k),
                control2: CGPoint(x: cx - irx * k, y: cy + iry)
            )
            innerPath.addCurve(
                to: CGPoint(x: cx + irx, y: cy),
                control1: CGPoint(x: cx + irx * k, y: cy + iry),
                control2: CGPoint(x: cx + irx, y: cy + iry * k)
            )
            innerPath.closeSubpath()

            SkinRenderer.innerHighlight(ctx, path: innerPath, color: squirclePalette.accent, lineWidth: 1.5)
        }
    }

    // MARK: - Notched Rect — Cool slate gray with icy blue notch accent (phone-like)

    static let notchedPalette = SkinPalette(
        fillTop: CGColor(red: 0.14, green: 0.16, blue: 0.19, alpha: 1.0),
        fillBottom: CGColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1.0),
        border: CGColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 0.6),
        accent: CGColor(red: 0.40, green: 0.65, blue: 0.90, alpha: 0.5),  // icy blue notch
        shadow: CGColor(red: 0.22, green: 0.26, blue: 0.32, alpha: 0.3)
    )

    static var notchedRect: SkinSpec {
        SkinSpec(name: "notched-rect", width: 420, height: 620, category: "Minimal") { ctx, w, h in
            let fw = CGFloat(w)
            let fh = CGFloat(h)
            let inset: CGFloat = 4
            let cornerRadius: CGFloat = 14
            let notchWidth: CGFloat = 120
            let notchHeight: CGFloat = 24
            let notchRadius: CGFloat = 10

            let r = CGRect(x: inset, y: inset, width: fw - inset * 2, height: fh - inset * 2)
            let notchLeft = r.midX - notchWidth / 2
            let notchRight = r.midX + notchWidth / 2

            let path = CGMutablePath()

            path.move(to: CGPoint(x: r.minX + cornerRadius, y: r.minY))
            path.addLine(to: CGPoint(x: notchLeft - notchRadius, y: r.minY))

            path.addArc(
                center: CGPoint(x: notchLeft - notchRadius, y: r.minY + notchRadius),
                radius: notchRadius, startAngle: -.pi / 2, endAngle: 0, clockwise: false
            )
            path.addLine(to: CGPoint(x: notchLeft, y: r.minY + notchHeight - notchRadius))
            path.addArc(
                center: CGPoint(x: notchLeft + notchRadius, y: r.minY + notchHeight - notchRadius),
                radius: notchRadius, startAngle: .pi, endAngle: .pi / 2, clockwise: true
            )
            path.addLine(to: CGPoint(x: notchRight - notchRadius, y: r.minY + notchHeight))
            path.addArc(
                center: CGPoint(x: notchRight - notchRadius, y: r.minY + notchHeight - notchRadius),
                radius: notchRadius, startAngle: .pi / 2, endAngle: 0, clockwise: true
            )
            path.addLine(to: CGPoint(x: notchRight, y: r.minY + notchRadius))
            path.addArc(
                center: CGPoint(x: notchRight + notchRadius, y: r.minY + notchRadius),
                radius: notchRadius, startAngle: .pi, endAngle: -.pi / 2, clockwise: false
            )

            path.addLine(to: CGPoint(x: r.maxX - cornerRadius, y: r.minY))
            path.addArc(center: CGPoint(x: r.maxX - cornerRadius, y: r.minY + cornerRadius),
                        radius: cornerRadius, startAngle: -.pi / 2, endAngle: 0, clockwise: false)
            path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cornerRadius))
            path.addArc(center: CGPoint(x: r.maxX - cornerRadius, y: r.maxY - cornerRadius),
                        radius: cornerRadius, startAngle: 0, endAngle: .pi / 2, clockwise: false)
            path.addLine(to: CGPoint(x: r.minX + cornerRadius, y: r.maxY))
            path.addArc(center: CGPoint(x: r.minX + cornerRadius, y: r.maxY - cornerRadius),
                        radius: cornerRadius, startAngle: .pi / 2, endAngle: .pi, clockwise: false)
            path.addLine(to: CGPoint(x: r.minX, y: r.minY + cornerRadius))
            path.addArc(center: CGPoint(x: r.minX + cornerRadius, y: r.minY + cornerRadius),
                        radius: cornerRadius, startAngle: .pi, endAngle: -.pi / 2, clockwise: false)
            path.closeSubpath()

            SkinRenderer.fillAndStroke(ctx, path: path, palette: notchedPalette, lineWidth: 1.5)

            // Blue accent glow inside the notch
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.setFillColor(notchedPalette.accent)
            let notchGlowRect = CGRect(
                x: notchLeft + notchRadius,
                y: r.minY + 2,
                width: notchWidth - notchRadius * 2,
                height: notchHeight - 4
            )
            ctx.fillEllipse(in: notchGlowRect.insetBy(dx: 10, dy: 2))
            ctx.restoreGState()

            // Tiny camera dot in notch
            ctx.setFillColor(CGColor(red: 0.20, green: 0.22, blue: 0.28, alpha: 1.0))
            ctx.fillEllipse(in: CGRect(x: r.midX - 3, y: r.minY + notchHeight / 2 - 3, width: 6, height: 6))
            ctx.setStrokeColor(notchedPalette.accent)
            ctx.setLineWidth(0.5)
            ctx.strokeEllipse(in: CGRect(x: r.midX - 3, y: r.minY + notchHeight / 2 - 3, width: 6, height: 6))
        }
    }
}
