import Foundation
import SwiftUI
import SlopKit
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Data Model

@SlopData
public struct MarkdownEditorData {
    @SlopKit.Section("Document") @Field("Title") var title: String = "Untitled"
    @Field("Tags") var tags: String = ""
}

// MARK: - Template View

struct MarkdownEditorView: View {
    @TemplateData var data: MarkdownEditorData
    @SidecarContent var content: String
    @Environment(\.slopTheme) private var theme

    init(store: RawTemplateStore, sidecarStore: SidecarStore) {
        self._data = TemplateState(store: store)
        self._content = SidecarContent(key: "content", store: sidecarStore)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            VStack(alignment: .leading, spacing: 4) {
                SlopTextField("Title", text: $data.title)
                    .font(theme.title(size: 20))
                    .foregroundStyle(theme.foreground)

                if !data.tags.isEmpty {
                    SlopTextField("Tags", text: $data.tags)
                        .font(theme.mono(size: 11))
                        .foregroundStyle(theme.secondary)
                } else {
                    SlopEditable($data.tags) { _ in
                        EmptyView()
                    } editor: { binding in
                        TextField("Add tags...", text: binding)
                            .font(theme.mono(size: 11))
                            .foregroundStyle(theme.secondary)
                            .textFieldStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().background(theme.divider)

            // Markdown editor
            SlopEditable($content) { value in
                ScrollView {
                    Text(value)
                        .font(theme.mono(size: 13))
                        .foregroundStyle(theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            } editor: { binding in
                #if canImport(AppKit)
                HashyEditorView(
                    text: binding,
                    font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                    textColor: NSColor(theme.foreground),
                    backgroundColor: NSColor(theme.background),
                    isEditable: true,
                    showLineNumbers: false,
                    showOverlayButtons: false
                )
                #else
                TextEditor(text: binding)
                    .font(theme.mono(size: 13))
                    .foregroundStyle(theme.foreground)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background)
    }
}

// MARK: - Template Class (manual — needs sidecar store)

public final class MarkdownEditorView_SlopTemplate: AnySlopTemplate {
    public static let templateID = "com.hitslop.templates.markdown-editor"
    public static let name = "Markdown Editor"
    public static let templateDescription: String? = "Write Markdown in a clean editor with file-backed content and live styling."
    public static let version = "1.0.0"
    public static let minimumHostVersion = "1.0.0"
    public static let schema: Schema = {
        // Combine the data schema with the file field
        var sections = MarkdownEditorData.schema.sections
        sections.append(SchemaSection("Content", fields: [
            FieldDescriptor(
                key: "content",
                label: "Content",
                kind: .file,
                required: false,
                defaultValue: .null,
                fileDescriptor: FileFieldDescriptor(
                    fileExtension: "md",
                    mimeType: "text/markdown",
                    isText: true,
                    defaultFilename: "content.md"
                )
            )
        ]))
        return Schema(sections: sections)
    }()
    public static let metadata = TemplateMetadata(
        width: 560,
        height: 700,
        minSize: CGSize(width: 400, height: 400),
        windowShape: .roundedRect(radius: 16),
        theme: nil,
        alwaysOnTop: true,
        titleBarHidden: true,
        categories: ["popular", "personal"]
    )

    private let store: RawTemplateStore
    private let sidecar: SidecarStore

    public init(rawStore: RawTemplateStore) {
        self.store = rawStore
        self.sidecar = SidecarStore()
    }

    public init(rawStore: RawTemplateStore, sidecarStore: SidecarStore) {
        self.store = rawStore
        self.sidecar = sidecarStore
    }

    @MainActor
    public func body() -> AnyView {
        AnyView(MarkdownEditorView(store: store, sidecarStore: sidecar))
    }
}

@objc(MarkdownEditorView_EntryPoint)
public final class MarkdownEditorView_EntryPoint: SlopTemplateEntryPoint {
    @objc override public class func templateType() -> AnyObject.Type {
        MarkdownEditorView_SlopTemplate.self
    }
}
