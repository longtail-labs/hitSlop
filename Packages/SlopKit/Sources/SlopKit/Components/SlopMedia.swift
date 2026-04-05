import SwiftUI
import UniformTypeIdentifiers

/// A unified media component that auto-detects image vs video from file extension
/// and routes to `SlopImage` or `SlopVideo` internally. Drop zone accepts both types.
///
/// ```swift
/// SlopMedia(media: $data.content, placeholder: "Drop image or video")
/// ```
public struct SlopMedia: View {
    private let binding: Binding<TemplateImage>
    private let placeholder: String

    public init(media: Binding<TemplateImage>, placeholder: String = "Drop image or video") {
        self.binding = media
        self.placeholder = placeholder
    }

    public var body: some View {
        if binding.wrappedValue.path.isEmpty {
            emptyDropZone
        } else if isVideo(binding.wrappedValue.path) {
            SlopVideo(video: binding, placeholder: placeholder)
        } else {
            SlopImage(image: binding, placeholder: placeholder)
        }
    }

    private nonisolated static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "webm"]

    private func isVideo(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return Self.videoExtensions.contains(ext)
    }

    @Environment(\.slopRenderTarget) private var renderTarget
    @Environment(\.slopPackageURL) private var packageURL

    @ViewBuilder
    private var emptyDropZone: some View {
        if renderTarget == .interactive {
            dropZone
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
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
                Image(systemName: "photo.on.rectangle.angled")
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

    private nonisolated static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "tiff", "webp", "heic"]
    private nonisolated static let allExtensions: Set<String> = imageExtensions.union(videoExtensions)

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .movie]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        binding.wrappedValue = TemplateImage.importAsset(from: url, into: packageURL)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil)
            else { return }
            guard Self.allExtensions.contains(url.pathExtension.lowercased()) else { return }
            DispatchQueue.main.async {
                binding.wrappedValue = TemplateImage.importAsset(from: url, into: packageURL)
            }
        }
        return true
    }
}
