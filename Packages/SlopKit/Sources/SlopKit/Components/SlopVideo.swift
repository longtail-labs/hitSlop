import SwiftUI
import AppKit
import AVKit
import AVFoundation
import CoreMedia
import UniformTypeIdentifiers

/// Displays a video from a `TemplateImage` path. In interactive mode, shows an
/// inline player with play/pause controls. In export mode, renders a thumbnail
/// of the first frame. Supports drop-to-replace and file picker.
///
/// ```swift
/// SlopVideo(video: $data.clip, placeholder: "Drop video here")
/// ```
public struct SlopVideo: View {
    private let binding: Binding<TemplateImage>
    private let placeholder: String

    @Environment(\.slopRenderTarget) private var renderTarget
    @Environment(\.slopPackageURL) private var packageURL
    @State private var thumbnail: NSImage?

    public init(video: Binding<TemplateImage>, placeholder: String = "Drop video here") {
        self.binding = video
        self.placeholder = placeholder
    }

    public var body: some View {
        if binding.wrappedValue.path.isEmpty {
            emptyState
        } else if renderTarget == .interactive {
            playerView
        } else {
            thumbnailView
        }
    }

    // MARK: - Player

    @ViewBuilder
    private var playerView: some View {
        let url = URL(fileURLWithPath: binding.wrappedValue.resolved(relativeTo: packageURL))
        let player = AVPlayer(url: url)
        VideoPlayer(player: player)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear { player.isMuted = true }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }
    }

    // MARK: - Thumbnail (export)

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .center) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 4)
                }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay(
                    ProgressView()
                        .controlSize(.small)
                )
                .task { await generateThumbnail() }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        if renderTarget == .interactive {
            dropZone
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
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
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                )

            VStack(spacing: 8) {
                Image(systemName: "film.badge.plus")
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

    // MARK: - File Handling

    private nonisolated static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v", "webm"]

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        binding.wrappedValue = TemplateImage.importAsset(from: url, into: packageURL)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil)
            else { return }
            guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else { return }
            DispatchQueue.main.async {
                binding.wrappedValue = TemplateImage.importAsset(from: url, into: packageURL)
            }
        }
        return true
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail() async {
        let resolved = binding.wrappedValue.resolved(relativeTo: packageURL)
        guard !resolved.isEmpty else { return }
        let url = URL(fileURLWithPath: resolved)
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)

        do {
            let (cgImage, _) = try await generator.image(at: CMTime.zero)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            await MainActor.run { thumbnail = nsImage }
        } catch {
            // Thumbnail generation failed — leave nil, placeholder will show
        }
    }
}
