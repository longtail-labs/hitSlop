import QuickLookUI
import SlopUI
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider {

    enum PreviewError: Error {
        case invalidFile
    }

    func providePreview(
        for request: QLFilePreviewRequest
    ) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let title = fileURL.deletingPathExtension().lastPathComponent

        if let previewURL = SlopPreviewAssetResolver.resolvePreviewURL(for: fileURL) {
            let reply = QLPreviewReply(fileURL: previewURL)
            reply.title = title
            return reply
        }

        guard let envelope = try? SlopFile.loadEnvelope(from: fileURL)
        else {
            throw PreviewError.invalidFile
        }

        // Fallback: HTML-based data reply with template name
        let templateName = envelope.templateID.components(separatedBy: ".").last ?? envelope.templateID
        let html = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>
        body {
            margin: 0; display: flex; align-items: center; justify-content: center;
            height: 100vh; background: #fff; font-family: -apple-system, system-ui;
        }
        .card { text-align: center; padding: 40px; }
        .title { font-size: 24px; font-weight: 600; color: #262633; margin-bottom: 8px; }
        .template { font-size: 14px; font-weight: 500; color: #8066ff; }
        </style></head>
        <body><div class="card">
            <div class="title">\(Self.escapeHTML(title))</div>
            <div class="template">Template: \(Self.escapeHTML(templateName))</div>
        </div></body>
        </html>
        """

        guard let htmlData = html.data(using: .utf8) else {
            throw PreviewError.invalidFile
        }

        let reply = QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 400, height: 300)
        ) { _ in
            return htmlData
        }
        reply.title = title
        return reply
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
