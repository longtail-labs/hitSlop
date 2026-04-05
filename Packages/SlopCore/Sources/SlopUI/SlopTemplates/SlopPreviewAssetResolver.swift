import Foundation

public enum SlopPreviewAssetResolver {
    public static func resolvePreviewURL(for packageURL: URL) -> URL? {
        resolvePreviewURL(
            for: packageURL,
            previewsDirectory: SlopSharedContainer.previewsDir
        )
    }

    static func resolvePreviewURL(
        for packageURL: URL,
        previewsDirectory: URL,
        loadEnvelope: (URL) throws -> SlopFileEnvelope = SlopFile.loadEnvelope(from:)
    ) -> URL? {
        if let packagePreviewURL = accessiblePreviewURL(
            packageURL.appendingPathComponent("preview.png")
        ) {
            return packagePreviewURL
        }

        guard let envelope = try? loadEnvelope(packageURL) else { return nil }
        let cachedPreviewURL = previewsDirectory
            .appendingPathComponent("\(envelope.templateID)@\(envelope.templateVersion).png")
        return accessiblePreviewURL(cachedPreviewURL)
    }

    private static func accessiblePreviewURL(_ url: URL) -> URL? {
        guard (try? Data(contentsOf: url, options: [.mappedIfSafe])) != nil else { return nil }
        return url
    }
}
