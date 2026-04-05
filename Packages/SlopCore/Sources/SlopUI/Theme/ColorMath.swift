import Foundation

/// LCH color representation (Lightness, Chroma, Hue) in CIELCh(ab) space.
/// Used at theme generation time only — themes are stored as plain hex strings.
public struct LCHColor: Sendable {
    public let l: Double   // 0-100 (lightness)
    public let c: Double   // 0-~130 (chroma/saturation)
    public let h: Double   // 0-360 (hue angle)

    public init(l: Double, c: Double, h: Double) {
        self.l = l
        self.c = max(0, c)
        self.h = h.truncatingRemainder(dividingBy: 360)
    }

    public init(hex: String) {
        let (r, g, b) = hexToRGB(hex)
        let (x, y, z) = rgbToXYZ(r: r, g: g, b: b)
        let (lVal, a, bVal) = xyzToLAB(x: x, y: y, z: z)
        let (lch_l, lch_c, lch_h) = labToLCH(l: lVal, a: a, b: bVal)
        self.l = lch_l
        self.c = max(0, lch_c)
        self.h = lch_h
    }

    public func toHex() -> String {
        let (labL, labA, labB) = lchToLAB(l: l, c: c, h: h)
        let (x, y, z) = labToXYZ(l: labL, a: labA, b: labB)
        let (r, g, b) = xyzToRGB(x: x, y: y, z: z)
        return rgbToHex(r: r, g: g, b: b)
    }
}

// MARK: - WCAG Contrast

/// WCAG 2.1 relative luminance from linear RGB (0.0=black, 1.0=white).
public func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
    func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
}

/// WCAG contrast ratio between two hex colors (1.0-21.0).
public func contrastRatio(_ hex1: String, _ hex2: String) -> Double {
    let (r1, g1, b1) = hexToRGB(hex1)
    let (r2, g2, b2) = hexToRGB(hex2)
    let lum1 = relativeLuminance(r: r1, g: g1, b: b1)
    let lum2 = relativeLuminance(r: r2, g: g2, b: b2)
    let lighter = max(lum1, lum2)
    let darker = min(lum1, lum2)
    return (lighter + 0.05) / (darker + 0.05)
}

// MARK: - Hex ↔ RGB

func hexToRGB(_ hex: String) -> (Double, Double, Double) {
    var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if h.hasPrefix("#") { h.removeFirst() }
    guard h.count == 6, let rgb = UInt64(h, radix: 16) else {
        return (0, 0, 0)
    }
    return (
        Double((rgb >> 16) & 0xFF) / 255.0,
        Double((rgb >> 8) & 0xFF) / 255.0,
        Double(rgb & 0xFF) / 255.0
    )
}

func rgbToHex(r: Double, g: Double, b: Double) -> String {
    let clamp = { (v: Double) -> Int in max(0, min(255, Int(round(v * 255)))) }
    return String(format: "#%02x%02x%02x", clamp(r), clamp(g), clamp(b))
}

// MARK: - RGB ↔ XYZ (D65 illuminant, sRGB companding)

func rgbToXYZ(r: Double, g: Double, b: Double) -> (Double, Double, Double) {
    func linearize(_ c: Double) -> Double {
        c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92
    }
    let rl = linearize(r), gl = linearize(g), bl = linearize(b)
    let x = 0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl
    let y = 0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl
    let z = 0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl
    return (x, y, z)
}

func xyzToRGB(x: Double, y: Double, z: Double) -> (Double, Double, Double) {
    func compand(_ c: Double) -> Double {
        let clamped = max(0, c)
        return clamped > 0.0031308
            ? 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
            : 12.92 * clamped
    }
    let r = compand( 3.2404542 * x - 1.5371385 * y - 0.4985314 * z)
    let g = compand(-0.9692660 * x + 1.8760108 * y + 0.0415560 * z)
    let b = compand( 0.0556434 * x - 0.2040259 * y + 1.0572252 * z)
    return (min(1, max(0, r)), min(1, max(0, g)), min(1, max(0, b)))
}

// MARK: - XYZ ↔ LAB (D65 reference white)

private let refX = 0.95047
private let refY = 1.00000
private let refZ = 1.08883

func xyzToLAB(x: Double, y: Double, z: Double) -> (Double, Double, Double) {
    func f(_ t: Double) -> Double {
        t > 0.008856 ? pow(t, 1.0 / 3.0) : (903.3 * t + 16) / 116
    }
    let fx = f(x / refX)
    let fy = f(y / refY)
    let fz = f(z / refZ)
    let l = 116 * fy - 16
    let a = 500 * (fx - fy)
    let b = 200 * (fy - fz)
    return (l, a, b)
}

func labToXYZ(l: Double, a: Double, b: Double) -> (Double, Double, Double) {
    let fy = (l + 16) / 116
    let fx = a / 500 + fy
    let fz = fy - b / 200
    func invF(_ t: Double) -> Double {
        let t3 = t * t * t
        return t3 > 0.008856 ? t3 : (116 * t - 16) / 903.3
    }
    return (refX * invF(fx), refY * invF(fy), refZ * invF(fz))
}

// MARK: - LAB ↔ LCH

func labToLCH(l: Double, a: Double, b: Double) -> (Double, Double, Double) {
    let c = sqrt(a * a + b * b)
    var h = atan2(b, a) * 180 / .pi
    if h < 0 { h += 360 }
    return (l, c, h)
}

func lchToLAB(l: Double, c: Double, h: Double) -> (Double, Double, Double) {
    let hRad = h * .pi / 180
    return (l, c * cos(hRad), c * sin(hRad))
}
