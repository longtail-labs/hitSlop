import AppKit
import SwiftUI
import SlopAI
import SlopKit
import os

private let log = Logger(subsystem: "com.hitslop.ai", category: "chat")

@MainActor
final class AIChatPanel: NSPanel {
    static let panelWidth: CGFloat = 320
    private static let cornerRadius: CGFloat = 12

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(document: SlopTemplateDocumentModel, aiService: SlopAIService) {
        let rect = NSRect(x: 0, y: 0, width: Self.panelWidth, height: 440)
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        isRestorable = false
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.moveToActiveSpace]

        let root = AIChatView(document: document, aiService: aiService)
            .frame(width: Self.panelWidth)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))

        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = rect
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    func reposition(relativeTo window: NSWindow, gap: CGFloat = 8) {
        let parentFrame = window.frame
        let x = parentFrame.maxX + gap
        let y = parentFrame.minY
        let height = parentFrame.height
        setFrame(
            NSRect(x: x, y: y, width: Self.panelWidth, height: height),
            display: true
        )
    }
}

private struct AIChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
        case error
    }

    let id = UUID()
    let role: Role
    let text: String
    let imageData: Data?

    init(role: Role, text: String, imageData: Data? = nil) {
        self.role = role
        self.text = text
        self.imageData = imageData
    }
}

@MainActor
private struct AIChatView: View {
    @ObservedObject var document: SlopTemplateDocumentModel
    let aiService: SlopAIService

    @State private var draft = ""
    @State private var isSending = false
    @State private var messages: [AIChatMessage] = []

    /// Image fields from the template schema available for "Save to field".
    private var imageFieldKeys: [(key: String, label: String)] {
        document.schema.allFields
            .filter { $0.kind == .image }
            .map { (key: $0.key, label: $0.label) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty {
                        emptyState
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { message in
                                messageRow(message)
                                    .id(message.id)
                            }

                            if isSending {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Working…")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(12)
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            composer
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "bubble.right")
                .font(.system(size: 12, weight: .semibold))
            Text("AI Chat")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Spacer()
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Describe the change you want.")
                .font(.system(size: 12, weight: .semibold))
            Text("Examples: \u{201C}Rename the title to Sprint Goals\u{201D}, \u{201C}Add a new habit\u{201D}, or \u{201C}Generate a photo of a sunset.\u{201D}")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !imageFieldKeys.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 10))
                    Text("This template has image fields \u{2014} try \u{201C}generate a photo of\u{2026}\u{201D}")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary.opacity(0.7))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $draft)
                .font(.system(size: 12))
                .frame(minHeight: 84, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                )

            HStack {
                Text(isSending ? "Working\u{2026}" : "Updates are applied directly to this slop.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Send") {
                    send()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
    }

    private func messageRow(_ message: AIChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(roleLabel(for: message.role))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(roleColor(for: message.role))

            Text(message.text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Inline image display for generated images
            if let imageData = message.imageData,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 4)

                // "Save to field" buttons for image fields
                if !imageFieldKeys.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SAVE TO FIELD")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 4) {
                            ForEach(imageFieldKeys, id: \.key) { field in
                                Button(field.label) {
                                    saveImageToField(imageData: imageData, fieldKey: field.key)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(messageBackground(for: message.role))
        )
    }

    // MARK: - Send

    private func send() {
        let instruction = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty, !isSending else { return }

        draft = ""
        isSending = true
        messages.append(AIChatMessage(role: .user, text: instruction))

        // Detect if this looks like an image generation request
        if looksLikeImageGeneration(instruction) {
            sendImageGeneration(instruction)
        } else {
            sendDocumentUpdate(instruction)
        }
    }

    private func sendDocumentUpdate(_ instruction: String) {
        let schema = document.schema
        let currentData = FieldValue.encodeRecord(document.rawData, schema: schema)

        log.info("send: instruction=\(instruction.prefix(80), privacy: .public), schema fields=\(schema.allFields.count), currentData keys=\(currentData.count)")

        Task {
            do {
                let update = try await aiService.updateDocument(
                    templateName: document.fileURL.deletingPathExtension().lastPathComponent,
                    schema: schema,
                    currentData: currentData,
                    instruction: instruction
                )

                log.info("send: received update \u{2014} \(String(describing: update).prefix(120), privacy: .public)")

                await MainActor.run {
                    DocumentUpdateApplier.apply(update, to: document.rawStore, schema: schema)
                    messages.append(AIChatMessage(role: .assistant, text: summary(for: update)))
                    isSending = false
                    log.info("send: update applied, isSending=false")
                }
            } catch {
                // If model refused document tools and template has image fields,
                // retry as image generation.
                if case SlopAIError.noFunctionCall = error, !imageFieldKeys.isEmpty {
                    log.info("send: noFunctionCall with image fields present, retrying as image generation")
                    await MainActor.run {
                        sendImageGeneration(instruction)
                    }
                    return
                }

                log.error("send: error \u{2014} \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    messages.append(AIChatMessage(role: .error, text: error.localizedDescription))
                    isSending = false
                }
            }
        }
    }

    private func sendImageGeneration(_ prompt: String) {
        log.info("sendImageGeneration: prompt=\(prompt.prefix(80), privacy: .public)")

        Task {
            do {
                let result = try await aiService.generateImage(prompt: prompt)

                await MainActor.run {
                    let text = result.text.isEmpty ? "Generated image." : result.text
                    let firstImage = result.images.first
                    messages.append(AIChatMessage(
                        role: .assistant,
                        text: text,
                        imageData: firstImage
                    ))
                    isSending = false
                    log.info("sendImageGeneration: success, images=\(result.images.count)")
                }
            } catch {
                log.error("sendImageGeneration: error \u{2014} \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    messages.append(AIChatMessage(role: .error, text: error.localizedDescription))
                    isSending = false
                }
            }
        }
    }

    // MARK: - Image Generation Detection

    private func looksLikeImageGeneration(_ text: String) -> Bool {
        let lower = text.lowercased()

        // Explicit triggers — verb + image-related noun
        let verbs = ["generate", "create", "make", "draw", "paint", "illustrate", "design", "render", "produce", "sketch"]
        let nouns = ["image", "photo", "picture", "illustration", "logo", "artwork", "icon", "graphic", "portrait", "thumbnail", "banner", "screenshot"]

        for verb in verbs {
            for noun in nouns {
                if lower.contains(verb) && lower.contains(noun) {
                    return true
                }
            }
        }

        // Short phrase triggers
        let directTriggers = [
            "nano banana",
            "draw me",
            "draw a ",
            "paint a ",
            "paint me",
            "sketch a ",
            "sketch me",
            "generate a ",
            "illustrate a ",
        ]
        for trigger in directTriggers {
            if lower.contains(trigger) { return true }
        }

        return false
    }

    // MARK: - Save Image to Field

    private func saveImageToField(imageData: Data, fieldKey: String) {
        let filename = "ai_generated_\(UUID().uuidString.prefix(8)).png"
        let imageURL = document.fileURL.appendingPathComponent(filename)

        do {
            // Ensure .slop package directory exists
            try FileManager.default.createDirectory(at: document.fileURL, withIntermediateDirectories: true)
            try imageData.write(to: imageURL)

            // Update the image field via rawStore for undo support
            document.rawStore.setValues([fieldKey: .image(imageURL.path)])

            messages.append(AIChatMessage(
                role: .assistant,
                text: "Saved to \(fieldKey)."
            ))
            log.info("saveImageToField: saved \(filename, privacy: .public) to field \(fieldKey, privacy: .public)")
        } catch {
            log.error("saveImageToField: error \u{2014} \(error.localizedDescription, privacy: .public)")
            messages.append(AIChatMessage(
                role: .error,
                text: "Failed to save image: \(error.localizedDescription)"
            ))
        }
    }

    // MARK: - Helpers

    private func summary(for update: DocumentUpdate) -> String {
        switch update {
        case .fullRewrite:
            return "Rewrote the document with a full structured update."
        case .mergeFields(let changedFields):
            let count = changedFields.count
            return "Updated \(count) field\(count == 1 ? "" : "s")."
        case .arrayOps(let operations):
            let added = operations.reduce(0) { $0 + $1.add.count }
            let removed = operations.reduce(0) { $0 + $1.removeIDs.count }
            let updated = operations.reduce(0) { $0 + $1.update.count }
            let parts = [
                added > 0 ? "added \(added)" : nil,
                removed > 0 ? "removed \(removed)" : nil,
                updated > 0 ? "updated \(updated)" : nil,
            ].compactMap { $0 }

            if parts.isEmpty {
                return "Applied array updates."
            }
            return "Array changes: \(parts.joined(separator: ", "))."
        }
    }

    private func roleLabel(for role: AIChatMessage.Role) -> String {
        switch role {
        case .user:
            return "YOU"
        case .assistant:
            return "AI"
        case .error:
            return "ERROR"
        }
    }

    private func roleColor(for role: AIChatMessage.Role) -> Color {
        switch role {
        case .user:
            return .secondary
        case .assistant:
            return .accentColor
        case .error:
            return .red
        }
    }

    private func messageBackground(for role: AIChatMessage.Role) -> Color {
        switch role {
        case .user:
            return Color.white.opacity(0.03)
        case .assistant:
            return Color.accentColor.opacity(0.10)
        case .error:
            return Color.red.opacity(0.10)
        }
    }
}

// MARK: - FlowLayout

/// Simple horizontal flow layout for "Save to field" buttons.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var offsets: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
            totalHeight = y + rowHeight
        }

        return ArrangeResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            offsets: offsets
        )
    }
}
