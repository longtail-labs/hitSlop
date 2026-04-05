import CoreGraphics

enum RetroSkins {
    static var all: [SkinSpec] {
        [notebook, stickyNote, ticketStub]
    }

    // MARK: - Notebook — Warm cream/ivory paper with red margin line

    static let notebookPalette = SkinPalette(
        fillTop: CGColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1.0),    // cream
        fillBottom: CGColor(red: 0.90, green: 0.87, blue: 0.78, alpha: 1.0),  // slightly darker cream
        border: CGColor(red: 0.72, green: 0.68, blue: 0.58, alpha: 0.8),      // warm tan border
        accent: CGColor(red: 0.75, green: 0.22, blue: 0.22, alpha: 0.6),      // red margin line
        shadow: CGColor(red: 0.60, green: 0.55, blue: 0.45, alpha: 0.3)
    )

    static var notebook: SkinSpec {
        SkinSpec(name: "notebook", width: 400, height: 580, category: "Retro") { ctx, w, h in
            let fw = CGFloat(w)
            let fh = CGFloat(h)
            let leftMargin: CGFloat = 36
            let inset: CGFloat = 4

            // Main body with torn bottom edge
            let path = CGMutablePath()
            path.move(to: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: fw - inset, y: inset))
            path.addLine(to: CGPoint(x: fw - inset, y: fh - 20))

            // Torn bottom edge
            var x = fw - inset
            let tearHeight: CGFloat = 12
            while x > inset {
                let dx = CGFloat.random(in: 10...20)
                x -= dx
                let ty = fh - 20 + CGFloat.random(in: 0...tearHeight)
                path.addLine(to: CGPoint(x: max(x, inset), y: ty))
            }
            path.addLine(to: CGPoint(x: inset, y: fh - 20 + CGFloat.random(in: 0...tearHeight)))
            path.closeSubpath()

            SkinRenderer.fillAndStroke(ctx, path: path, palette: notebookPalette, lineWidth: 1.5)

            // Faint ruled lines
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.setStrokeColor(CGColor(red: 0.70, green: 0.75, blue: 0.85, alpha: 0.25))
            ctx.setLineWidth(0.5)
            var lineY: CGFloat = 50
            while lineY < fh - 30 {
                ctx.move(to: CGPoint(x: leftMargin + 4, y: lineY))
                ctx.addLine(to: CGPoint(x: fw - inset - 4, y: lineY))
                lineY += 22
            }
            ctx.strokePath()
            ctx.restoreGState()

            // Red margin line
            ctx.setStrokeColor(notebookPalette.accent)
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: leftMargin, y: inset))
            ctx.addLine(to: CGPoint(x: leftMargin, y: fh - 20))
            ctx.strokePath()

            // Spiral binding holes
            let dotRadius: CGFloat = 4
            let dotSpacing: CGFloat = 28
            let dotX: CGFloat = leftMargin / 2
            var dotY: CGFloat = 30

            while dotY < fh - 40 {
                // Punch hole
                ctx.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0))
                ctx.fillEllipse(in: CGRect(
                    x: dotX - dotRadius, y: dotY - dotRadius,
                    width: dotRadius * 2, height: dotRadius * 2
                ))
                // Dark ring around hole
                ctx.setStrokeColor(CGColor(red: 0.55, green: 0.50, blue: 0.42, alpha: 0.7))
                ctx.setLineWidth(1.5)
                ctx.strokeEllipse(in: CGRect(
                    x: dotX - dotRadius, y: dotY - dotRadius,
                    width: dotRadius * 2, height: dotRadius * 2
                ))
                // Silver spiral wire arc
                ctx.setStrokeColor(CGColor(red: 0.65, green: 0.65, blue: 0.68, alpha: 0.9))
                ctx.setLineWidth(2)
                let wireRect = CGRect(
                    x: dotX - dotRadius - 4, y: dotY - dotRadius - 2,
                    width: (dotRadius + 4) * 2, height: (dotRadius + 2) * 2
                )
                ctx.strokeEllipse(in: wireRect)
                dotY += dotSpacing
            }
        }
    }

    // MARK: - Sticky Note — Bright yellow with curled corner shadow

    static let stickyPalette = SkinPalette(
        fillTop: CGColor(red: 1.0, green: 0.95, blue: 0.45, alpha: 1.0),     // bright yellow
        fillBottom: CGColor(red: 0.95, green: 0.88, blue: 0.35, alpha: 1.0),  // slightly deeper
        border: CGColor(red: 0.80, green: 0.72, blue: 0.20, alpha: 0.5),      // golden edge
        accent: CGColor(red: 0.88, green: 0.80, blue: 0.25, alpha: 0.8),      // curl shadow
        shadow: CGColor(red: 0.70, green: 0.62, blue: 0.15, alpha: 0.3)
    )

    static var stickyNote: SkinSpec {
        SkinSpec(name: "sticky-note", width: 380, height: 380, category: "Retro") { ctx, w, h in
            let fw = CGFloat(w)
            let fh = CGFloat(h)
            let inset: CGFloat = 6
            let curlSize: CGFloat = 40

            let path = CGMutablePath()
            path.move(to: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: fw - inset, y: inset))
            path.addLine(to: CGPoint(x: fw - inset, y: fh - inset - curlSize))
            path.addCurve(
                to: CGPoint(x: fw - inset - curlSize, y: fh - inset),
                control1: CGPoint(x: fw - inset, y: fh - inset - curlSize / 3),
                control2: CGPoint(x: fw - inset - curlSize / 3, y: fh - inset)
            )
            path.addLine(to: CGPoint(x: inset, y: fh - inset))
            path.closeSubpath()

            // Drop shadow behind note
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 3, height: 4), blur: 6, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.25))
            SkinRenderer.gradientFill(ctx, path: path, palette: stickyPalette)
            ctx.restoreGState()

            // Border
            ctx.addPath(path)
            ctx.setStrokeColor(stickyPalette.border)
            ctx.setLineWidth(1)
            ctx.strokePath()

            // Curled corner — darker fold
            let curlPath = CGMutablePath()
            curlPath.move(to: CGPoint(x: fw - inset, y: fh - inset - curlSize))
            curlPath.addCurve(
                to: CGPoint(x: fw - inset - curlSize, y: fh - inset),
                control1: CGPoint(x: fw - inset, y: fh - inset - curlSize / 3),
                control2: CGPoint(x: fw - inset - curlSize / 3, y: fh - inset)
            )
            curlPath.addLine(to: CGPoint(x: fw - inset - curlSize, y: fh - inset - curlSize))
            curlPath.closeSubpath()

            ctx.addPath(curlPath)
            ctx.setFillColor(CGColor(red: 0.88, green: 0.82, blue: 0.30, alpha: 1.0))
            ctx.fillPath()

            ctx.addPath(curlPath)
            ctx.setStrokeColor(stickyPalette.accent)
            ctx.setLineWidth(1)
            ctx.strokePath()

            // Faint fold shadow on curl
            ctx.saveGState()
            ctx.addPath(curlPath)
            ctx.clip()
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
            ctx.fill(CGRect(x: fw - inset - curlSize, y: fh - inset - curlSize, width: curlSize, height: curlSize))
            ctx.restoreGState()
        }
    }

    // MARK: - Ticket Stub — Warm off-white / kraft paper with red accents

    static let ticketPalette = SkinPalette(
        fillTop: CGColor(red: 0.92, green: 0.88, blue: 0.80, alpha: 1.0),    // kraft paper
        fillBottom: CGColor(red: 0.85, green: 0.80, blue: 0.70, alpha: 1.0),
        border: CGColor(red: 0.65, green: 0.55, blue: 0.40, alpha: 0.8),
        accent: CGColor(red: 0.80, green: 0.20, blue: 0.15, alpha: 0.7),     // red ticket accent
        shadow: CGColor(red: 0.55, green: 0.45, blue: 0.30, alpha: 0.3)
    )

    static var ticketStub: SkinSpec {
        SkinSpec(name: "ticket-stub", width: 420, height: 560, category: "Retro") { ctx, w, h in
            let fw = CGFloat(w)
            let fh = CGFloat(h)
            let inset: CGFloat = 4
            let notchRadius: CGFloat = 10
            let perfY = fh * 0.7

            let path = CGMutablePath()
            let r = CGRect(x: inset, y: inset, width: fw - inset * 2, height: fh - inset * 2)
            let cornerRadius: CGFloat = 8

            path.move(to: CGPoint(x: r.minX + cornerRadius, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX - cornerRadius, y: r.minY))
            path.addArc(center: CGPoint(x: r.maxX - cornerRadius, y: r.minY + cornerRadius),
                        radius: cornerRadius, startAngle: -.pi / 2, endAngle: 0, clockwise: false)

            path.addLine(to: CGPoint(x: r.maxX, y: perfY - notchRadius))
            path.addArc(center: CGPoint(x: r.maxX, y: perfY),
                        radius: notchRadius, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cornerRadius))

            path.addArc(center: CGPoint(x: r.maxX - cornerRadius, y: r.maxY - cornerRadius),
                        radius: cornerRadius, startAngle: 0, endAngle: .pi / 2, clockwise: false)
            path.addLine(to: CGPoint(x: r.minX + cornerRadius, y: r.maxY))

            path.addArc(center: CGPoint(x: r.minX + cornerRadius, y: r.maxY - cornerRadius),
                        radius: cornerRadius, startAngle: .pi / 2, endAngle: .pi, clockwise: false)

            path.addLine(to: CGPoint(x: r.minX, y: perfY + notchRadius))
            path.addArc(center: CGPoint(x: r.minX, y: perfY),
                        radius: notchRadius, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: r.minX, y: r.minY + cornerRadius))

            path.addArc(center: CGPoint(x: r.minX + cornerRadius, y: r.minY + cornerRadius),
                        radius: cornerRadius, startAngle: .pi, endAngle: -.pi / 2, clockwise: false)
            path.closeSubpath()

            SkinRenderer.fillAndStroke(ctx, path: path, palette: ticketPalette, lineWidth: 1.5)

            // Red accent stripe along top
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.setFillColor(ticketPalette.accent)
            ctx.fill(CGRect(x: r.minX, y: r.minY, width: r.width, height: 18))
            ctx.restoreGState()

            // Dashed perforation line
            ctx.saveGState()
            ctx.setStrokeColor(CGColor(red: 0.55, green: 0.45, blue: 0.32, alpha: 0.5))
            ctx.setLineWidth(1)
            ctx.setLineDash(phase: 0, lengths: [5, 5])
            ctx.move(to: CGPoint(x: r.minX + notchRadius + 8, y: perfY))
            ctx.addLine(to: CGPoint(x: r.maxX - notchRadius - 8, y: perfY))
            ctx.strokePath()
            ctx.restoreGState()

            // "ADMIT ONE" style tiny text area indicator (decorative dots)
            ctx.setFillColor(ticketPalette.accent)
            let starY = r.minY + 7
            for i in 0..<5 {
                let sx = r.midX - 20 + CGFloat(i) * 10
                ctx.fillEllipse(in: CGRect(x: sx, y: starY, width: 3, height: 3))
            }
        }
    }
}
