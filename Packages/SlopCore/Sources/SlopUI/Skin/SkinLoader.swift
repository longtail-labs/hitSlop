import AppKit
import CoreGraphics

public struct SkinImage: Sendable {
    public let cgImage: CGImage
    public let size: NSSize
    public let alphaData: Data
    public let alphaWidth: Int
    public let alphaHeight: Int

    public init(cgImage: CGImage, size: NSSize, alphaData: Data, alphaWidth: Int, alphaHeight: Int) {
        self.cgImage = cgImage
        self.size = size
        self.alphaData = alphaData
        self.alphaWidth = alphaWidth
        self.alphaHeight = alphaHeight
    }
}

public struct SkinLoader: Sendable {

    public init() {}

    public static func load(name: String, relativeTo baseURL: URL) -> SkinImage? {
        let skinURL = baseURL.deletingLastPathComponent().appendingPathComponent(name)
        return load(from: skinURL)
    }

    public static func load(from skinURL: URL) -> SkinImage? {
        guard let nsImage = NSImage(contentsOf: skinURL) else {
            NSLog("SkinLoader: failed to load image at \(skinURL.path)")
            return nil
        }

        var rect = NSRect(origin: .zero, size: nsImage.size)
        guard let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            NSLog("SkinLoader: failed to get CGImage")
            return nil
        }

        let (alphaData, alphaWidth, alphaHeight) = extractAlpha(from: cgImage)

        return SkinImage(
            cgImage: cgImage,
            size: nsImage.size,
            alphaData: alphaData,
            alphaWidth: alphaWidth,
            alphaHeight: alphaHeight
        )
    }

    public static func extractAlpha(from cgImage: CGImage) -> (data: Data, width: Int, height: Int) {
        let w = cgImage.width
        let h = cgImage.height
        var bytes = [UInt8](repeating: 0, count: w * h)

        guard let ctx = CGContext(
            data: &bytes,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else {
            return (Data(), w, h)
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (Data(bytes), w, h)
    }
}
