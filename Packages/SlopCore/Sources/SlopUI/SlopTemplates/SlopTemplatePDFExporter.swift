import AppKit
import CoreGraphics
import SwiftUI
import SlopKit

struct SlopTemplatePDFSnapshot {
    let size: NSSize
    let pdfData: Data
}

struct SlopTemplateImageSnapshot {
    let size: NSSize
    let cgImage: CGImage

    func pngData() -> Data? {
        NSBitmapImageRep(cgImage: cgImage)
            .representation(using: .png, properties: [:])
    }
}

private struct SlopTemplateMeasuredCanvas {
    let size: NSSize
    let rootView: SlopTemplateCanvasView
}

@MainActor
enum SlopTemplateSnapshotRenderer {
    static func renderPDF(
        makeTemplateBody: () -> AnyView,
        metadata: TemplateMetadata,
        themeName: String?,
        bundleURL: URL,
        packageURL: URL? = nil,
        effectiveShape: WindowShape? = nil
    ) -> SlopTemplatePDFSnapshot? {
        guard let prepared = prepareCanvas(
            makeTemplateBody: makeTemplateBody,
            metadata: metadata,
            themeName: themeName,
            renderTarget: .pdfExport,
            bundleURL: bundleURL,
            clipToWindowShape: false,
            packageURL: packageURL,
            effectiveShape: effectiveShape
        ) else { return nil }

        let renderer = ImageRenderer(content: prepared.rootView)
        renderer.proposedSize = ProposedViewSize(prepared.size)
        renderer.scale = 1

        let pdfData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: prepared.size)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return nil }

        renderer.render { _, renderInContext in
            context.beginPDFPage(nil)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
        }

        return SlopTemplatePDFSnapshot(
            size: prepared.size,
            pdfData: pdfData as Data
        )
    }

    static func renderImage(
        makeTemplateBody: () -> AnyView,
        metadata: TemplateMetadata,
        themeName: String?,
        bundleURL: URL,
        scale: CGFloat = 2,
        packageURL: URL? = nil,
        effectiveShape: WindowShape? = nil
    ) -> SlopTemplateImageSnapshot? {
        guard let prepared = prepareCanvas(
            makeTemplateBody: makeTemplateBody,
            metadata: metadata,
            themeName: themeName,
            renderTarget: .imageExport,
            bundleURL: bundleURL,
            clipToWindowShape: true,
            packageURL: packageURL,
            effectiveShape: effectiveShape
        ) else { return nil }

        let renderer = ImageRenderer(content: prepared.rootView)
        renderer.proposedSize = ProposedViewSize(prepared.size)
        renderer.scale = scale

        guard let cgImage = renderer.cgImage else { return nil }
        return SlopTemplateImageSnapshot(size: prepared.size, cgImage: cgImage)
    }

    private static func prepareCanvas(
        makeTemplateBody: () -> AnyView,
        metadata: TemplateMetadata,
        themeName: String?,
        renderTarget: SlopRenderTarget,
        bundleURL: URL,
        clipToWindowShape: Bool,
        packageURL: URL? = nil,
        effectiveShape: WindowShape? = nil
    ) -> SlopTemplateMeasuredCanvas? {
        var measuredSize = measureContentSize(
            makeTemplateBody: makeTemplateBody,
            metadata: metadata,
            themeName: themeName,
            renderTarget: renderTarget,
            bundleURL: bundleURL,
            clipToWindowShape: clipToWindowShape,
            packageURL: packageURL,
            effectiveShape: effectiveShape
        )

        // For image export with a skin, use the skin's native pixel dimensions
        // so the exported image matches the interactive window's proportions.
        if renderTarget == .imageExport,
           let skinSize = resolveSkinSize(effectiveShape: effectiveShape ?? metadata.windowShape, bundleURL: bundleURL) {
            measuredSize = skinSize
        }

        let rootView = makeRootView(
            templateBody: makeTemplateBody(),
            metadata: metadata,
            themeName: themeName,
            renderTarget: renderTarget,
            bundleURL: bundleURL,
            canvasSize: measuredSize,
            clipToWindowShape: clipToWindowShape,
            packageURL: packageURL,
            effectiveShape: effectiveShape
        )

        return SlopTemplateMeasuredCanvas(size: measuredSize, rootView: rootView)
    }

    private static func measureContentSize(
        makeTemplateBody: () -> AnyView,
        metadata: TemplateMetadata,
        themeName: String?,
        renderTarget: SlopRenderTarget,
        bundleURL: URL,
        clipToWindowShape: Bool,
        packageURL: URL? = nil,
        effectiveShape: WindowShape? = nil
    ) -> NSSize {
        let hostingView = makeHostingView(
            templateBody: makeTemplateBody(),
            metadata: metadata,
            themeName: themeName,
            renderTarget: renderTarget,
            bundleURL: bundleURL,
            canvasSize: nil,
            clipToWindowShape: clipToWindowShape,
            packageURL: packageURL,
            effectiveShape: effectiveShape
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: metadata.width, height: metadata.height)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.invalidateIntrinsicContentSize()

        let fittingSize = hostingView.fittingSize
        let intrinsicSize = hostingView.intrinsicContentSize

        return NSSize(
            width: ceil(measuredDimension([metadata.width, fittingSize.width, intrinsicSize.width])),
            height: ceil(measuredDimension([metadata.height, fittingSize.height, intrinsicSize.height]))
        )
    }

    private static func measuredDimension(_ values: [CGFloat]) -> CGFloat {
        let finiteValues = values.filter { $0.isFinite && $0 > 0 }
        return finiteValues.max() ?? 1
    }

    private static func resolveSkinSize(effectiveShape: WindowShape, bundleURL: URL) -> NSSize? {
        guard case .skin(let filename) = effectiveShape else { return nil }
        let bundleSkinURL = bundleURL
            .appendingPathComponent("Contents/Resources", isDirectory: true)
            .appendingPathComponent(filename)
        if let image = NSImage(contentsOf: bundleSkinURL) {
            return image.size
        }
        if let entry = SkinCatalog.resolve(filename) {
            return NSImage(contentsOf: entry.fileURL)?.size
        }
        return nil
    }

    private static func makeHostingView(
        templateBody: AnyView,
        metadata: TemplateMetadata,
        themeName: String?,
        renderTarget: SlopRenderTarget,
        bundleURL: URL,
        canvasSize: NSSize?,
        clipToWindowShape: Bool,
        packageURL: URL? = nil,
        effectiveShape: WindowShape? = nil
    ) -> NSHostingView<SlopTemplateCanvasView> {
        let rootView = SlopTemplateCanvasView(
            templateBody: templateBody,
            metadata: metadata,
            themeName: themeName,
            renderTarget: renderTarget,
            bundleURL: bundleURL,
            canvasSize: canvasSize,
            clipToWindowShape: clipToWindowShape,
            packageURL: packageURL,
            effectiveShape: effectiveShape
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.setFrameSize(canvasSize ?? NSSize(width: metadata.width, height: metadata.height))
        return hostingView
    }

    private static func makeRootView(
        templateBody: AnyView,
        metadata: TemplateMetadata,
        themeName: String?,
        renderTarget: SlopRenderTarget,
        bundleURL: URL,
        canvasSize: NSSize?,
        clipToWindowShape: Bool,
        packageURL: URL? = nil,
        effectiveShape: WindowShape? = nil
    ) -> SlopTemplateCanvasView {
        SlopTemplateCanvasView(
            templateBody: templateBody,
            metadata: metadata,
            themeName: themeName,
            renderTarget: renderTarget,
            bundleURL: bundleURL,
            canvasSize: canvasSize,
            clipToWindowShape: clipToWindowShape,
            packageURL: packageURL,
            effectiveShape: effectiveShape
        )
    }
}

@MainActor
enum SlopTemplatePDFExporter {
    static func render(
        makeTemplateBody: () -> AnyView,
        metadata: TemplateMetadata,
        themeName: String?,
        bundleURL: URL,
        packageURL: URL? = nil,
        effectiveShape: WindowShape? = nil
    ) -> SlopTemplatePDFSnapshot? {
        SlopTemplateSnapshotRenderer.renderPDF(
            makeTemplateBody: makeTemplateBody,
            metadata: metadata,
            themeName: themeName,
            bundleURL: bundleURL,
            packageURL: packageURL,
            effectiveShape: effectiveShape
        )
    }
}

struct SlopTemplateCanvasView: View {
    let templateBody: AnyView
    let metadata: TemplateMetadata
    let themeName: String?
    let renderTarget: SlopRenderTarget
    let bundleURL: URL
    let canvasSize: NSSize?
    let clipToWindowShape: Bool
    var packageURL: URL?
    var effectiveShape: WindowShape?

    private var resolvedShape: WindowShape {
        effectiveShape ?? metadata.windowShape
    }

    private var isSkinActive: Bool {
        if renderTarget == .pdfExport { return false }
        if case .skin = resolvedShape { return true }
        return false
    }

    var body: some View {
        let theme = ThemeCatalog.resolveTheme(themeName, packageURL: packageURL)
        let appliedTheme = isSkinActive ? theme.withClearBackground() : theme
        applyShape(
            to: framedCanvas
                .background(appliedTheme.background)
                .environment(\.slopTheme, appliedTheme)
                .environment(\.slopRenderTarget, renderTarget)
                .environment(\.slopPackageURL, packageURL)
        )
    }

    @ViewBuilder
    private var framedCanvas: some View {
        let canvas = ZStack {
            if renderTarget == .imageExport, let skinImage {
                Image(nsImage: skinImage)
                    .resizable()
                    .scaledToFill()
            }
            templateCanvas
        }

        if let canvasSize {
            canvas
                .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        } else {
            canvas
                .frame(width: metadata.width, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var templateCanvas: some View {
        if let canvasSize {
            if isSkinActive {
                templateBody
                    .frame(
                        width: metadata.width,
                        height: metadata.height,
                        alignment: .top
                    )
            } else {
                templateBody
                    .frame(
                        width: canvasSize.width,
                        height: canvasSize.height,
                        alignment: .top
                    )
            }
        } else {
            templateBody
                .frame(width: metadata.width, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func applyShape<Content: View>(to content: Content) -> some View {
        if clipToWindowShape {
            switch resolvedShape {
            case .roundedRect(let radius):
                content.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            case .circle:
                content.clipShape(Circle())
            case .capsule:
                content.clipShape(Capsule())
            case .path:
                content.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            case .skin:
                content
            }
        } else {
            content
        }
    }

    private var skinImage: NSImage? {
        guard case .skin(let filename) = resolvedShape else { return nil }
        // Try template bundle first
        let bundleSkinURL = bundleURL
            .appendingPathComponent("Contents/Resources", isDirectory: true)
            .appendingPathComponent(filename)
        if let image = NSImage(contentsOf: bundleSkinURL) {
            return image
        }
        // Fall back to SkinCatalog
        if let entry = SkinCatalog.resolve(filename) {
            return NSImage(contentsOf: entry.fileURL)
        }
        return nil
    }
}
