import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct NoteChecklistItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Item") var title: String = ""
    @Field("Done") var isDone: Bool = false
}

@SlopData
public struct SimpleNoteData {
    @SlopKit.Section("Overview") @Field("Title") var title: String = "Meeting Notes"
    @Field("Subtitle") var subtitle: String = "Stand-up sync — March 2026"
    @Field("Body") var bodyText: String = "Remember to tag Jordan on the deploy PR and call out the CI follow-up."
    @Field("Footer") var footer: String = "Quick Note"
    @SlopKit.Section("Checklist") @Field("Checklist") var checklist: [NoteChecklistItem] = SimpleNoteData.defaultChecklist
}

extension SimpleNoteData {
    static var defaultChecklist: [NoteChecklistItem] {
        func item(_ title: String, _ done: Bool) -> NoteChecklistItem {
            var value = NoteChecklistItem()
            value.title = title
            value.isDone = done
            return value
        }

        return [
            item("Review PRs", true),
            item("Update roadmap", false),
            item("Send follow-up", false),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.simple-note",
    name: "Simple Note",
    description: "Create a lightweight sticky-style note for quick thoughts and reminders.",
    version: "1.0.0",
    width: 350, height: 420,
    minWidth: 300, minHeight: 320,
    shape: .roundedRect(radius: 18),
    theme: "paper",
    alwaysOnTop: true,
    categories: ["popular", "personal"]
)
struct SimpleNoteView: View {
    @TemplateData var data: SimpleNoteData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTextField("Badge", text: $data.footer)
                    .font(theme.mono(size: 10, weight: .bold))
                    .foregroundStyle(theme.accent)

                SlopTextField("Title", text: $data.title)
                    .font(theme.title(size: 24))
                    .foregroundStyle(theme.foreground)
                SlopTextField("Subtitle", text: $data.subtitle)
                    .foregroundStyle(theme.secondary)

                Divider().background(theme.divider)

                SlopEditable($data.bodyText) { value in
                    Text(value)
                        .foregroundStyle(theme.foreground.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                } editor: { binding in
                    TextEditor(text: binding)
                        .foregroundStyle(theme.foreground.opacity(0.92))
                        .scrollContentBackground(.hidden)
                        .font(theme.font(size: 13))
                        .frame(minHeight: 60)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach($data.checklist) { $item in
                        HStack(spacing: 10) {
                            CheckmarkIndicator(isChecked: $item.isDone)
                            SlopTextField("Item", text: $item.title)
                                .foregroundStyle(theme.foreground)
                            SlopInteractiveOnly {
                                Button {
                                    withAnimation { data.checklist.removeAll { $0.id == item.id } }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(theme.font(size: 12))
                                        .foregroundStyle(theme.secondary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    SlopInteractiveOnly {
                        Button {
                            withAnimation { data.checklist.append(NoteChecklistItem()) }
                        } label: {
                            Label("Add Item", systemImage: "plus")
                                .font(.caption)
                                .foregroundStyle(theme.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

