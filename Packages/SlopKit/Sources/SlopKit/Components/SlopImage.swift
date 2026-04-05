import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Displays an image from a `TemplateImage` path. In interactive mode, shows a
/// drop zone / file picker when no image is set. In export mode, renders statically.
///
/// ```swift
/// SlopImage(image: $data.screenshot, placeholder: "Drop screenshot here")
/// ```
public struct SlopImage: View {
    private let binding: Binding<TemplateImage>
    private let placeholder: String

    @Environment(\.slopRenderTarget) private var renderTarget
    @Environment(\.slopPackageURL) private var packageURL

    public init(image: Binding<TemplateImage>, placeholder: String = "Drop image here") {
        self.binding = image
        self.placeholder = placeholder
    }

    public var body: some View {
        if binding.wrappedValue.path.isEmpty {
            emptyState
        } else {
            imageView
        }
    }

    @ViewBuilder
    private var imageView: some View {
        let resolved = binding.wrappedValue.resolved(relativeTo: packageURL)
        if let nsImage = NSImage(contentsOfFile: resolved) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            placeholderRect
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if renderTarget == .interactive {
            dropZone
        } else {
            placeholderRect
        }
    }

    private var placeholderRect: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                )

            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text(placeholder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Choose File\u{2026}") {
                    chooseFile()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        binding.wrappedValue = TemplateImage.importAsset(from: url, into: packageURL)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil)
            else { return }
            let supported: Set<String> = ["png", "jpg", "jpeg", "gif", "tiff", "webp", "heic"]
            guard supported.contains(url.pathExtension.lowercased()) else { return }
            DispatchQueue.main.async {
                binding.wrappedValue = TemplateImage.importAsset(from: url, into: packageURL)
            }
        }
        return true
    }
}
